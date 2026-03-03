# ADR-0014: ScriptAnalyzer 差分チェックの FailOnSeverity を当面 Error のみにする

## Status

Accepted

## Context

本リポジトリには、`scripts/Invoke-ScriptAnalyzerChanged.ps1` を用いてGit差分（`BaseRef..HeadRef`）のみを対象にPSScriptAnalyzerを実行する仕組みがある。  
この差分解析はCI上でゲートとして運用され、差分に含まれる問題を早期に検出する役割を持つ。

これまで `FailOnSeverity` には `Warning` を含めていたため、`PSUseSingularNouns` や `PSUseConsistentWhitespace` などの軽微なスタイル警告でもCI全体が失敗していた。  
その結果、機能追加や基盤整備の進行に対して、スタイル警告が過度なブロッカーとして作用する局面があった。

## Decision

`Invoke-ScriptAnalyzerChanged.ps1` の `FailOnSeverity` は、当面 `@('Error')` のみを指定する。  
`Warning` はCIの失敗条件に含めない。

あわせて、`pester.yml` の「DecompileDLL WhatIfスモーク検証」では、CI実行環境に `ILSpyCmd` が存在しない場合は当該スモークをスキップ（`exit 0`）する。  
`ILSpyCmd` 前提の検証は、ローカル環境または別テストで担保する。

## Rationale

- DecompileDLLのCI組み込みと、差分チェック基盤そのものの安定稼働を優先するため。
- GitHub Actionsランナーでは `ILSpyCmd` が必ずしも導入済みでないため、ツール非依存の経路を不必要に失敗させないため。
- 試行錯誤フェーズでは、`Warning` レベルのスタイル指摘で開発速度が阻害されるリスクが高いため。
- ただし `Warning` を無視するわけではなく、`LOG/psscriptanalyzer-changed.json` へ出力し、継続的に観察・棚卸しを行うため。
- 将来的には `Warning` の一部を `Error` 扱いに格上げすることを検討し、段階的に品質ゲートを強化するため。

## Consequences

- `Error` が存在する場合のみCIは失敗し、品質ゲートとしての機能を維持できる。
- `ILSpyCmd` 未導入のCI環境でも、DecompileDLL WhatIfスモークは明示的にスキップされ、環境差異によるノイズ失敗を抑制できる。
- `Warning` はCIを停止しないが、JSONとログには残るため、後続の改善対象としてレビューできる。
- 運用が安定した段階で、ルール見直しサイクル（例：月次レビュー）を導入し、`Warning` の扱いを再評価する余地がある。

## Links

- [ADR-0006: PSScriptAnalyzer Information レベルの扱い](0006-psscriptanalyzer-information-level.md)
- [ADR-0009: テスト基盤を PowerShell 7 上での Pester 実行を CI に集約する](0009-pester-test-environments.md)
- [PSScriptAnalyzerSettings.psd1](../PSScriptAnalyzerSettings.psd1)
- [scripts/Invoke-ScriptAnalyzerChanged.ps1](../scripts/Invoke-ScriptAnalyzerChanged.ps1)
- [DecompileDLL/Script/DecompileDll.ps1](../DecompileDLL/Script/DecompileDll.ps1)
- [.github/workflows/pester.yml](../.github/workflows/pester.yml)