# ADR-0006: PSScriptAnalyzer Information レベルの扱い

## Status

Accepted

## Context

PSScriptAnalyzerはPowerShellスクリプトのコード品質を保つための重要なツールで、以下の3つのレベルで問題を報告する：

- **Error**: 実行エラーを引き起こす可能性のある深刻な問題
- **Warning**: 推奨されないパターンやバグの潜在的原因
- **Information**: コードの読みやすさや保守性を向上させるための提案

2026年2月のコード品質改善作業において、以下の状況が確認された：

1. Warning/Errorレベルの問題は、すべて修正可能で明確な品質上の利点がある
2. Informationレベルの警告（とくに `PSProvideCommentHelp`）は、以下の特性を持つ：
   - 関数に詳細なヘルプコメントを追加することを推奨
   - ヘルプがなくても機能上の問題はない
   - プライベート関数（processブロック内の内部関数など）への適用は、コードの可読性を低下させる場合がある
   - 構造的な大幅変更が必要になる場合がある（例: DotNetUninstallTool.ps1の3関数）

とくに `DotNetUninstallTool.ps1` では、以下の3関数がprocessブロック内に定義されており、Informationレベルの警告が出ている：

- `Show-Menu` (行440)
- `Install-UninstallTool` (行464)
- `Uninstall-UninstallTool` (行598)

これらを修正するには、関数をスクリプトスコープに移動する必要があるが、それはスクリプトの構造を大きく変更することを意味する。

## Decision

本リポジトリでは、PSScriptAnalyzerの警告レベルに応じて以下の方針を採用する：

### 1. 必須対応レベル（Error / Warning）

- **Error** レベル：必ず修正する（例外なし）
- **Warning** レベル：原則として修正する
  - 修正が困難な場合は、理由をADRまたはREADMEに記録した上で `ExcludeRules` に追加する

### 2. 推奨レベル（Information）

- **Information** レベル：修正を推奨するが、必須ではない
- 以下の場合は警告を許容する：
  - 内部関数やプライベート関数で外部公開しない場合
  - コメントヘルプの追加がコードの可読性を低下させる場合
  - 修正に大規模な構造変更が必要で、リスクが利益を上回る場合
- 許容する場合は、その判断理由を記録する（CHANGELOGまたはADR）

### 3. コード品質ゲートの基準

CIや手動チェックでは：

```powershell
# Warning/Error のみをブロック（Information は許容）
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 |
  Where-Object { $_.Severity -in 'Error', 'Warning' }
```

## Consequences

### 👍 良い点

- **現実的な品質基準**: 完璧主義に陥らず、実用的な品質を保つ
- **メンテナンス性**: 大規模な構造変更を避け、既存コードの安定性を維持
- **柔軟性**: プロジェクトの成熟度に応じて、段階的にInformationレベルも対応可能
- **明確な基準**: Error/Warningは必須、Informationは推奨という明確な線引き

### 👎 注意点

- **ドキュメント不足のリスク**: Informationを許容した関数は、コメントが不足する可能性
  - 軽減策: READMEや使用例で補完する
- **段階的な改善の必要性**: 将来的にInformationレベルも対応する計画が望ましい
  - 軽減策: リファクタリング時に併せて対応する

### 📝 関連ファイル

- [PSScriptAnalyzerSettings.psd1](../PSScriptAnalyzerSettings.psd1)
- [CHANGELOG.md](../CHANGELOG.md)（現時点では英語ベース、2026-02-12エントリ）
- [README.md](../README.md) (コード品質チェックセクション）

### 🔄 今後の見直し

以下のタイミングで本方針を再評価する：

- リポジトリが外部公開される場合
- CI/CDパイプラインを導入する場合
- コードベースが大幅に拡大した場合（現在の3倍以上）

## References

- [PSScriptAnalyzer - GitHub](https://github.com/PowerShell/PSScriptAnalyzer)
- [PSScriptAnalyzer Rules](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/readme)
