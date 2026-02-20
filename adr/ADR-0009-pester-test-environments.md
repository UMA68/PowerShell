
# ADR-0009: テスト基盤を PowerShell 7 上での Pester 実行を CI に集約する

## Status
Accepted

## Context
本リポジトリでは以下が既存 ADR により正式に決定済みである：

- Windows PowerShell 5.1 をサポート対象外とする（ADR-0007）
- pwsh（PowerShell 7.x）を全用途で使用する（ADR-0003 / ADR-0007）
- Setup-PowerShell Action 依存を排除し、ランナー同梱版の pwsh を利用する（ADR-0005）

一方でテスト体系には、Pester 4 系と Pester 5 系という二系統が存在していた。

- **Pester 4**：レガシー互換性を持つテストフレームワーク
- **Pester 5**：PowerShell 7.x 向けのモダンテスト基盤

この二系統の混在は、以下のリスクを生んでいた：

- 誤った系統でのテスト実行
- 系統別の構文差による破壊的影響
- CI とローカル環境での再現性低下
- テスト実行環境の不透明性

加えて、ローカル環境では SRP / GPO 制約の影響を受けやすく、Pester 5 系の安定実行が保証できない状況があった。

## Decision
以下の方針を採用する。

1. **PowerShell 7.x を唯一のサポート実行基盤とする**
   - ランタイムはすべて pwsh に統一する

2. **Pester 5 系の正式実行環境を CI（GitHub Actions）に集約する**
   - CI を合否判定の唯一の正とする

3. **ローカル環境では Pester 4.10.1 を補助的に許容する**
   - ローカル実行は開発補助と位置づけ、最終判定には使用しない

4. **テストの物理ディレクトリを系統別に分離する**
   - `Tests/Pester4/` → Pester 4 系テスト
   - `Tests/Pester5/` → Pester 5 系テスト

5. **GitHub Actions を Windows / Ubuntu の 2 ジョブ構成とする**
   - `windows-latest` + `pwsh` → Pester 4 実行
   - `ubuntu-latest` + `pwsh` → Pester 5 実行
   - `powershell/setup-powershell` は使用しない（ADR-0005 に準ずる）

6. **GitHub を Single Source of Truth とする**
   - main ブランチ上の CI 結果のみを正式な判断材料とする

## Rationale

- **CI 集約による再現性の確保**  
  ローカル環境固有の SRP / GPO 制約を回避し、実行環境を固定化できる

- **系統分離による誤実行防止**  
  Pester 4 / 5 の構文差を物理的な分離で吸収し、事故を防止する

- **既存 ADR との整合性**  
  ADR-0003 / ADR-0005 / ADR-0007 の方針と矛盾しない

- **段階的移行の現実性**  
  既存 Pester 4 資産を維持しつつ、Pester 5 への移行を継続できる

## Alternatives Considered

1. **Pester 4 を廃止し、Pester 5 のみに全面移行する**
   - 書き換えコストが高く、段階的移行を阻害するため不採用

2. **Windows 上で Pester 4 / Pester 5 を両方正式運用する**
   - 環境が複雑化し、誤実行リスクが高いため不採用

3. **ローカル実行を正式な合否判定に含める**
   - 環境差により再現性が担保できないため不採用

**結論**：CI 集約が最も安全で再現性の高い選択である

## Consequences

### 👍 良い点

- **再現性の最大化**  
  合否判定が CI に一本化され、環境差分の影響を排除できる

- **事故の構造的防止**  
  テスト系統の誤実行を設計レベルで防止できる

- **移行戦略の明確化**  
  Pester 4 → 5 の移行が長期的に管理可能になる

### 👎 悪い点・割り切り

- **ローカルでは Pester 5 の完全再現ができない**  
  ローカル実行は補助確認に限定される

- **CI 実行時間の増加**  
  Windows / Ubuntu の 2 ジョブ構成により実行時間がやや増加する

## Actions

1. `Tests/Pester4/` と `Tests/Pester5/` ディレクトリを作成する
2. Pester 4 テストを pwsh 上で動作するよう最小限調整する
3. Pester 5 テストを新規作成または移植する
4. `.github/workflows/pester.yml` を 2 ジョブ構成に変更する
5. ドキュメントを「PowerShell 7.x のみサポート」に統一する
6. 本 ADR のステータスを Accepted に更新する

## Related Documents

- [ADR-0003: テスト概要表示ステップで pwsh を使用する](0003-pwsh-for-test-summary.md)
- [ADR-0005: Setup-PowerShell Action を廃止し、ランナー同梱版に統一する](0005-remove-setup-powershell-action.md)
- [ADR-0007: Windows PowerShell 5.1 のサポート終了と PowerShell Core (7.x) への統一](0007-drop-windows-powershell-5.1.md)
- [ADR-9001: Single Source of Truth は GitHub](9000-meta/ADR-9001-single-source-of-truth.md)
- [ADR-9009: ADR-0009 に対する運用ガードレール](ADR-9009-pester-ci-centralization-guardrails.final.md)
