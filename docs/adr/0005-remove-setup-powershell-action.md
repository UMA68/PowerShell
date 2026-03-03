# ADR-0005: Setup-PowerShell Action を廃止し、ランナー同梱版に統一する

## Status

Accepted

## Context

GitHub ActionsのPesterワークフロー（`.github/workflows/pester.yml`）において、
PowerShell 7.xのバージョンをmatrixで切り替えるため
`powershell/setup-powershell@v2` Actionを使用していた。

しかし、以下の重大な問題が発生した：

- `powershell/setup-powershell@v2` がGitHub Marketplaceから取得できず、
  ワークフロー準備フェーズで  
  **"Unable to resolve action powershell/setup-powershell, repository not found"**  
  エラーが発生
- CIがPester実行前に停止し、
  テスト自体が一切実行されない状況に陥った
- このリポジトリのCIは **ADR-0003 / ADR-0004** の流れで
  安定性とシンプル化を段階的に優先してきており、
  外部Actionへの依存はリスク要因となっていた

一方、以下の事実も確認された：

- **windows-latest** ランナーには
  PowerShell 5.1とPowerShell 7.xが **標準で同梱**されている
- `shell: powershell` および `shell: pwsh` で直接実行すれば、
  追加のActionを必要としない
- matrixで複数のPowerShell 7.xバージョンをテストする必要性も、
  現在の開発規模では限定的である

## Decision

以下の方針を採用する：

1. **`powershell/setup-powershell@v2` Action を完全に削除する**
2. 全ステップは  
   `shell: powershell`（Windows PowerShell 5.1）または  
   `shell: pwsh`（PowerShell 7.x）で **直接実行**する
3. ランナー標準環境（windows-latest同梱版）を  
   **CI の唯一の PowerShell 実行環境**とする
4. PowerShell 7.xのmatrixテストは  
   **当面不要と判断し、廃止**する
   - 必要になった場合は別の仕組み（例: Docker、別Action）を検討

## Consequences

### 👍 良い点

- **CI が即座に安定化する**（外部Actionの取得失敗が根本解決）
- 外部依存が減り、**ワークフロー準備フェーズの失敗リスクが低下**
- ランナー標準環境を使うため、  
  ローカル検証とCIの再現性が向上する
- ワークフロー構成がシンプルになり、  
  **ADR-0003 / ADR-0004 の流れと一貫性がある**
- matrixの複雑性が消え、ログの追跡が容易になる

### 👎 悪い点・割り切り

- PowerShell 7.xの特定バージョン（7.3 / 7.4 / 7.5）を  
  個別にテストできなくなる
  - 将来的に必要になった場合は、別の仕組みで対応する必要がある
- ランナーの同梱バージョンに依存するため、  
  GitHubがランナーイメージを変更した場合の影響を受ける
  - ただし、これはsetup-powershell Actionでも同様のリスクがある

## Notes（個人用・将来削除可）

- この判断は **ADR-0003（pwsh による文字化け回避）** および  
  **ADR-0004（Performance テスト除外）** と連続した  
  **CI 設計改善の第三段階**である
- 今回の障害は「CIが動かない」というもっとも重大なレベルであり、  
  即座の対応が必要だった
- 将来的にPowerShell 7.xの特定バージョンテストが必要になった場合は、
  本ADRを前提に「別ワークフロー」または「Dockerコンテナー」を検討する
- **Loop は正本**であるため、  
  この文書は最終版として成形されている
