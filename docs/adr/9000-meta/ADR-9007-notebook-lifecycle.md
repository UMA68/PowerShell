# ADR-9007: Copilot Notebook のライフサイクル

## Status

Accepted

## Context

Copilot Notebookは便利だが、放置すると
「知識の墓場」や「第二の倉庫」になりやすい。

これはADR-9004（設計レビュー室）に反する。

## Decision

Copilot Notebookのライフサイクルを以下に定義する。

- 作成：1テーマにつき1 Notebook
- 使用：設計レビュー・別案検討・リスク確認のみ
- 終了：判断がGitHub / Loopに反映された時点
- 廃棄：役割を終えたNotebookは閉じて参照しない

Notebookは「育てない」「整理しない」。

## Consequences

### 👍

- Notebookが増えても負債にならない
- Copilot依存を防げる

### 👎

- 過去の対話を再利用しにくい
