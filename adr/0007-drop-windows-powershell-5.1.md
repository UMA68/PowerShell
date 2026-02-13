# ADR-0007: Windows PowerShell 5.1 のサポート終了と PowerShell Core (7.x) への統一

## Status

Accepted

## Context

2026-02-13 時点の判断として記録する。

本リポジトリはPowerShellを中心とした自動化・検証の作業場であり、
再現性と運用の単純化を重視している。

近年の運用ではPowerShell 7.xを主軸に整備されており、
Windows PowerShell 5.1との両対応は以下の課題を生んでいる：

- 実行環境差分による挙動の分岐と検証コストの増大
- CIとローカルの差分が広がり、再現性が下がる
- 「真実はGitHub」「再現性を最優先」といった運用原則との乖離

## Decision

以下の方針を採用する：

1. 本リポジトリの正式サポートはPowerShell Core (7.x) のみに統一する
2. Windows PowerShell 5.1の動作保証を廃止する
3. GitHub Actionsはwindows-latest同梱のpwshで実行し、PowerShell 7.1と最新バージョンのみをテスト対象とする
   - `powershell/setup-powershell` は使用しない
4. ローカルではPowerShell 7.xの複数バージョンでマトリックステストを実施する
5. 必要に応じて、将来PowerShell 5.1専用リポジトリを新設する

## Rationale

- PowerShell 7.xはクロスプラットフォームであり、将来的な保守性が高い
- 5.1互換性維持のための分岐と検証は、実運用の価値に対して過剰
- CIの対象を明確化することで、テストの意味と再現性が担保される
- 運用原則（真実はGitHub、再現性最優先）と整合した判断である

## Alternatives Considered

1. 5.1と7.xの両方を正式サポートとする
   - 互換性維持のための分岐・テスト負荷が大きく、再現性が下がる
2. CIのみ7.x、ローカルで5.1を許容する
   - 仕様の一次情報源が不一致になり、運用原則と矛盾する

## Consequences

### 👍 良い点

- 実行環境が7.xに統一され、再現性と運用の単純化が進む
- CIとローカルの差分が縮小し、テスト結果の信頼性が上がる

### 👎 悪い点・割り切り

- 5.1での動作は保証対象外となる
- 5.1向けの要求が発生した場合、別リポジトリでの対応が必要になる

## Actions

- GitHub ActionsのPesterワークフローを7.1と最新バージョンのみに整理する
- ローカル検証用に7.xの複数バージョンを用意し、マトリックステスト手順を明文化する
- READMEと必要なドキュメントに「5.1非対応」を明示する

## Related Documents

- [ADR-0003: テスト概要表示ステップで pwsh を使用する](0003-pwsh-for-test-summary.md)
- [ADR-0005: Setup-PowerShell Action を廃止し、ランナー同梱版に統一する](0005-remove-setup-powershell-action.md)
- [ADR-9001: Single Source of Truth は GitHub](9000-meta/ADR-9001-single-source-of-truth.md)
- [ADR-9003: 情報の昇格フロー（平日 / 週末）](9000-meta/ADR-9003-daily-flow-and-promotion.md)
