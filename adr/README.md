# PowerShell Automation & Personal Operating System

このリポジトリは、PowerShell を主役とした
**個人自動化・検証・設計のための作業場**です。

目的は以下の3点です。

- 再現できること
- 後から理由がわかること
- 疲れていても壊れないこと

---

## 📌 Single Source of Truth

このリポジトリにおける **唯一の真実** は GitHub 上のコードと ADR です。

- 実装・設定・判断の最終版は **GitHub** にのみ存在します
- OneNote / Loop / Copilot は補助用途であり、正文は置きません

---

## 🧭 運用の中核（個人運用憲法）

本リポジトリの運用ルールと設計思想は、
以下の **9000番台 ADR（憲法）** に定義されています。

- [ADR-9001: Single Source of Truth は GitHub](adr/9000-meta/ADR-9001-single-source-of-truth.md)
- [ADR-9002: OneNote / Loop / GitHub の役割分離](adr/9000-meta/ADR-9002-roles-of-tools.md)
- [ADR-9003: 情報の昇格フロー（平日 / 週末）](adr/9000-meta/ADR-9003-daily-flow-and-promotion.md)
- [ADR-9004: Copilot 利用方針（設計レビュー室）](adr/9000-meta/ADR-9004-copilot-usage-policy.md)
- [ADR-9005: OS 役割分離（Windows / macOS）](adr/9000-meta/ADR-9005-os-role-separation.md)
- [ADR-9006: 非常時プロトコル（迷ったら戻る）](adr/9000-meta/ADR-9006-emergency-protocol.md)
- [ADR-9007: Copilot Notebook のライフサイクル](adr/9000-meta/ADR-9007-notebook-lifecycle.md)
- [ADR-9008: 赤チーム（意地悪レビュー）運用](adr/9000-meta/ADR-9008-red-team-review.md)

👉 **迷ったら、まずここを読む。**

---

## 📂 リポジトリ構成（概要）

```text
adr/
 ├─ 000x-xxxx/        # 機能・実装に関する設計判断
 └─ 9000-meta/        # 個人運用憲法・安全装置（最優先）

src/                  # PowerShell スクリプト
tests/                # Pester テスト
```

## Review Tools

- Red Team Prompt Pack: ../prompts/red-team.md