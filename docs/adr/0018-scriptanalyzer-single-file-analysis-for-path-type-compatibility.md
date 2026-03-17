# ADR-0018: PSScriptAnalyzer の Path 型差異を吸収するため、差分チェック実装を単一ファイル解析方式に変更する

## Status

Accepted

## Context

GitHub ActionsランナーがPowerShell 7.5.5に更新されたタイミングで、
scripts/Invoke-ScriptAnalyzerChanged.ps1の実行時に以下のエラーが発生するようになった。

```text
Cannot convert 'System.Object[]' to the type 'System.String' required by parameter 'Path'.
```

ローカル環境で確認したところ、Invoke-ScriptAnalyzerのPathパラメーター型が
System.Stringとして公開されており、複数ファイルを配列のまま渡すと
パラメーターバインディングが失敗することが分かった。

従来実装では、Git差分BaseRef..HeadRefから抽出した変更ファイル一覧を配列でまとめて
Invoke-ScriptAnalyzer -Pathに渡していた。
しかし、この方式はPowerShell本体やPSScriptAnalyzerのバージョン差に影響され、
CI上で不安定化することが判明した。

## Decision

scripts/Invoke-ScriptAnalyzerChanged.ps1の差分チェック実装を、
単一ファイル解析方式に変更する。

- Invoke-ScriptAnalyzer -Pathへ配列を一括渡しする方式を廃止する
- 差分抽出後、変更ファイル1件につき1回Invoke-ScriptAnalyzerを呼び出す
- Get-ChangedFileの戻り値は@(...)で常に配列として扱い、0件、1件、複数件のいずれでも型揺れを防ぐ
- Invoke-ScriptAnalyzerの戻り値はforeach ($item in @($fileResults))で収集し、null、1件、複数件のいずれでも安定して集約する

## Rationale

- Pathがstringとstring[]のどちらで公開されるかに依存した実装は、実環境差異により保守コストが高い
- GitHub Actions上ではPathがstringとして公開されており、配列一括渡しは実際に失敗した
- 差分チェックの対象は通常少数ファイルであり、ファイル単位でのInvoke-ScriptAnalyzer呼び出しによる性能影響は実用上無視できる
- ランタイム更新や依存モジュール更新があってもCIを安定動作させることを優先する

## Consequences

- scripts/Invoke-ScriptAnalyzerChanged.ps1は、PSScriptAnalyzerのPath型差異を吸収できるようになる
- GitHub Actionsにおける差分チェックは、PowerShellやモジュール更新の影響を受けにくくなる
- PSScriptAnalyzerSettings.psd1や既存テストコードには影響しない
- 差分チェックの性能は理論上わずかに低下するが、対象件数が少ないため許容範囲とする

## Options Considered

1. Invoke-ScriptAnalyzer -Path([string[]]$displayTargets)のように強制キャストする

ある環境では動作する可能性があるが、別環境で再び型バインディングが壊れる余地があり、
長期的には不安定と判断した。

2. PSScriptAnalyzerのバージョンを固定する

本リポジトリは、ランタイム更新や依存更新の影響をCIで検知する運用を重視している。
そのため、問題を環境固定で隠すよりも、差異を吸収できる実装側の改善を優先した。

## Follow-up

- 将来、PSScriptAnalyzerがPath=string[]を明確にサポートし、その仕様が安定した場合は一括解析方式への回帰を再評価する

## Links

- [ADR-0011: リポジトリ全体に対する PSScriptAnalyzer 実行方針を確定する](0011-repository-wide-scriptanalyzer-policy.md)
- [ADR-0012: PSScriptAnalyzer を CI に組み込むタイミングとローカル実行との責務分離](0012-scriptanalyzer-ci-and-local-responsibilities.md)
- [ADR-0014: ScriptAnalyzer 差分チェックの FailOnSeverity を当面 Error のみにする](0014-psscriptanalyzer-failonseverity-error-only.md)
- [scripts/Invoke-ScriptAnalyzerChanged.ps1](../../scripts/Invoke-ScriptAnalyzerChanged.ps1)
- [PSScriptAnalyzerSettings.psd1](../../PSScriptAnalyzerSettings.psd1)