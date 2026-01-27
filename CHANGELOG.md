# Changelog

## 2026-01-27

- Help updates for `暗号化文字列の作成/Script/MakeEncryptedString.ps1` and `暗号化文字列の復元/Script/StringDecryption.ps1`
  - Clarified default key file and options; aligned `.LINK` paths
  - Version/date bumped to reflect latest state
- Docs unification: standardized key file naming to `Encryption.key` across Readme files
  - Updated: Common, 暗号化鍵の作成, SQLクエリー実行, Excel/ExportExcel, リリースバッチ, root README
  - Note: Windows is case-insensitive; existing files named `Encryption.Key` remain compatible
- PSScriptAnalyzer settings tweak
  - Allowed interactive `Write-Host` via `ExcludeRules` (for explicit options like `-ShowInConsole`)
- Minor style fixes (whitespace) in `暗号化鍵の作成/Script/MakeEncrypted.ps1`
