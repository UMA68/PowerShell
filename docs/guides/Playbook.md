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

### ローカル再現コマンド（DecompileDLL Integration）
- `DecompileDLL/Script/DecompileDll.ps1` の統合テストは `Tests/Integration/DecompileDll.Tests.ps1` を正本とする
- 実行コマンド（Pester 5ランナー経由）

```powershell
pwsh -NoProfile -File .\Run-Pester5.ps1 -DecompileDll
```

- 実行コマンド（直接実行）

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path .\Tests\Integration\DecompileDll.Tests.ps1"
```

- 備考: `Show-ErrorPopup` がブロッキングになる2ケース（`Error-FileNotFound-OldEmpty` / `Error-GeneralError-InvalidYaml`）は、CI向けに `Skip` で運用する

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

※ 定期（四半期）CIを自動判断しない理由は
[ADR-0013: 定期（四半期）CIを環境変化検知専用とし、人間判断を前提とする](../ADR/0013-quarterly-ci-as-environment-signal.md) に定義されている。

---

## ScriptAnalyzer（差分チェック）運用指針

### 目的
`scripts/Invoke-ScriptAnalyzerChanged.ps1` による差分チェック運用の目的は、
**mainに入る変更で、直ちに危険な問題だけを確実に止める**ことにある。

CIを「すべてを自動判定する装置」にしない。  
ScriptAnalyzerも、判断を助けるための信号機として扱う。

### 常時 CI における役割
- `pester.yml` の品質ゲートで、Git差分（`BaseRef..HeadRef`）に対して
  `scripts/Invoke-ScriptAnalyzerChanged.ps1` を実行する
- 対象は「今回の変更に含まれるPowerShellスクリプト」に限定する
- これにより、全量検査の重さを避けつつ、変更起点の品質低下を検知する

### FailOnSeverity の扱い（現行）
- FailOnSeverityは `@('Error')` のみを失敗条件とする
- Warningは検知しても、常時CIの失敗条件には含めない

### Warning をゲートから除外した理由
- これまでError / Warningの両方をゲートにしていたため、
  軽微なWarningでCIが不要に赤くなるケースが多発した
- 品質ゲートのノイズが増えると、
  本当に止めるべき異常（Error）の信号が埋もれる
- そのため、常時CIでは「止めるべきもの」をErrorに絞る

### Warning をログに残す運用
- Warningを無視するのではなく、JSONに蓄積して後から棚卸しする
- 出力先は `LOG/psscriptanalyzer-changed.json`
- 常時CIでは「即時停止」と「継続的改善」を分離して扱う

### DecompileDLL スモークと ILSpyCmd の扱い
- ⚙️ `DecompileDLL/Script/DecompileDll.ps1` は、`ILSpyCmd` を前提とした逆コンパイルスクリプトである
- ⚠️ CIランナーに `ILSpyCmd` が存在しない場合、DecompileDLLのWhatIfスモークは実行せず、
  ステップ内で警告を出して `exit 0` でスキップする
- 📝 スキップ時はログ上で理由を明示する（例: `ILSpyCmd が見つからないためスキップ`）
- 🧪 `ILSpyCmd` 前提の挙動検証は、ローカル実行や
  `Tests/Integration/DecompileDll.Tests.ps1` などのIntegrationテストで担保する
- 🚦 この設計は「CIは決定装置ではなく信号機である」という
  Playbook全体の方針に沿って、常時CIの信号品質を優先するための運用である

### 将来的な見直し
- 蓄積したWarningは定期的に棚卸しし、
  影響の大きいものから修正・ルール化する
- 運用が安定した領域は、
  Warning → Errorへ段階的に格上げすることを検討する

この方針は、CIを判断装置にしないというPlaybook全体の原則に従う。  
**CIは決定装置ではなく、判断を支援する信号機である。**

### ADR 参照
- [ADR-0014: PSScriptAnalyzerのFailOnSeverityをErrorのみに変更する](../adr/0014-psscriptanalyzer-failonseverity-error-only.md)

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

## CI が赤のまま許容される条件（チェックリスト）

```info
このチェックリストは「CIを緑に戻すこと」よりも  
「判断を誤らないこと」を優先するために存在する。
```

以下すべてに ✅ が付く場合、**CI が赤の状態を一時的に許容してよい**。

### 前提条件

- [ ] 失敗しているCIは **定期 CI（四半期）** である  
- [ ] 失敗は **コード変更を伴わない実行** で発生している  
- [ ] 常時CI（push / PR）は **すべてグリーン** である  

### 原因に関する確認

- [ ] 失敗要因が **PowerShell ランタイム更新** または  
      **GitHub Actions ランナー更新** に起因していると判断できる
- [ ] プロダクトコードの不具合ではないことを  
      ログ・差分・直近変更から説明できる

### 判断と記録

- [ ] 失敗内容を **把握・理解したうえで意図的に放置している**
- [ ] 必要であれば、Issue / メモ / Commitコメント等に  
      「なぜ今は対応しないか」を簡潔に残している
- [ ] 次回の定期CIまたは、関連作業時に  
      再確認する前提が共有されている

---

⚠️ 上記のいずれかに ❌ が付く場合、  
**CI を赤のままにしてよいか再検討すること。**

※ 本チェックリストは「自動判断」ではなく、  
**人間の判断を補助するためのもの**である。  
設計判断の背景については  
[ADR-0013: 定期（四半期）CIを環境変化検知専用とし、人間判断を前提とする](../ADR/0013-quarterly-ci-as-environment-signal.md) を参照。

---

> 🔗 定期（四半期）CI を「環境変化検知専用」とし、人間判断を前提とする設計判断については
> [ADR-0013: 定期（四半期）CIを環境変化検知専用とし、人間判断を前提とする](../ADR/0013-quarterly-ci-as-environment-signal.md) を参照する。

---

## 正本・関連資料
- `PSScriptAnalyzerSettings.psd1`
- `.github/workflows/pester.yml`
- ADR-0011 / ADR-0012 / ADR-0013

---

## この Playbook について
- READMEには概要リンクのみを置く
- 本文はこのファイルを正本とする
- 迷ったときは、このPlaybookに戻る
