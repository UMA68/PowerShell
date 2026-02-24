# ADR-0010: ローカル環境における Pester 5.6.1 の動作確認結果とその位置づけ

## Status
Accepted

## Context
本 ADR は、新方針の提示ではなく、既存判断の文脈で発生した事実の記録と位置づけの明確化を目的とする。

以下は既に Accepted であり、本 ADR はこれらを否定・変更しない。

- ADR-0009: テスト基盤を PowerShell 7 上での Pester 実行を CI に集約する
- ADR-9009: ADR-0009（Pester CI 集約）に対する運用ガードレール
- ADR-0003: テスト概要表示ステップで pwsh を使用する
- ADR-0005: Setup-PowerShell Action を廃止し、ランナー同梱版に統一する
- ADR-0007: Windows PowerShell 5.1 のサポート終了と PowerShell 7.x への統一
- ADR-9001: Single Source of Truth は GitHub

観測事実は次の通りである。

- ローカル開発環境（PowerShell 7.x）において、Pester 5.6.1 を AllUsers インストールした状態で、Import および最小テスト実行が成功した。
- この事実は、「Pester 5 系はローカル環境では一律に実行不能である」という一般化を否定する一次証拠である。
- 一方で ADR-0009 が定義する通り、正式な合否判定および Single Source of Truth は CI（GitHub Actions）である。

本 ADR は、動作確認という事実を ADR-0009 / ADR-9009 の判断体系内でどのように扱うかを明確化するために作成する。

## Decision
以下を決定事項とする。

1. ローカル環境において、Pester 5.6.1 は限定条件下で実行可能であることを認める。
2. ただしこれは、Pester 5 系の正式実行基盤を CI に集約するという ADR-0009 の判断を変更・緩和しない。
3. ローカルで Pester 5.6.1 を使用する場合は、`RequiredVersion` を必ず明示し、暗黙的なバージョン解決を行わない。
4. 本判断は正式採用ではなく、将来の再評価に利用可能な一次証拠の固定と位置づける。

## Alternatives Considered

1. ローカル環境でも Pester 5 系を正式な合否判定に含める
   - ADR-0009 の CI 集約方針と整合しないため不採用。
   - ADR-9009 が定義する運用ガードレール（最終判定の CI 固定）にも反する。

2. 動作確認結果を ADR として記録せず、CI のみを唯一の事実とする
   - ADR-9009 が重視する証拠保全の観点で、一次証拠の劣化リスクが増えるため不採用。
   - 将来の再評価時に比較可能な根拠が欠落する。

3. 最新版の Pester を随時ローカル利用する
   - 暗黙的なバージョン変動により再現性を損なうため不採用。
   - ADR-9009 の再評価運用（条件固定・差分追跡）と整合しない。

## Consequences

### 良い点

- 「Pester 5 系はローカルで一切動作しない」という誤解を排除できる。
- GPO / SRP / PowerShell 更新時の再評価において、比較可能な一次証拠を維持できる。
- ADR-9009 が定義する「証拠劣化」のリスクを低減できる。

### 悪い点・割り切り

- 記録された動作確認結果は、将来陳腐化する可能性がある。
- ローカル実行の成功を過信した運用は、CI 集約判断を誤用するリスクがある。

## Notes

- 本 ADR は post-hoc（事後記録）である。
- 本 ADR の目的は判断の正当化ではなく、「なぜ今この状態になっているか」を将来に説明可能にすることである。
- ADR-9009 に記載された一次証拠（Pester 5.0.0 / 5.6.1 は成功、Pester 5.7.1 では問題が再現）と矛盾しない範囲で本記録を固定する。

## Related ADRs

- [ADR-0009: テスト基盤を PowerShell 7 上での Pester 実行を CI に集約する](0009-pester-test-environments.md)
- [ADR-9009: ADR-0009（Pester CI 集約）に対する運用ガードレール](9000-meta/ADR-9009-pester-ci-centralization-guardrails.md)
- [ADR-0003: テスト概要表示ステップで pwsh を使用する](0003-pwsh-for-test-summary.md)
- [ADR-0005: Setup-PowerShell Action を廃止し、ランナー同梱版に統一する](0005-remove-setup-powershell-action.md)
- [ADR-0007: Windows PowerShell 5.1 のサポート終了と PowerShell 7.x への統一](0007-drop-windows-powershell-5.1.md)
- [ADR-9001: Single Source of Truth は GitHub](9000-meta/ADR-9001-single-source-of-truth.md)