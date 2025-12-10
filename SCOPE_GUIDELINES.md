# PowerShell スクリプト変数スコープガイドライン

## 概要
このドキュメントは、PowerShellプロジェクト全体で一貫した変数スコープの使用を保証するためのガイドラインです。

## 基本原則

### 1. **スクリプトスコープ変数 (`$script:`) の使用**
スクリプト全体で共有される変数は、明示的に `$script:` スコープを使用してください。

#### 対象となる変数:
- **パス関連変数**: `$script:ScriptPath`, `$script:UpperPath`, `$script:PowerShellDir`, `$script:YamlPath`, `$script:ComPath`, `$script:LogDir`, `$script:LogPath`
- **設定オブジェクト**: `$script:Yaml`, `$script:YamlOBJ`
- **グローバル情報**: `$script:User`, `$script:HostName`
- **スクリプトブロック関数**: `$script:ShowPopup`, `$script:GetMessage`
- **共有リソース**: `$script:SensitivePatterns`, `$script:EncryptedKey`

#### 例:
```powershell
begin {
    # スクリプト実行環境を取得
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $script:UpperPath = Split-Path -Parent $script:ScriptPath
    $script:PowerShellDir = Split-Path -Parent $script:UpperPath
    
    # YAML設定ファイルの読み込み
    $script:Yaml = Get-Content -Path $script:YamlPath -Delimiter "`0" | ConvertFrom-Yaml -Ordered
    
    # ユーザー情報
    $script:User = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME
}
```

### 2. **ローカル変数の使用**
一時的な計算や限定的なスコープで使用する変数は、スコープ修飾子を付けません。

#### 対象となる変数:
- ループカウンター: `$i`, `$counter`
- 一時的な計算結果: `$result`, `$output`
- 関数内のローカル変数: `$tempFile`, `$fileEncoding`

#### 例:
```powershell
process {
    foreach ($file in $files) {
        $tempFile = $file.FullName + ".tmp"  # ローカル変数
        $result = Process-File -Path $tempFile
    }
}
```

### 3. **関数パラメータ**
関数のパラメータは、通常のローカルスコープとして扱います。

#### 例:
```powershell
function Copy-ItemCustom {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReleaseType,
        [Parameter(Mandatory=$true)]
        [object]$Yaml
    )
    
    # $ReleaseType と $Yaml はこの関数内でのみ有効
}
```

### 4. **スクリプトブロック内の変数**
スクリプトブロック (`{}`) 内で親スコープの変数を参照する場合、明示的に `$script:` を使用します。

#### 例:
```powershell
$script:ShowPopup = {
    param(
        [string]$Message,
        [int]$Buttons = 0
    )
    $obj = New-Object -ComObject WScript.Shell
    try {
        return [int]$obj.Popup($Message, 0, "Information", $Buttons)
    } finally {
        if ($null -ne $obj) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
            $obj = $null
        }
    }
}

$script:GetMessage = {
    param([string]$Key)
    $lang = $script:Yaml.MESSAGES.LANGUAGE  # 親スコープの変数を参照
    $message = $script:Yaml.MESSAGES.$lang.$Key
    return $message
}
```

## スコープ適用パターン

### パターン1: メインスクリプト構造
```powershell
param(
    [Parameter(Mandatory=$false)]
    [string]$EnvYaml = "default.yaml"
)

begin {
    # パス初期化
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $script:UpperPath = Split-Path -Parent $script:ScriptPath
    $script:PowerShellDir = Split-Path -Parent $script:UpperPath
    
    # 設定読み込み
    $script:YamlPath = Join-Path -Path $script:UpperPath -ChildPath "YAML" | Join-Path -ChildPath $EnvYaml
    $script:Yaml = Get-Content $script:YamlPath -Delimiter "`0" | ConvertFrom-Yaml -Ordered
    
    # ログ設定
    $script:LogPath = Join-Path -Path $script:Yaml.LOG.PATH -ChildPath ($script:Yaml.LOG.FILENAME + "_" + (Get-Date -Format "yyyyMMdd-HHmmss") + $script:Yaml.LOG.EXTENSION)
}

process {
    # メイン処理
    foreach ($item in $script:Yaml.ITEMS.Keys) {
        $localResult = Process-Item -Name $item  # ローカル変数
        Write-CommonLog -Message $localResult -LogPath $script:LogPath -Level 'INFO'
    }
}

end {
    # クリーンアップ
    Write-Host "ログファイル: $($script:LogPath)"
}
```

### パターン2: 関数定義
```powershell
function Invoke-CustomProcess {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [string]$LogPath = $script:LogPath  # デフォルト値としてscript変数を使用
    )
    
    # ローカル変数
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $message = "Processing: $Name at $timestamp"
    
    # script変数への書き込み
    Write-CommonLog -Message $message -LogPath $LogPath -Level 'INFO'
}
```

## 命名規則

### 推奨する変数名の大文字/小文字表記
- **Pascal Case (大文字開始)**: `$script:ScriptPath`, `$script:YamlPath`, `$script:LogDir`
- **Camel Case (小文字開始)**: ローカル変数 `$tempFile`, `$fileCount`
- **定数風**: `$script:User`, `$script:HostName` (変更されない値)

### 避けるべきパターン
```powershell
# ❌ 悪い例: スコープが不明確
$scriptPath = "..."  # ローカルか？スクリプトスコープか？
$yaml = Get-Content ...  # 複数の場所で使われるのに明示的なスコープがない

# ✅ 良い例: スコープが明確
$script:ScriptPath = "..."
$script:Yaml = Get-Content ...
```

## 移行チェックリスト

既存スクリプトを本ガイドラインに適合させる際のチェックリスト:

- [ ] すべてのパス関連変数に `$script:` を追加
- [ ] YAML設定オブジェクトに `$script:` を追加
- [ ] ユーザー・ホスト情報に `$script:` を追加
- [ ] スクリプトブロック内の親スコープ参照に `$script:` を追加
- [ ] 関数内のローカル変数がスコープ修飾子なしであることを確認
- [ ] ループ変数がローカルスコープであることを確認

## 対象スクリプト一覧

以下のスクリプトは本ガイドラインに準拠しています:

1. **リリースバッチ/**
   - `relMain.ps1` ✓
   - `CopyItemCustom.ps1` ✓

2. **SQLクエリー実行/**
   - `sqlMain.ps1` ✓

3. **ILSpyCmdの入手/**
   - `getILSpyCmd.ps1` ✓

4. **DotnetSdk削除/**
   - `DotNetSdk_Uninstall.ps1` ✓

5. **DecompileDLL/**
   - `DecompileDll.ps1` ✓ (一部)

## バージョン履歴

- **v1.0.0** (2025-12-10): 初版リリース
  - スクリプトスコープの統一ガイドライン確立
  - 主要スクリプトへの適用完了

## 参考資料

- [PowerShell About Scopes (Microsoft Docs)](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_scopes)
- プロジェクトREADME: `README.md`
