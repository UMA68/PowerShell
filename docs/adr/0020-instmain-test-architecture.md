# ADR-0020: InstMain 統合テストの共通化方針とテスト基盤設計

## Status

Accepted

## Context

`Tests/Integration/InstMain.Tests.ps1` は、`必要なモジュールの導入/Script/InstMain.ps1` の統合テストである。
本テストはケース数が多く、各 `It` でArrange（YAML生成、dot-source、Mock初期化）が重複しやすかったため、
可読性の低下とメンテナンスコスト増大が課題になっていた。

また、テストごとの前提が揺れると回帰時の切り分けが難しくなるため、
テスト構造を安定化し、保守性を長期的に確保する設計方針の固定が必要である。

## Decision

以下の方針で、`InstMain.Tests.ps1` のテスト設計を統一する。

### 1) 共通ヘルパー関数による Arrange の標準化

- `New-MockYaml` を利用し、テスト用YAMLデータ生成を統一する。
- `Initialize-InstMainTestEnvironment` を利用し、共通dot-source、`Test-*` 関数昇格、基本Mockを共通化する。
- `Enable-WriteCommonLogCapture` を利用し、`Write-CommonLog` のログ収集を共通化する。

### 2) Write-CommonLog の扱い

- `Initialize-InstMainTestEnvironment` では `Write-CommonLog` を昇格しない。
- `BeforeAll` でのみ `Common/Write-CommonLog.ps1` をdot-sourceし、`script:Write-CommonLog` に昇格させる。
- 各 `It` では必要に応じて `Mock Write-CommonLog` を適切に上書きする。

### 3) Pester 実行前提

- `InstMain.Tests.ps1` はPester 5系（とくに5.6.1）での実行を前提とする。
- ローカル実行では `Run-Pester5.ps1` を利用し、実行環境を固定する。

## Rationale

- Arrangeが冗長化し、テスト意図の読解コストが高くなっていたため。
- `BeforeAll` で共通初期化を標準化することで、ケース追加時の差分を最小化できるため。
- `Write-CommonLog` を複数箇所で昇格すると、Mock解決順の不安定化を招くため。
- 本リポジトリではADR文化が確立されており、本判断は将来保守に影響する設計方針として
  ADR化の基準に合致するため。

## Consequences

- テストコードの重複が減り、保守性と変更容易性が向上する。
- `Write-CommonLog` の責務と差し替えポイントが明確化され、テスト意図が読みやすくなる。
- Pester 5.x前提の実行経路が固定され、ローカル再現性と安定動作が担保される。

## Alternatives Considered

- `Initialize-InstMainTestEnvironment` 内で `Write-CommonLog` 昇格を継続する案。
  却下理由: Mock競合や解決順依存のリスクが残る。
- 各 `It` で毎回YAML生成やdot-sourceを記述する案。
  却下理由: 可読性・保守性が悪化し、修正漏れの温床になる。

## Follow-up Tasks

- ADRファイルを追加し、本方針をリポジトリの設計判断として固定する。
- `README.md` と `CONTRIBUTING.md` に、`InstMain.Tests.ps1` が本ポリシーに従う旨を追記する。

## Links

- [Tests/Integration/InstMain.Tests.ps1](../../Tests/Integration/InstMain.Tests.ps1)
- [必要なモジュールの導入/Script/InstMain.ps1](../../必要なモジュールの導入/Script/InstMain.ps1)
- [Run-Pester5.ps1](../../Run-Pester5.ps1)
- [ADR-0010: ローカル環境における Pester 5.6.1 の動作確認結果とその位置づけ](0010-local-pester-5-6-1-observation.md)