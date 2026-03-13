# ADR-0017: sqlMain と Common のテスト境界を固定する

## Status

Accepted

## Context

sqlMainは、YAML/SQL/LOGの実ファイル操作に加えて、`Invoke-Sqlcmd`、`nkf32`、`WScript.Shell`、
`Invoke-Item`、暗号化復号（`Encryption.Key` と `*.pass`）を横断する。完全なユニットテストでは
配線不整合を見逃しやすく、逆に実DBまで常時検証するとCIの安定性が低下する。

Commonの `Test-NoDoubleActivation` と `Test-Command` は、全スクリプトの実行前ガードであり、
環境依存の揺らぎを持ち込まない保証が必要である。既存方針（ADR-0002, 0008, 0009, 0010, 0013）と
整合したテスト境界を固定するため、本ADRを定義する。

## Decision

- `Tests/Integration/sqlMain.Tests.ps1` は「実ファイル操作あり・DBはMock」のIntegration寄りユニットとして扱う。
- sqlMainテストではYAML/SQL/LOGを実I/Oで検証し、`Invoke-Sqlcmd` は常時Mockする。
- `nkf32`、`WScript.Shell`（Popup）、`Invoke-Item` はMockし、外部副作用を隔離する。
- `ConvertTo-SecureString -Key` は暗号強度の評価対象にせず、復号ワイヤリング確認のためStub化する。
- Common（`NoDoubleActivation` / `CheckCommand`）は `Tests/Common` で完全ユニット化し、
  Mutex・COM・`Get-Command` をMockして仕様を固定する（現行ベースライン: 30/30 Passed）。
- 常時CIは「Commonユニット + sqlMain（DB Mock）」を対象とし、DBコンテナーを使う実SQL実行は四半期の定期CIに分離する。

## Rationale

- 常時CIを回帰検知と仕様保証に集中させ、環境変化の検知は定期CIへ分離するため。
- sqlMainは実ファイル層を残すことで、設定・パス・ログ連携の破綻を早期に検出できるため。
- Commonは失敗時の影響が大きく、環境非依存の単体保証を最優先すべきため。
- 代替案の「常時CIで実DBまで実行」はノイズ失敗が増えるため不採用。
- 代替案の「全層完全Mock」は実運用配線の不整合を見逃しやすいため不採用。

## Consequences

- 常時CIの再現性と安定性が向上し、失敗時の切り分け（仕様逸脱か環境変化か）が明確になる。
- sqlMainは実運用に近いファイル連携を維持したまま、短時間で継続検証できる。
- DB実行計画差やコンテナー依存の不具合は定期CIまで遅延検知となる。
- そのため、四半期実行の継続と結果レビューを運用上の必須条件とする。

## Links

- [ADR-0002: Pester テストを仕様の一次情報源として扱う](0002-error-handling-policy.md)
- [ADR-0008: ShowDialog の COM 解放とテスト容易性](0008-showdialog-com-release-and-testability.md)
- [ADR-0009: テスト基盤を PowerShell 7 上での Pester 実行を CI に集約する](0009-pester-test-environments.md)
- [ADR-0010: ローカル環境における Pester 5.6.1 の動作確認結果とその位置づけ](0010-local-pester-5-6-1-observation.md)
- [ADR-0013: 定期（四半期）CIを環境変化検知専用とし、人間判断を前提とする](0013-quarterly-ci-as-environment-signal.md)
- [Tests/Integration/sqlMain.Tests.ps1](../../Tests/Integration/sqlMain.Tests.ps1)
- [Tests/Common/NoDoubleActivation.Tests.ps1](../../Tests/Common/NoDoubleActivation.Tests.ps1)
- [Tests/Common/CheckCommand.Tests.ps1](../../Tests/Common/CheckCommand.Tests.ps1)
