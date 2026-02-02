# ADR-9002: OneNote / Loop / GitHub の役割分離

## Status
Accepted

## Context
思考・試行・決定を同じ場所で行うと、
情報が混ざり、再利用できなくなる。

## Decision
ツールの役割を以下に固定する。

- **OneNote**：実験ログ・試行錯誤・感情込みの生ログ
- **Loop**：再利用できる技術知見の正本
- **GitHub**：コード・ADR・実行物の唯一の保管場所

Loopに書かれた時点で「正」とみなす。

## Consequences
### 👍
- 書く場所に迷わない
- Loopの品質が自然に上がる

### 👎
- OneNoteは後から読む前提ではない