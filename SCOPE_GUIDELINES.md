# PowerShell スクリプト変数スコープガイドライン

## 概要

このドキュメントは、PowerShellプロジェクト全体で一貫した変数スコープの使用を保証するためのガイドラインです。

## 基本原則

### 1. **スクリプトスコープ変数 (`$script:`) の使用**

スクリプト全体で共有される変数は、明示的に `$script:` スコープを使用してください。

#### 対象となる変数（スクリプトスコープ）

- **パス関連変数**: `$script:ScriptPath`, `$script:UpperPath`, `$script:PowerShellDir`, `$script:YamlPath`, `$script:ComPath`, `$script:LogDir`, `$script:LogPath`
- **設定オブジェクト**: `$script:Yaml`, `$script:YamlOBJ`
- **グローバル情報**: `$script:User`, `$script:HostName`
- **スクリプトブロック関数**: `$script:ShowPopup`, `$script:GetMessage`
- **共有リソース**: `$script:SensitivePatterns`, `$script:EncryptedKey`

#### 例（スクリプトスコープ変数）

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

#### 対象となる変数（ローカル）

- ループカウンター: `$i`, `$counter`
- 一時的な計算結果: `$result`, `$output`
- 関数内のローカル変数: `$tempFile`, `$fileEncoding`

#### 例（ローカル変数）

```powershell
process {
    foreach ($file in $files) {
        $tempFile = $file.FullName + ".tmp"  # ローカル変数
        $result = Process-File -Path $tempFile
    }
}
```

### 3. **関数パラメーター**

関数のパラメーターは、通常のローカルスコープとして扱います。

#### 例（関数パラメーター）

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

#### 例（スクリプトブロック）

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
- **定数風**: `$script:User`, `$script:HostName` (変更されない値）

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
   - `DecompileDll.ps1` ✓ (一部）

6. **Node.js通信ブロック対応/**
   - `npm_install_safe.ps1` ✓
   - `npm_uninstall_safe.ps1` ✓

7. **Excelの操作/**
   - `ExcelBook比較/ExcelComp.ps1` ✓
   - `Excelセルコメント/WriteCell.ps1` ✓
   - `ExportExcel/ExptExcel.ps1` ✓

8. **ファイルアクセスブロック解除/**
   - `unblock_files.ps1` ✓

9. **必要なモジュールの導入/**
   - `InstMain.ps1` ✓

10. **dotNetSdkUninstallToolの入手/**
    - `DotNetUninstallTool.ps1` ✓

11. **暗号化鍵の作成/**
    - `MakeEncrypted.ps1` ✓

12. **暗号化文字列の作成/**
    - `MakeEncryptedString.ps1` ✓

13. **暗号化文字列の復元/**
    - `StringDecryption.ps1` ✓
    - `InputGUI.ps1` ✓

## 補足ガイド

### `$global:` の取り扱い

- 原則として使用禁止。影響範囲がワークスペース全体に拡散し、保守性とテスト容易性が低下します。
- 例外は短命の検証コードやテスト専用のフラグなどに限定し、PRレビューを必須とします。

### モジュールスコープ (`$module:`)

- `.psm1` 内では `$script:` がモジュール内スコープとして機能します。モジュール外からの共有はパラメーター渡しを基本とし、`$global:` を避けます。
- 推奨: 設定値やステートは `$module:`（または `$script:`）に集約し、公開関数は引数で受け取り・返り値で返す方針。

### 並列/非同期と `$using:` の注意

- `Start-Job` や `ForEach-Object -Parallel` では、親スコープの値は `$using:` で明示渡し（コピー）され、同期はされません。

```powershell
$cfg = $script:Yaml
Start-Job -ScriptBlock {
    param($c)
    Process-Items -Config $c
} -ArgumentList $cfg | Out-Null

$script:Items | ForEach-Object -Parallel {
    Process-Item -Config $using:Yaml
}
```

### ドットソースの注意

- `. "path\lib.ps1"` は呼び出し側スコープに取り込みます（衝突リスク）。原則は実行 `& "path\lib.ps1"` を推奨。
- やむを得ずドットソースする場合は、公開シンボルのプレフィックスや `$script:` での明示を徹底し、命名衝突を避けます。

### 読み取り専用化（誤更新防止）

```powershell
New-Variable -Name 'LogPath' -Value $computed -Scope Script -Option ReadOnly
```

- 初期化後に変更しない共有値にはReadOnlyを推奨します。必要時のみ `-Force` 解除を伴う再初期化に限定します。

### コンテキスト集約（論理的バンドル）

```powershell
$script:Context = [ordered]@{
    Paths  = [ordered]@{ Root = $script:UpperPath; Log = $script:LogPath }
    Config = $script:Yaml
    User   = [ordered]@{ Name = $script:User; Host = $script:HostName }
}
```

- 論理的まとまりで束ねることで、意図せぬキー追加/誤用を検知しやすくします。

### 例外と後始末の標準化（ロギング・フォールバック）

```powershell
try {
    Write-CommonLog -Message $msg -LogPath $script:LogPath -Level 'INFO'
} catch {
    Write-Error $_
    $fb = Join-Path $env:TEMP 'fallback.log'
    Add-Content -Path $fb -Value "[FALLBACK] $msg"
}
```

- 主要処理に失敗時でも最低限の記録を残すフォールバックを用意します。

### `Set-StrictMode` の推奨

```powershell
Set-StrictMode -Version Latest
```

- 未宣言/未初期化参照を早期検知し、スコープの不整合を防ぎます。

## 設計・可読性の補足

### `begin/process/end` の役割明確化

- `begin`: 共有リソースの初期化（パス、設定、ログ）。
- `process`: 逐次処理（ローカル変数中心、共有値の読み取りのみ）。
- `end`: 後始末（ハンドル解放、サマリ出力）。

### 命名の強化

- YAML原文は `$YamlText`、変換済みオブジェクトは `$Yaml` と役割分離。
- パスは `...Path`、ディレクトリは `...Dir` を徹底（例: `LogPath` / `LogDir`）。

### 既定値評価のタイミング

- パラメーター既定値で `$script:LogPath` を参照する場合、呼出時評価のため「呼出前に初期化済み」が前提である旨を明記。

### ログ出力先の事前作成

```powershell
$dir = Split-Path -Path $script:LogPath
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
```

## 品質保証

### PSScriptAnalyzer の活用

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
```

- 推奨ルール例: `PSUseDeclaredVarsMoreThanAssignments`, `PSAvoidGlobalVars`, `PSUseCorrectCasing`, `PSUseConsistentWhitespace`。
- 実際の実行手順は [README.md](README.md) の「7. コード品質チェック」を参照。

### Pester でのスコープ検証

- `$script:` 初期化の存在・不変性・関数からの参照可否をテストで担保。

## アンチパターン

- ループ中に共有変数へ随時追記（並列化不能・副作用拡散）。
- 暗黙のドットソースでスコープ混在（命名衝突・意図しない上書き）。
- 例外で初期化が部分的に失敗したまま続行（整合性欠如）。

## バージョン履歴

- **v1.3.0** (2026-01-21): 対象スクリプト一覧の更新
  - dotNetSdkUninstallToolの入手スクリプトを追加
  - 暗号化関連スクリプト（鍵の作成、文字列の作成、文字列の復元）を追加
  - プロジェクトの実装状況を反映

- **v1.2.0** (2026-01-13): 補足ガイド追加
  - `$global:`の取り扱い、`$module:`、並列/非同期と`$using:`、ドットソース注意点を追加
    - 読み取り専用化、コンテキスト集約、例外・後始末、`Set-StrictMode`推奨を追記
    - 設計・可読性、品質保証（PSScriptAnalyzer/Pester）、アンチパターンを補強

- **v1.1.0** (2026-01-06):
  - Excel操作スクリプトの追加対応
  - Node.js通信ブロック対応の追加
    - その他ツールの統合

- **v1.0.0** (2025-12-10): 初版リリース
  - スクリプトスコープの統一ガイドライン確立
    - 主要スクリプトへの適用完了

## 参考資料

- [PowerShell About Scopes (Microsoft Docs)](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_scopes)
- [About Modules](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_Modules)
- [About Jobs](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_Jobs)
- [Script Internationalization](https://learn.microsoft.com/powershell/scripting/learn/ps-international)
- プロジェクトREADME: `README.md`
