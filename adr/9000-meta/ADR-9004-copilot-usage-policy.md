# ADR-9004: Copilot は「設計レビュー室」として使う

## Status
Accepted

## Context
Copilot を常用すると、
思考停止・過剰依存・ノイズ増加が起きやすい。

## Decision
Copilot の役割を以下に限定する。

- 設計に迷ったときのみ使用
- Loop の完成ページのみを入力する
- 生ログ・下書き・途中コードは渡さない
- 1 Notebook = 1 テーマを厳守

## Consequences
### 👍
- AI が「壁打ち相手」として機能する
- 判断の主導権を失わない

### 👎
- 便利だが頻繁には使えない