# .NET Uninstall Tool 管理スクリプト（DotNetUninstallTool.ps1）

English: [Readme.en.md](./Readme.en.md)

.NET Uninstall Tool（`dotnet-core-uninstall`）のインストール/アンインストールを、対話式メニューとYAML設定で安全・簡単に管理するためのスクリプトです。ドライラン（`-WhatIf`）対応で、実際に変更を加える前に「何が行われるか」を確認できます。ログは常に作成され、実行後に自動で開きます。

---

## 目次

- [.NET Uninstall Tool 管理スクリプト（DotNetUninstallTool.ps1）](#net-uninstall-tool-管理スクリプトdotnetuninstalltoolps1)
  - [目次](#目次)
  - [特長](#特長)
  - [前提条件](#前提条件)
  - [配置と構成](#配置と構成)
  - [クイックスタート](#クイックスタート)
  - [ドライランの挙動](#ドライランの挙動)
  - [ログ](#ログ)
  - [YAML設定](#yaml設定)
  - [操作の流れ（概要）](#操作の流れ概要)
  - [終了コード](#終了コード)
  - [トラブルシューティング](#トラブルシューティング)
  - [手動インストール（参考）](#手動インストール参考)
  - [ライセンス / リンク](#ライセンス--リンク)

---

## 特長

- YAMLによる一元設定（MSIファイル、タイムアウト、ログ、終了コード等）
- 管理者権限チェック（デバッグ用途の `-SkipAdminCheck` あり）
- MSIの存在確認とブロック解除（Unblock）
- `msiexec` によるインストール/アンインストール（タイムアウト付き）
- レジストリからの製品コード/インストール場所の検出
- インストール/アンインストール後の検証
- ログ生成と自動ローテーション、終了時のログ自動オープン
- 二重起動防止（Mutex）
- ドライラン（`-WhatIf`）対応：実行計画のみをログへ出力し、変更は行いません

---

## 前提条件

- PowerShell 7.x以上（推奨: 最新）
- モジュール: `powershell-yaml`
  - 未インストールの場合（管理者PowerShell推奨）:

```powershell
Install-Module powershell-yaml -Scope CurrentUser -Force
```

- リポジトリ直下に`Common/Write-CommonLog.ps1`が存在すること
- 本フォルダー配下にYAML設定`YAML/DotNetUninstallTool.yaml`が存在すること
- MSIファイル`dotNetSdkUninstallTool/dotnet-core-uninstall.msi`が存在すること

---

## 配置と構成

```text
dotNetSdkUninstallToolの入手/
├─ Readme.md                         ← 本ファイル
├─ Script/
│   └─ DotNetUninstallTool.ps1       ← 実行スクリプト
├─ YAML/
│   └─ DotNetUninstallTool.yaml      ← 設定ファイル（ScriptVersion: 1.1.0）
├─ dotNetSdkUninstallTool/
│   └─ dotnet-core-uninstall.msi     ← インストール用MSI
└─ LOG/                               ← 実行ログ（自動作成/ローテーション）
```

---

## クイックスタート

安全に計画のみ確認（ドライラン）:

```powershell
pwsh -NoProfile -File ".\dotNetSdkUninstallToolの入手\Script\DotNetUninstallTool.ps1" -WhatIf -Verbose
```

通常実行（変更を伴います。管理者PowerShellでの実行を推奨）:

```powershell
pwsh -NoProfile -File ".\dotNetSdkUninstallToolの入手\Script\DotNetUninstallTool.ps1" -Verbose
```

デバッグ用途で権限チェックをスキップ（本番利用非推奨）:

```powershell
pwsh -NoProfile -File ".\dotNetSdkUninstallToolの入手\Script\DotNetUninstallTool.ps1" -SkipAdminCheck -Verbose
```

> メニューが表示されたら、`1`（インストール）、`2`（アンインストール）、`Q`（終了）から選択してください。

---

## ドライランの挙動

- `ShouldProcess`で保護された操作（`Unblock-File`/`msiexec`/フォルダー削除）は実行されません。
- その代わり「何を実行するか」を `[WhatIf]` 行としてログ出力します。
- ログの作成・追記・終了時のログオープンは `-WhatIf` の影響を受けず、常に実行されます。

---

## ログ

- 出力先:`dotNetSdkUninstallToolの入手/LOG/`（なければ自動作成）
- 命名規則: `DotNetUninstallTool_yyyyMMdd-HHmmss-fff.log`
- ローテーション:`YAML/LogCleanup.RetentionDays`に従い古いログを削除
- 実行終了時に自動でログを開きます（`-WhatIf`でも開かれます）

---

## YAML設定

対象: `YAML/DotNetUninstallTool.yaml`

主要キー（例を含む）:

- `Project`
  - `Name`: ".NET Uninstall Tool Management"
  - `ScriptVersion`: "1.1.0"
- `MSI`
  - `FileName`: "dotnet-core-uninstall.msi"
  - `ProductName`: "*Uninstall Tool*"（レジストリDisplayName検索用）
- `Installation`
  - `DefaultPath`: `C:\\Program Files (x86)\\dotnet-core-uninstall`
  - `CommandName`: `dotnet-core-uninstall`
- `LOG`
  - `FILENAME`: `DotNetUninstallTool`
  - `EXTENSION`: `.log`
- `LogCleanup`
  - `Enabled`: `true`
  - `RetentionDays`: `30`
- `Timeout`
  - `InstallSeconds`: `300`
  - `UninstallSeconds`: `300`
  - `SleepAfterOperation`: `5`
- `PopupIcon`
  - `Error`: `0x10`
  - `Warning`: `0x30`
  - `Information`: `0x40`
- `ExitCode`
  - `Success`: `0`
  - `GeneralError`: `1`
  - `UserCancelled`: `2`
  - `InsufficientPrivileges`: `3`
  - `FileNotFound`: `4`
  - `InstallFailed`: `5`
  - `UninstallFailed`: `6`

---

## 操作の流れ（概要）

1. YAML読み込み → ログ初期化 → 権限確認 → Mutex取得 → 古いログのクリーンアップ
2. メニュー表示（`1` インストール / `2` アンインストール / `Q` 終了）
3. インストール: MSI存在確認 → Unblock → `msiexec /i` → 検証
4. アンインストール: レジストリ検索 → `msiexec /x` → 残存フォルダー削除 → 検証
5. 実行終了時にログを自動オープン

---

## 終了コード

- `0`: 正常終了（Success）
- `1`: 一般エラー（GeneralError）
- `2`: ユーザーキャンセル（UserCancelled）
- `3`: 権限不足（InsufficientPrivileges）
- `4`: ファイル未検出（FileNotFound）
- `5`: インストール失敗（InstallFailed）
- `6`: アンインストール失敗（UninstallFailed）

---

## トラブルシューティング

- `powershell-yaml` が見つからない
  - `Install-Module powershell-yaml -Scope CurrentUser -Force`
- 管理者権限が必要と表示される
  - 管理者PowerShellで実行するか、デバッグ用途のみ `-SkipAdminCheck` を使用
- MSIが見つからない
  - `dotNetSdkUninstallTool/dotnet-core-uninstall.msi` の有無とパスを確認
- インストール後にコマンドが認識されない
  - `dotnet-core-uninstall` コマンドは新しいセッションで認識される場合があります。PowerShellを再起動
- ログが開かれない
  - 例外などで開けない場合は`dotNetSdkUninstallToolの入手/LOG/`を直接参照

---

## 手動インストール（参考）

公式の配布ページからMSIを取得して手動インストールも可能です。

- Releases: <https://github.com/dotnet/cli-lab/releases>
- 例:`dotnet-core-uninstall-1.x.x.msi`をダウンロード→管理者権限で実行
- 確認:

```powershell
dotnet-core-uninstall list
```

---

## ライセンス / リンク

- リポジトリ: <https://github.com/UMA68/PowerShell>
- ライセンス: 本リポジトリの `LICENSE` に従います


