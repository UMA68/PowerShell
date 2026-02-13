# PowerShell Automation & Personal Operating System

このリポジトリは、PowerShellを主役とした
**個人自動化・検証・設計のための作業場**です。

目的は以下の3点です。

- 再現できること
- 後から理由がわかること
- 疲れていても壊れないこと

---

## 📌 Single Source of Truth

このリポジトリにおける **唯一の真実** はGitHub上のコードとADRです。

- 実装・設定・判断の最終版は **GitHub** にのみ存在します
- OneNote / Loop / Copilotは補助用途であり、正文は置きません

---

## 🧭 運用の中核（個人運用憲法）

本リポジトリの運用ルールと設計思想は、
以下の **9000番台 ADR（憲法）** に定義されています。

- [ADR-9001: Single Source of Truth は GitHub](9000-meta/ADR-9001-single-source-of-truth.md)
- [ADR-9002: OneNote / Loop / GitHub の役割分離](9000-meta/ADR-9002-roles-of-tools.md)
- [ADR-9003: 情報の昇格フロー（平日 / 週末）](9000-meta/ADR-9003-daily-flow-and-promotion.md)
- [ADR-9004: Copilot 利用方針（設計レビュー室）](9000-meta/ADR-9004-copilot-usage-policy.md)
- [ADR-9005: OS 役割分離（Windows / macOS）](9000-meta/ADR-9005-os-role-separation.md)
- [ADR-9006: 非常時プロトコル（迷ったら戻る）](9000-meta/ADR-9006-emergency-protocol.md)
- [ADR-9007: Copilot Notebook のライフサイクル](9000-meta/ADR-9007-notebook-lifecycle.md)
- [ADR-9008: 赤チーム（意地悪レビュー）運用](9000-meta/ADR-9008-red-team-review.md)

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

---

## 📋 機能・実装に関する ADR（000x シリーズ）

技術的な設計判断や実装方針は、以下に記録されています：

- [ADR-0001: Chat履歴はそのまま保存しない](0001-module-split.md)
- [ADR-0002: Pester テストを仕様の一次情報源として扱う](0002-error-handling-policy.md)
- [ADR-0003: テスト概要表示ステップで pwsh を使用する](0003-pwsh-for-test-summary.md)
- [ADR-0004: パフォーマンステストを CI の Unit / Coverage から除外する](0004-exclude-performance-tests-from-ci.md)
- [ADR-0005: Setup-PowerShell Action を廃止し、ランナー同梱版に統一する](0005-remove-setup-powershell-action.md)
- [ADR-0006: PSScriptAnalyzer Information レベルの扱い](0006-psscriptanalyzer-information-level.md) 🆕
- [ADR-0007: Windows PowerShell 5.1 のサポート終了と PowerShell Core (7.x) への統一](0007-drop-windows-powershell-5.1.md)

---

## Review Tools

- [Red Team Prompt Pack](../prompts/red-team.md)