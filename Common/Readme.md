# Common フォルダー概要

プロジェクト共通で使うPowerShellユーティリティをまとめています。各 .ps1をドットソースして関数を呼び出してください。

## 前提条件

- PowerShell 5.1以上
- 必要に応じてPowerShell-Yaml (0.4.7+) — `Import-YamlConfig` で利用
	- インストール: `Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Force`
	- バージョン確認: `Get-Module PowerShell-Yaml -ListAvailable | Select Name,Version`
	- アンインストール: `Uninstall-Module -Name PowerShell-Yaml`
- ShowDialogオプション（ダイアログ表示）はWindowsのCOM (`WScript.Shell`) に依存
	- Linux/macOSでは `ShowDialog` は無効または例外が発生するため、パラメーターを省略するか `$false` を指定してください
- 各スクリプトの詳細情報は `-Verbose` フラグで確認可能（例：`Get-Help Test-Command -Verbose`）

## 使い方

```powershell
# 例: 必要な関数だけ読み込む
. "$PSScriptRoot/CheckCommand.ps1"
. "$PSScriptRoot/FindModule.ps1"
. "$PSScriptRoot/Write-CommonLog.ps1"

# 例: リポジトリルートから Common をドットソース
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'Common/CheckCommand.ps1')
. (Join-Path $repoRoot 'Common/FindModule.ps1')
. (Join-Path $repoRoot 'Common/Write-CommonLog.ps1')

# 利用例
if (-not (Test-NoDoubleActivation -Thread "sqlMain" -ShowDialog)) { return }
if (-not (Test-Command -ComName "nkf32")) { return }
if (-not (Test-ModuleInstalled -ModuleName "PowerShell-Yaml" -MinimumVersion "0.4.7")) { return }
$paths = Get-ScriptPaths -EnvFileName "Env.yaml"
$config = Import-YamlConfig -YamlPath $paths.EnvFile
$key    = Get-EncryptionKey -KeyPath "$($paths.Common)/Encryption.key"
Write-CommonLog -Message "起動完了" -LogPath "$($paths.Log)/app.log" -Level INFO

# Test-Command について
# - ComName パラメータを省略した場合はデフォルト値 "nkf32" が使用されます
# - 前後の空白は自動削除されます（例: "  Get-Process  " → "Get-Process"）
# 典型的な失敗時のログ・中断パターン
if (-not (Test-Command -ComName "nkf32")) {
	Write-CommonLog -Message "nkf32 が見つかりません" -LogPath "$($paths.Log)/app.log" -Level WARN
	return
}
if (-not (Test-ModuleInstalled -ModuleName "PowerShell-Yaml" -MinimumVersion "0.4.7")) {
	Write-CommonLog -Message "PowerShell-Yaml が不足しています" -LogPath "$($paths.Log)/app.log" -Level ERROR
	return
}
```

## スクリプト一覧

| 関数 | ファイル | 説明 | 戻り値 | 主なパラメーター | バージョン |
| --- | --- | --- | --- | --- | --- |
| `Test-Command` | [CheckCommand.ps1](CheckCommand.ps1) | コマンドの存在を確認 | `[bool]` | `-ComName` (opt), `-ShowDialog` | v1.3.0 |
| `Test-ModuleInstalled` | [FindModule.ps1](FindModule.ps1) | モジュール存在とバージョンを確認 | `[bool]` | `-ModuleName`, `-MinimumVersion`, `-ShowDialog` | - |
| `Get-EncryptionKey` | [Get-EncryptionKey.ps1](Get-EncryptionKey.ps1) | 暗号化用鍵（16/24/32 B）を読み込み | `[byte[]]` | `-KeyPath` | - |
| `Get-ScriptPaths` | [Get-ScriptPaths.ps1](Get-ScriptPaths.ps1) | パス情報ハッシュテーブルを計算 | `[hashtable]` | `-ScriptPath`, `-EnvFileName` | - |
| `Import-YamlConfig` | [Import-YamlConfig.ps1](Import-YamlConfig.ps1) | YAML を OrderedDictionary で読み込み | `[OrderedDictionary]` | `-YamlPath` | - |
| `Test-NoDoubleActivation` | [NoDoubleActivation.ps1](NoDoubleActivation.ps1) | Mutex で二重起動を防止 | `[bool]` | `-Thread`, `-ShowDialog` | - |
| `Write-CommonLog` | [Write-CommonLog.ps1](Write-CommonLog.ps1) | タイムスタンプ付きログ出力 | `[void]` | `-Message`, `-LogPath`, `-Level`, `-SensitivePatterns`, `-Quiet` | - |

詳細は各ファイルの `Get-Help` を参照してください。

## Encryption.key について

- 用途: `Get-EncryptionKey` が読み込む対称鍵バイナリ。暗号化/復号の共通鍵として使用。
- 形式: 生のバイト列で16 / 24 / 32バイトのみ有効（UTF-8テキスト不可）。
- 配置例: Common/Encryption.key（Git管理外で安全な場所に保管することを推奨）。
- Git管理: `.gitignore` に `Common/Encryption.key` を追加してコミット事故を防止。
- 参照例: `$key = Get-EncryptionKey -KeyPath "$($paths.Common)/Encryption.key"`
- 取り扱い: 秘匿情報のためコミットしない。必要に応じて権限を絞った共有ストレージに置く。
- 生成手順: [暗号化鍵の作成/Readme.md](暗号化鍵の作成/Readme.md) を参照。概要は以下の通り。
	- 実行: `./暗号化鍵の作成/Script/MakeEncrypted.ps1`（既存があれば上書き確認あり）
	- キー長: 128/192/256ビットから指定（例: `./Script/MakeEncrypted.ps1 -KeySize 256`）。
	- 出力: Common/Encryption.keyに保存。**上書きすると既存データの復号は不可。実行前にバックアップ推奨。**

### .gitignore 例（鍵のコミット防止）

```Shell
Common/Encryption.key
```

### 戻り値と例外の目安

| 関数 | 戻り値 | 例外/失敗時 | 推奨ハンドリング |
| --- | --- | --- | --- |
| Test-Command | `$true` / `$false` | なし（未検出は `$false`） | 未検出時に WARN/ERROR をログし中断 |
| Test-ModuleInstalled | `$true` / `$false` | なし（不足は `$false`） | 不足時に ERROR をログし中断 |
| Get-EncryptionKey | `[byte[]]` | 無効サイズ・アクセス不可で例外 | 例外をキャッチし ERROR ログして中断 |
| Get-ScriptPaths | `[hashtable]` | パス計算失敗で例外 | 例外をキャッチし ERROR ログして中断 |
| Import-YamlConfig | `OrderedDictionary` \| `$null` | モジュール未導入・YAML 不備で例外、空ファイルは $null | 例外/null をキャッチし ERROR ログして中断 |
| Test-NoDoubleActivation | `$true` / `$false` | なし（多重起動は `$false`） | 多重起動時に INFO/WARN ログして終了 |
| Write-CommonLog | `[void]` | 書き込み不可で例外 | 例外をキャッチし中断 |

詳細な例外型（UnauthorizedAccessException、IOExceptionなど）は各スクリプトのヘルプ（`Get-Help 関数名`）を参照してください。

## Get-ScriptPaths が返却するパス構造

```Shell
PowerShell ルート/
├─ Upper (スクリプト実行フォルダの親)
│  ├─ YAML (paths.Yaml - 設定ファイル)
│  ├─ LOG (paths.Log - ログファイル)
│  └─ Script (paths.Script - スクリプト実行ディレクトリ)
├─ Common (paths.Common - 共通スクリプト)
└─ PowerShell (paths.PowerShell - プロジェクトルート)
```

例：リポジトリが `C:\repo\PowerShell` の場合

- `paths.PowerShell` → `C:\repo\`
- `paths.Upper` → `C:\repo\PowerShell\Script`（スクリプト実行フォルダーの親）
- `paths.Yaml` → `C:\repo\PowerShell\Script\YAML`
- `paths.Log` → `C:\repo\PowerShell\Script\LOG`
- `paths.Common` → `C:\repo\PowerShell\Common`

## Verbose/Debug 情報の活用

各関数は `-Verbose` フラグで詳細情報を出力します：

```powershell
# Test-Command の例
Test-Command -ComName "powershell" -Verbose
# VERBOSE: コマンド 'powershell' が見つかりました。(型: Application, パス: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe)

# Get-ScriptPaths の例
Get-ScriptPaths -Verbose
# VERBOSE: パス計算完了: Script=C:\repo\PowerShell\Script, PowerShell=C:\repo\

# Get-EncryptionKey の例
Get-EncryptionKey -KeyPath "C:\Keys\aes256.key" -Verbose
# VERBOSE: 鍵ファイルを読み込みました。パス: C:\Keys\aes256.key、鍵サイズ: 32 バイト

# Test-ModuleInstalled の例
Test-ModuleInstalled -ModuleName "SqlServer" -MinimumVersion "22.1.1" -Verbose
# VERBOSE: モジュール 'SqlServer' (バージョン: 22.2.0) が見つかりました。
```

## 併用のヒント

- バッチ/スケジューラ実行時は `Test-NoDoubleActivation` で多重起動を防ぎ、続けて `Write-CommonLog` で進捗を記録する構成が便利です。
- 設定ファイルを扱うスクリプトは `Get-ScriptPaths` でパスを揃え、`Import-YamlConfig` で読み込み、必要なら `Test-ModuleInstalled` で依存モジュールを確認してください。
- エラー処理の定型例:

	```powershell
	try {
			$config = Import-YamlConfig -YamlPath $paths.EnvFile
	}
	catch {
			Write-CommonLog -Message "設定読み込み失敗: $($_.Exception.Message)" -LogPath "$($paths.Log)/app.log" -Level ERROR
			return
	}
	```

## 機密情報マスキングについて

`Write-CommonLog` は `-SensitivePatterns` パラメーターで機密情報をマスキングします：

```powershell
# 例: パスワードと API キーを自動マスク
Write-CommonLog `
    -Message "ログイン試行: password=MySecret123, api_key=abcd1234efgh5678" `
    -LogPath "C:\Logs\app.log" `
    -SensitivePatterns @('password', 'api_key')
# ログ出力: 2026-01-14 14:30:00 [INFO] - ログイン試行: password=***, api_key=***
```

マスク対象：パターン直後に `:` `=` またはスペースが続く値をすべて置き換え

## セキュリティのベストプラクティス

### Get-EncryptionKey の安全な使用

- 鍵ファイルは `.gitignore` に指定してバージョン管理から除外
- ファイルアクセス権を制限（例：所有者のみ読み取り可能）
- 本番環境ではAzure Key VaultやHashiCorp Vaultなどの鍵管理システム推奨
- 参考: [暗号化鍵の作成/Readme.md](../暗号化鍵の作成/Readme.md)

### ログ出力のベストプラクティス

- `Write-CommonLog` で自動的に機密情報をマスク
- ログレベルを適切に設定（DEBUGは開発時のみ有効にする）
- ログファイルのアクセス権を制限
