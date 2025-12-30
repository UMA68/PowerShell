# Common フォルダー概要

プロジェクト共通で使うPowerShellユーティリティをまとめています。各 .ps1をドットソースして関数を呼び出してください。

## 前提条件

- PowerShell 5.1以上
- 必要に応じてPowerShell-Yaml (0.4.7+) — Import-YamlConfigで利用
	- インストール例: `Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7`
	- バージョン確認: `Get-Module PowerShell-Yaml -ListAvailable | Select Name,Version`
- ShowDialogオプションはWindowsのCOM (`WScript.Shell`) 依存。Linux/macOSでは無効または例外になるためオフにしてください。

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
$key    = Get-EncryptionKey -KeyPath "$($paths.Common)/Encryption.Key"  # 無ければ生成手順を案内して終了するなどのフォールバックを実装
Write-CommonLog -Message "起動完了" -LogPath "$($paths.Log)/app.log" -Level INFO

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

- [CheckCommand.ps1](Common/CheckCommand.ps1) — `Test-Command`: コマンドの存在を確認。`ShowDialog` で未検出時にポップアップ。
- [FindModule.ps1](Common/FindModule.ps1) — `Test-ModuleInstalled`: モジュールの存在と最小バージョンを確認。必要に応じてダイアログ表示。
- [Get-EncryptionKey.ps1](Common/Get-EncryptionKey.ps1) — `Get-EncryptionKey`: 鍵ファイルを読み込み、16/24/32バイトのみ受け付け。
- [Get-ScriptPaths.ps1](Common/Get-ScriptPaths.ps1) — `Get-ScriptPaths`: 実行スクリプトを基点に主要ディレクトリ（PowerShellルート、YAML、LOG、Common）と環境ファイルパスを返却。
- [Import-YamlConfig.ps1](Common/Import-YamlConfig.ps1) — `Import-YamlConfig`: YAMLをOrderedDictionaryで読み込み。PowerShell-Yaml依存。
- [NoDoubleActivation.ps1](Common/NoDoubleActivation.ps1) — `Test-NoDoubleActivation`: Mutexで二重起動を防止。`ShowDialog` で警告を表示可能。
- [Write-CommonLog.ps1](Common/Write-CommonLog.ps1) — `Write-CommonLog`: タイムスタンプ付きログ出力。INFO/WARN/ERROR/DEBUG、機密情報マスク、Quietでコンソール抑制。

## Encryption.Key について

- 用途: `Get-EncryptionKey` が読み込む対称鍵バイナリ。暗号化/復号の共通鍵として使用。
- 形式: 生のバイト列で16 / 24 / 32バイトのみ有効（UTF-8テキスト不可）。
- 配置例: Common/Encryption.Key（Git管理外で安全な場所に保管することを推奨）。
- Git管理: `.gitignore` に `Common/Encryption.Key` を追加してコミット事故を防止。
- 参照例: `$key = Get-EncryptionKey -KeyPath "$($paths.Common)/Encryption.Key"`
- 取り扱い: 秘匿情報のためコミットしない。必要に応じて権限を絞った共有ストレージに置く。
- 生成手順: [暗号化鍵の作成/Readme.md](暗号化鍵の作成/Readme.md) を参照。概要は以下の通り。
	- 実行: `./暗号化鍵の作成/Script/MakeEncrypted.ps1`（既存があれば上書き確認あり）
	- キー長: 128/192/256ビットから指定（例: `./Script/MakeEncrypted.ps1 -KeySize 256`）。
	- 出力: Common/Encryption.Keyに保存。**上書きすると既存データの復号は不可。実行前にバックアップ推奨。**

### .gitignore 例（鍵のコミット防止）

```Shell
Common/Encryption.Key
```

### 戻り値と例外の目安

| 関数 | 戻り値 | 例外/失敗時 | 推奨ハンドリング |
| --- | --- | --- | --- |
| Test-Command | `$true` / `$false` | なし（未検出は `$false`） | 未検出時に WARN/ERROR をログし中断 |
| Test-ModuleInstalled | `$true` / `$false` | なし（不足は `$false`） | 不足時に ERROR をログし中断 |
| Get-EncryptionKey | `[byte[]]` | サイズ不整合・アクセス不可で例外 | ERROR をログし中断 |
| Get-ScriptPaths | `[hashtable]` | パス計算失敗で例外 | ERROR をログし中断 |
| Import-YamlConfig | `OrderedDictionary` | モジュール未導入・YAML不備で例外 | ERROR をログし中断 |
| Test-NoDoubleActivation | `$true` / `$false` | なし（多重起動は `$false`） | 多重起動時に INFO/WARN をログし終了 |
| Write-CommonLog | なし | 書き込み不可で例外 | コンソール表示し中断 |

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
