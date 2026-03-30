# ADR-0021: Podman Desktop Accounts において GitHub Account ログインを採用しない判断

## Status

Accepted

## Context

Podman DesktopにはAccounts機能があり、GitHub AccountによるOAuthログインが可能である。
現行運用の前提は以下のとおりである。

- コンテナー操作はPodman CLIを主軸とし、Podman Desktopは可視化・補助UIとして位置づけている。
- ghcr.ioへの認証は `podman login`（PAT・最小権限）で完結している。
- CI/CDはGitHub Actionsの `GITHUB_TOKEN` または短命トークンを使用している。

この前提のもと、Podman DesktopのAccounts機能にGitHub Accountでログインする必要性を検討した。

## Decision

- Podman DesktopのAccounts機能において、GitHub Accountログインは採用しない。
- Podman Desktopは非ログイン状態で運用する。
- GitHub OAuth連携は明示的に行わない。
- 認証・権限管理はCLIおよびCI/CD側に集約する。

## Rationale

- コア機能（コンテナー起動・停止、Pod / Image管理、Podman Machine）はAccountsログイン有無に依存しない。
- OAuthトークンや永続認証情報をGUIに預けないことで攻撃面積を最小化できる。
- 現行運用において、ログインしないことによる実害が存在しない。
- 認証（CLI / CI）と観測・補助（GUI）の責務分離が明確になる。

## Consequences

### Positive

- OAuthトークン悪用リスクが低減される。
- GitHub組織・リポジトリへの波及リスクが抑制される。
- 認証経路の単純化により、障害切り分けが容易になる。
- 将来の環境再構築時にGUI側の状態依存がなくなる。

### Negative / Trade-offs

- Podman DesktopがAccountsログインを前提とする一部UX補助機能が利用できない。
- 将来的なチーム連携・クラウド連携機能は未使用となる。

## Reality Check（機能影響整理）

| 項目                         | 影響内容                         |
|------------------------------|----------------------------------|
| コンテナー起動・停止         | 影響なし                         |
| Pod / Image 管理             | 影響なし                         |
| ghcr.io からの pull          | 影響なし（CLI による `podman login` で対応） |
| CI / CD                      | 影響なし                         |
| 拡張機能の一部 UX            | 軽微（必須ではない）             |
| 将来のチーム連携機能         | 未使用（現時点では不要）         |


## Alternatives Considered

1. **GitHub Account ログインを常時有効化する案**
   現行運用においてAccountsログインが必要な機能を使用していない。
   常時ログインはOAuthトークンの永続保持を意味し、利益に対してリスクが不釣り合いなため採用しない。

2. **必要時のみログインする案**
  「必要時」の定義が曖昧になりやすく、その都度OAuth認可フローを踏むことになる。
   現行のCLI認証で要件を満たしているため、この複雑さを導入する合理的理由がなく採用しない。

## Review Policy

半年に一度、以下の観点で再評価する。

- Accountsログインを前提とする必須機能がPodman Desktopに追加されたか。
- チーム運用・可視化要件が変化し、GUI側の認証機能が必要になったか。
- 本ADRを更新すべき合理的理由（セキュリティ上の変化、運用方針の転換）が発生したか。

## Notes

本判断は、CLI中心・最小権限を原則とする現行構成において、
もっとも合理的かつ安全側の選択として採用したものである。
チーム規模や運用体制が変化した場合は、本ADRの前提条件から再検討する。

本ADRはPodman Desktop AccountsのGUI OAuthログインを対象とし、GitHub ActionsのGITHUB_TOKEN等のCI認証方針を否定しない。
