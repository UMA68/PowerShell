# ADR-9001: Single Source of Truth は GitHub とする

## Status
Accepted

## Context
個人開発・検証において、
OneNote / Loop / Copilot / OneDriveに情報が分散すると、
差分・履歴・再現性が失われやすい。

とくにPowerShellスクリプトでは、
「どれが正か分からない」状態が
致命的な運用ミスにつながる。

## Decision
本運用では、以下を採用する。

- **コードと実行物の真実は GitHub のみ**
- Loop / OneNote / Copilotにはコード全文を置かない
- LoopにはGitHubへのリンクのみを残す
- diff・履歴・再現性を最優先する

## Consequences
### 👍
- 迷ったらGitHubを見ればよい
- 履歴と判断が必ず追える

### 👎
- Loop単体では完結しない
- GitHubが使えない環境では作業できない