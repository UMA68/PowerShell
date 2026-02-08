# ADR-9007: Copilot Notebook のライフサイクル

## Status

Accepted

## Context

Copilot Notebook は便利だが、放置すると
「知識の墓場」や「第二の倉庫」になりやすい。

これは ADR-9004（設計レビュー室）に反する。

## Decision

Copilot Notebook のライフサイクルを以下に定義する。

- 作成：1テーマにつき1 Notebook
- 使用：設計レビュー・別案検討・リスク確認のみ
- 終了：判断が GitHub / Loop に反映された時点
- 廃棄：役割を終えた Notebook は閉じて参照しない

Notebook は「育てない」「整理しない」。

## Consequences

### 👍

- Notebook が増えても負債にならない
- Copilot 依存を防げる

### 👎

- 過去の対話を再利用しにくい
