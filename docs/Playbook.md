# Playbook — PowerShell リポジトリ CI / 運用

## TL;DR
- このリポジトリの CI は **品質ゲート**である
- main に入るコードの健全性のみを保証する
- PowerShell / GitHub Actions の更新追従確認は **定期 CI** で行う
- CI が赤になったら **メール通知を起点に人が判断する**

---

## この Playbook の目的
本 Playbook は、  
**PowerShell リポジトリにおける CI の役割・責務・判断基準を固定する**ことを目的とする。

CI を「すべてを自動判断する装置」にしない。  
**壊れたものを通さないための最小限の防波堤**として運用する。

---

## CI の役割定義

### 常時 CI（push / pull request）
- **目的**  
  main ブランチの健全性維持

- **対象**  
  - プロダクトコード  
    - `Common/`
    - 各 `*/Script/` 配下

- **実行内容**  
  - PSScriptAnalyzer  
    - Error / Warning を失敗条件とする
  - Pester  
    - Unit テスト
    - Integration テスト（存在する場合）

- **対象外**  
  - 運用補助スクリプト
  - 一時的な検証用コード

---

### 定期 CI（四半期に一回）
- **目的**  
  以下の環境変化に追従できているかを確認する
  - PowerShell ランタイムの更新
  - GitHub Actions ランナーの更新

- **実行方法**  
  - `workflow_dispatch`
  - または `schedule`（四半期）

- **判断方針**  
  - 失敗時は GitHub からのメール通知を受け取る
  - 自動修復は行わない
  - 影響内容を確認し、人が対応を判断する

この CI は「異常検知」が目的であり、
**自動的に是正しない**。

---

## CI に含めないもの
以下は CI の品質ゲート対象外とする。

- `audit-prepublic.ps1` などの運用・監査用スクリプト
- 試行錯誤中のコード
- 一時的な検証用スクリプト

**理由**  
用途と品質基準がプロダクトコードと異なるため。

---

## CI が赤になったときの考え方
1. どの工程で失敗したかを確認する  
   - ScriptAnalyzer
   - Pester（Unit / Integration）

2. 以下の要因を優先的に疑う  
   - PowerShell バージョン更新
   - GitHub Actions ランナー更新

3. 判断に迷った場合  
   - 無理に自動化しない
   - 人が判断する余地を残す

CI は決定装置ではない。  
**判断を助けるための信号機である。**

---

## 正本・関連資料
- `PSScriptAnalyzerSettings.psd1`
- `.github/workflows/pester.yml`
- ADR-0011 / ADR-0012

---

## この Playbook について
- README には概要リンクのみを置く
- 本文はこのファイルを正本とする
- 迷ったときは、この Playbook に戻る
