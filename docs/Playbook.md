# Playbook — PowerShell リポジトリ CI / 運用

## TL;DR
- このリポジトリのCIは **品質ゲート**である
- mainに入るコードの健全性のみを保証する
- PowerShell / GitHub Actionsの更新追従確認は **定期 CI** で行う
- CIが赤になったら **メール通知を起点に人が判断する**

---

## この Playbook の目的
本Playbookは、  
**PowerShell リポジトリにおける CI の役割・責務・判断基準を固定する**ことを目的とする。

CIを「すべてを自動判断する装置」にしない。  
**壊れたものを通さないための最小限の防波堤**として運用する。

---

## CI の役割定義

### 常時 CI（push / pull request）
- **目的**  
  mainブランチの健全性維持

- **対象**  
  - プロダクトコード  
    - `Common/`
    - 各 `*/Script/` 配下

- **実行内容**  
  - PSScriptAnalyzer  
    - Error / Warningを失敗条件とする
  - Pester  
    - Unitテスト
    - Integrationテスト（存在する場合）

- **対象外**  
  - 運用補助スクリプト
  - 一時的な検証用コード

---

### 定期 CI（四半期に一回）
- **目的**  
  以下の環境変化に追従できているかを確認する
  - PowerShellランタイムの更新
  - GitHub Actionsランナーの更新

- **実行方法**  
  - `workflow_dispatch`
  - または `schedule`（四半期）

- **判断方針**  
  - 失敗時はGitHubからのメール通知を受け取る
  - 自動修復は行わない
  - 影響内容を確認し、人が対応を判断する

このCIは「異常検知」が目的であり、
**自動的に是正しない**。

---

## CI に含めないもの
以下はCIの品質ゲート対象外とする。

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
   - PowerShellバージョン更新
   - GitHub Actionsランナー更新

3. 判断に迷った場合  
   - 無理に自動化しない
   - 人が判断する余地を残す

CIは決定装置ではない。  
**判断を助けるための信号機である。**

---

## 正本・関連資料
- `PSScriptAnalyzerSettings.psd1`
- `.github/workflows/pester.yml`
- ADR-0011 / ADR-0012

---

## この Playbook について
- READMEには概要リンクのみを置く
- 本文はこのファイルを正本とする
- 迷ったときは、このPlaybookに戻る
