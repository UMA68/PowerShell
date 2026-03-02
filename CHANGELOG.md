# Changelog

## 2026-03-02

- DecompileDll integration tests migrated and stabilized
  - Moved test file to `Tests/Integration/DecompileDll.Tests.ps1`
  - Fixed repository root resolution in moved test to keep `DecompileDLL/Script/DecompileDll.ps1` lookup valid
  - Verified execution paths: direct `Invoke-Pester` and `Run-Pester5.ps1 -DecompileDll`
- Test runner and docs synchronized with new path
  - Updated `Run-Pester5.ps1` default `-DecompileDll` target to `Tests/Integration/DecompileDll.Tests.ps1`
  - Updated references in `README.md`, `docs/Playbook.md`, and `Tests/README.md`
  - Added DecompileDll integration run examples (direct and runner-based)
- CI guard added for DecompileDLL WhatIf smoke step
  - Updated `.github/workflows/pester.yml` to skip the `DecompileDLL WhatIf` smoke check with `exit 0` when `ILSpyCmd` is not installed on the runner
  - Ensured `LOG` directory creation before the smoke step so log-path assumptions stay consistent
- ADR updated for temporary CI policy alignment
  - Extended `adr/0014-psscriptanalyzer-failonseverity-error-only.md` with the decision to skip `DecompileDLL WhatIf` smoke in CI environments without `ILSpyCmd`
  - Clarified rationale/consequences: avoid environment-noise failures while keeping `ILSpyCmd`-dependent validation in local or dedicated tests

## 2026-02-12

- Code quality improvements: Fixed PSScriptAnalyzer warnings across multiple files
  - **DecompileDLL/Script/DecompileDll.ps1**: Added help comments for `Write-ThreadSafeLog` function
  - **ILSpyCmdの入手/Script/Verify_v1.4.0.ps1**: Fixed automatic variable `$matches` conflict (renamed to `$regexMatches`), aligned comment formatting
  - **ILSpyCmdの入手/Script/getILSpyCmd.ps1**: Fixed whitespace consistency in hashtable definitions and end block
  - **Node.js通信ブロック対応/Script/npm_install_safe.ps1**: Moved comment-help blocks inside function definitions
  - **Tests/Common/Write-CommonLog.Tests.ps1**: Removed unused variable assignments (changed to `$null =`)
  - **Tests/Integration/ReleaseProcess.Tests.ps1**: Removed unused `$originalTime` variable
  - **リリースバッチ/Script/CopyItemCustom.ps1**: Adjusted internal function help comment positioning
  - Minor whitespace fix in PSScriptAnalyzerSettings.psd1
- All Warning/Error level issues resolved; remaining Information-level suggestions (3 items in DotNetUninstallTool.ps1) are accepted as-is for maintainability

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
