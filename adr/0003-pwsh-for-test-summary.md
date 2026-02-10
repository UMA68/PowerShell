# ADR-0003: テスト概要表示ステップで pwsh を使用する

## Status
Accepted

## Context
GitHub Actions（windows-latest）において、
PowerShell 5.1（shell: powershell）で
日本語や絵文字を含む Write-Host を実行すると、
文字化けに起因する ParserError
（"The string is missing the terminator" など）
が発生する事例が確認された。

これは、GitHub Actions が run ブロックを
一時的な .ps1 ファイルとして生成・実行する際に、
PowerShell 5.1 + UTF-8（BOM なし）の組み合わせで
文字列終端やクォート解釈が破壊されるケースがあるためと判断した。

一方、PowerShell 7（pwsh）では
UTF-8 の扱いが安定しており、
同一のスクリプト内容でも本問題は再現しない。

## Decision
テストロジック自体は変更せず、
**出力専用の「テスト概要を表示」ステップのみ**
PowerShell 7（shell: pwsh）で実行する。

- テスト実行・判定ロジックは従来どおり
- 変更差分は shell 指定のみ
- 出力内容（日本語・絵文字含む）は維持する

## Consequences

### 👍 良い点
- CI 上での ParserError が解消される
- 日本語・絵文字を含むテスト概要を安全に表示できる
- テストロジックへの影響が一切ない
- 変更範囲が最小で意図が明確

### 👎 悪い点・割り切り
- ワークフロー内で PowerShell 5.1 と 7 が混在する
- 理由を忘れると「なぜここだけ pwsh？」となりやすい

## Notes（個人用・将来削除可）
- この pwsh 指定は見た目や好みの問題ではない
- CI 安定性のための **意図的な分離**
- 誤って shell: powershell に戻さないこと