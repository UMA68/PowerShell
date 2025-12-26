# Node.js通信ブロック対応 - npm安全実行ツール

## 概要

Node.jsの送信通信をファイアウォールでブロックしている環境で、npmの主要コマンド（install/uninstall/update/ci）を一時的に安全に実行するためのPowerShellスクリプト群です。通信ブロックの解除→npm実行→再ブロックを自動化し、不要な外部通信を最小限に抑えます。

## 主な機能

### 🛡️ セキュリティ機能

- **一時的な通信許可**: npmコマンド実行時のみ送信通信を許可
- **自動再ブロック**: コマンド完了後、即座に送信通信を再ブロック
- **最小権限**: 必要なファイアウォールルールのみを操作

### ⚙️ 自動化機能

- npmパッケージのインストール/アンインストールを安全に実行
- ファイアウォールルール操作の自動化
- 処理状況の視覚的フィードバック

## 重要ポイント

- **DryRun**: 管理者権限不要・変更ゼロ。WhatIf相当で予定操作のみをログに出力し、ファイアウォール再ブロックも含めて一切の変更を行いません。
- **再ブロック保証**: 実行時（DryRun以外）はtry/catch/finallyにより、エラー時でも確実に送信通信を再ブロックします。
- **ログの既定**: 既定のログは `Node.js通信ブロック対応\npm_safe.log`（`Script` の1つ上）。`-LogPath` で変更可能。
- **ciの挙動**: `-Global`/`--save-dev`/`-Packages` は無視され、`package-lock.json` に厳密にしたがってクリーンインストールします。
- **ciの注意**: `package-lock.json` と `package.json` の不整合がある場合、`npm ci` は失敗します。対策として、まず `npm install` でlockを更新するか、依存バージョンの整合を取ってから `npm ci` を実行してください。
- **uninstallの必須引数**: `-Command uninstall` は `-Packages` の指定が必須です。未指定の場合はエラー終了します。
- **installの省略時挙動**: `-Command install` で `-Packages` を省略すると `npm install` を実行し、`package.json` の依存関係をインストールします（この場合は `-Global`/`--save-dev` は無視）。
- **強制インストール (`--force`) の注意**: 依存関係の整合性を無視して破壊的変更を招く可能性があります。推奨しません。必要な場合はまず `-DryRun` でコマンド内容を確認し、限定的に使用してください。
- **SkipAdminCheck**: `-DryRun` との併用時のみ有効。管理者権限チェックをスキップし、検証・テスト用途でログ出力のみを確認できます。単独使用時はエラー終了します。

## 前提条件

### 必須要件

- **Windows 10/11**: Windowsファイアウォール機能
- **PowerShell 5.1** 以降（またはPowerShell 7.x）
- **管理者権限**: ファイアウォールルール変更のため必須
- **Node.js**: インストール済みであること
- **ファイアウォールルール**: `Block Node.js Outbound` という名前のルールが作成済み

### ファイアウォールルールの事前設定

これらのスクリプトを使用する前に、以下のルールを作成しておく必要があります：

```powershell
# Node.js送信通信ブロックルールの作成（管理者権限で実行）
New-NetFirewallRule -DisplayName "Block Node.js Outbound" `
    -Direction Outbound `
    -Program "C:\Program Files\nodejs\node.exe" `
    -Action Block `
    -Enabled True

# 別のNode.jsインストール先の場合はパスを調整してください
# 例: "C:\Program Files (x86)\nodejs\node.exe"
```

## ディレクトリ構造

```Terminal
Node.js通信ブロック対応/
├── README.md                      # このファイル
└── Script/
    ├── npm_install_safe.ps1       # npm install/update/ci 安全実行スクリプト
    └── npm_uninstall_safe.ps1     # npm uninstall/update/ci 安全実行スクリプト
```

## 使い方

### 基本的な使用方法（編集不要・パラメーター指定）

管理者権限のPowerShellで、パラメーターを指定して実行します。スクリプト本体の編集は不要です。

```powershell
# インストール（ローカル）
.\Script\npm_install_safe.ps1 -Command install -Packages "express"

# インストール（開発依存）
.\Script\npm_install_safe.ps1 -Command install -Packages @("jest","eslint") -SaveDev

# インストール（グローバル）
.\Script\npm_install_safe.ps1 -Command install -Packages "typescript" -Global

# アンインストール（ローカル）
.\Script\npm_uninstall_safe.ps1 -Command uninstall -Packages "express"

# アンインストール（グローバル）
.\Script\npm_uninstall_safe.ps1 -Command uninstall -Packages "typescript" -Global

# 依存関係の更新（package.jsonに従う）
.\Script\npm_install_safe.ps1 -Command update

# lockに従ってクリーンインストール（ci）
.\Script\npm_install_safe.ps1 -Command ci
 
 # peerDependenciesの衝突を回避（例: レガシー許容）
 .\Script\npm_install_safe.ps1 -Command install -Packages "some-package" -ExtraArgs @("--legacy-peer-deps")

# 特定パッケージのみ更新（peer依存の警告回避）
.\Script\npm_install_safe.ps1 -Command update -Packages "some-package" -ExtraArgs @("--legacy-peer-deps")
```

補足:

- `install` で `-Packages` 未指定の場合は `npm install` を実行し、`package.json` の依存関係をインストールします（このケースでは `-Global`/`-SaveDev` は無視されます）。
- `uninstall` は必ず `-Packages` の指定が必要です（パッケージを明示してください）。
 - 各スクリプトが受け付ける `-Command` の値:
     - `npm_install_safe.ps1`: `install` | `update` | `ci`
     - `npm_uninstall_safe.ps1`: `uninstall` | `update` | `ci`

- 追加引数（`-ExtraArgs`）: `--legacy-peer-deps` などの追加引数は `-ExtraArgs` で指定できます（`ci`では無視されるかエラーになる可能性あり）。

ログ出力の既定場所は `Node.js通信ブロック対応\npm_safe.log`（`Script` フォルダーの1つ上）です。`-LogPath` で変更できます。

### 詳細な実行手順

#### Step 1: パラメーターで指定（編集不要）

上記の「基本的な使用方法」のとおり、`-Command`・`-Packages`・`-Global`・`-SaveDev` を必要に応じて指定します。

#### Step 2: 管理者権限で実行

```PowerShell
# PowerShellを管理者として起動
# スクリプトのあるディレクトリに移動
Set-Location "$HOME\GitHub\PowerShell\Node.js通信ブロック対応"

# 実行ポリシーの確認（必要に応じて）
Get-ExecutionPolicy

# 実行ポリシーの変更（必要な場合のみ）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# スクリプト実行
.\Script\npm_install_safe.ps1
```

#### Step 3: 実行結果の確認

スクリプトは以下の順序で処理を実行します：

1. ✅ 送信通信ブロックを一時解除
2. ✅ npmコマンドを実行
3. ✅ 送信通信を再度ブロック
4. ✅ 完了メッセージを表示

```Terminal
Node.js の送信通信を一時的に許可します...
npm install を実行中...
+ express@4.18.2
added 57 packages in 3s
Node.js の送信通信を再度ブロックします...
完了しました。
```

### ドライラン（DryRun）モード

実際にファイアウォールやnpmに変更を加えず、予定操作のみを確認できます。`-DryRun` は内部的にWhatIfと同様に扱われ、ファイアウォールの再ブロックも含めて一切の変更を行いません。DryRunは管理者権限不要です。

```powershell
# インストールのドライラン
.\Script\npm_install_safe.ps1 -Packages "express" -DryRun

# アンインストールのドライラン
.\Script\npm_uninstall_safe.ps1 -Packages "express" -DryRun

# 例: 複数パッケージやフラグの併用
.\Script\npm_install_safe.ps1 -Packages @("jest","eslint") -SaveDev -DryRun
.\Script\npm_uninstall_safe.ps1 -Packages @("lodash","axios") -DryRun
```

## スクリプト詳細

### npm_install_safe.ps1

Node.jsパッケージを安全にインストール・更新・クリーンインストールするスクリプトです。

**主な処理**:

1. `Block Node.js Outbound` ルールを無効化（DryRun時はスキップ）
2. `npm {install|update|ci}` を実行（指定に応じて）
3. `Block Node.js Outbound` ルールを再有効化（DryRun時はスキップ）

**使用場面**:

- 新しいnpmパッケージの追加
- package.jsonの依存関係インストール
- グローバルパッケージのインストール

**主なパラメーター**:

- `-Command`: `install` | `update` | `ci`
- `-Packages`: 対象パッケージ（`update`/`ci`では省略可。`ci`はパッケージ指定を無視）
- `-Global`: グローバル操作（`ci`では無効）
- `-SaveDev`: 開発依存としてインストール（`install`のみ有効）
 - `-ExtraArgs`: 追加引数（例: `--legacy-peer-deps`）。`ci`では無視されるかエラーになる可能性あり。

### npm_uninstall_safe.ps1

Node.jsパッケージを安全にアンインストール・更新（uninstall/update）するスクリプトです。

**主な処理**:

1. `Block Node.js Outbound` ルールを無効化（DryRun時はスキップ）
2. `npm {uninstall|update}` を実行（指定に応じて）
3. `Block Node.js Outbound` ルールを再有効化（DryRun時はスキップ）

**使用場面**:

- 不要なパッケージの削除
- パッケージの再インストール準備
- グローバルパッケージの削除

**主なパラメーター**:

- `-Command`: `uninstall` | `update` | `ci`（`ci`はインストール側での使用を推奨）
- `-Packages`: 対象パッケージ（`uninstall`は必須、`update`は省略可）
- `-Global`: グローバル操作
 - `-ExtraArgs`: 追加引数（例: `--legacy-peer-deps`）。`ci`では無視されるかエラーになる可能性あり。

## トラブルシューティング

### よくある問題と解決方法

#### 1. 「管理者権限が必要です」エラー

```Terminal
エラー: アクセスが拒否されました
```

**解決方法**:

- PowerShellを**管理者として実行**してください
- スタートメニュー → PowerShellを右クリック → 管理者として実行

#### 2. ファイアウォールルールが見つからない

```Terminal
エラー: No MSFT_NetFirewallRule objects found with property 'DisplayName' equal to 'Block Node.js Outbound'
```

**解決方法**:
ファイアウォールルールを作成してください：

```PowerShell
# 管理者権限で実行
New-NetFirewallRule -DisplayName "Block Node.js Outbound" `
    -Direction Outbound `
    -Program "C:\Program Files\nodejs\node.exe" `
    -Action Block `
    -Enabled True

# Node.jsのパスを確認
Get-Command node | Select-Object Source
```

#### 3. 実行ポリシーエラー

```Terminal
エラー: このシステムではスクリプトの実行が無効になっているため...
```

**解決方法**:

```PowerShell
# 現在のポリシーを確認
Get-ExecutionPolicy

# ポリシーを変更（管理者権限）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# または一時的に実行を許可
Set-ExecutionPolicy Bypass -Scope Process
```

#### 4. npmコマンドが見つからない

```Terminal
エラー: 'npm' は、内部コマンドまたは外部コマンド...として認識されていません
```

**解決方法**:

- Node.jsがインストールされているか確認：`node -v`
- 環境変数PATHにNode.jsが含まれているか確認
- Node.jsを再インストール

#### 5. 通信が完全にブロックされたまま

スクリプトがエラーで中断した場合、通信が再ブロックされない可能性があります。

**解決方法**:

```PowerShell
# 手動で通信を許可（管理者権限）
Set-NetFirewallRule -DisplayName "Block Node.js Outbound" -Enabled False

# または手動で再ブロック
Set-NetFirewallRule -DisplayName "Block Node.js Outbound" -Enabled True

# 現在の状態を確認
Get-NetFirewallRule -DisplayName "Block Node.js Outbound" | Select-Object DisplayName, Enabled, Direction, Action
```

#### 6. ファイアウォールルール名が異なる

環境によっては異なるルール名を使用している場合があります。

**解決方法**:

```PowerShell
# すべてのNode.js関連ルールを確認
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*Node*"} | Select-Object DisplayName, Enabled

# スクリプト内のルール名を変更
# 編集前: -DisplayName "Block Node.js Outbound"
# 編集後: -DisplayName "実際のルール名"
```

## セキュリティに関する注意事項

### ⚠️ 重要な注意点

1. **最小権限の原則**: スクリプトは必要最小限の時間だけ通信を許可します
2. **管理者権限**: ファイアウォール変更には管理者権限が必須です
3. **ルール名の一意性**: `Block Node.js Outbound` が既存ルールと重複しないことを確認
4. **信頼できるパッケージのみ**: npmパッケージは公式レジストリから取得してください
5. **SkipAdminCheckは検証専用**: `-DryRun` と組み合わせた検証・テスト用途に限定してください。単独使用はエラーになります。

### 🔒 セキュリティベストプラクティス

- スクリプト実行前に内容を確認する
- インストールするパッケージの信頼性を確認
- 不要な通信は最小限に抑える
- ファイアウォールログを定期的に確認

```PowerShell
# ファイアウォールログの確認
Get-NetFirewallProfile | Select-Object Name, LogFileName

# 最近のブロックを確認
Get-Content "C:\Windows\System32\LogFiles\Firewall\pfirewall.log" -Tail 50
```

#### 7. `npm ci` が失敗する（lock不整合）

`npm ci` は `package-lock.json` と `package.json` の差分に厳格です。lockが存在しない、または不整合があると失敗します。

**確認と対処**:

```powershell
# lock の存在確認
Test-Path .\package-lock.json

# lock を再生成（依存をインストール）
.\Script\npm_install_safe.ps1 -Command install

# その後、クリーンインストール
.\Script\npm_install_safe.ps1 -Command ci
```

必要に応じて、`package.json` の依存バージョンを見直し、lockと整合させてから再度 `ci` を実行してください。

## 高度な使用例

### 例1: package.jsonからすべてインストール

```PowerShell
Push-Location "$HOME\Projects\MyApp"
& "$HOME\GitHub\PowerShell\Node.js通信ブロック対応\Script\npm_install_safe.ps1" -Command install
Pop-Location
```

### 例2: 複数パッケージを一括操作（開発依存含む）

```PowerShell
& "$HOME\GitHub\PowerShell\Node.js通信ブロック対応\Script\npm_install_safe.ps1" -Command install -Packages @("express","mongoose","dotenv","cors","helmet")
& "$HOME\GitHub\PowerShell\Node.js通信ブロック対応\Script\npm_install_safe.ps1" -Command install -Packages @("@types/node","@types/express") -SaveDev
```

### 例3: グローバルツールのインストール

```PowerShell
& "$HOME\GitHub\PowerShell\Node.js通信ブロック対応\Script\npm_install_safe.ps1" -Command install -Packages @("typescript","ts-node","nodemon") -Global
```

### 例4: パッケージ更新

```PowerShell
# すべて更新
& "$HOME\GitHub\PowerShell\Node.js通信ブロック対応\Script\npm_install_safe.ps1" -Command update

# 特定パッケージのみ更新
& "$HOME\GitHub\PowerShell\Node.js通信ブロック対応\Script\npm_install_safe.ps1" -Command update -Packages @("express","mongoose")
```

### 例5: バッチ処理との統合（安全スクリプトを呼び出し）

```PowerShell
# batch_npm_install.ps1（新規作成例）
param(
    [Parameter(Mandatory=$true)]
    [string[]]$Packages
)

foreach ($package in $Packages) {
    & "$PSScriptRoot\Node.js通信ブロック対応\Script\npm_install_safe.ps1" -Command install -Packages $package
}

# 使用例
# .\batch_npm_install.ps1 -Packages @("express", "mongoose", "dotenv")
```

## ファイアウォールルール管理

### ルールの確認

```PowerShell
# Node.js関連ルールの一覧表示
Get-NetFirewallRule -DisplayName "Block Node.js Outbound" | 
    Select-Object DisplayName, Enabled, Direction, Action, Profile

# 詳細情報
Get-NetFirewallRule -DisplayName "Block Node.js Outbound" | 
    Get-NetFirewallApplicationFilter
```

### ルールの作成（詳細版）

```PowerShell
# 基本的な送信ブロックルール
New-NetFirewallRule `
    -DisplayName "Block Node.js Outbound" `
    -Description "Node.jsからの送信通信をブロック（npm実行時のみ一時解除）" `
    -Direction Outbound `
    -Program "C:\Program Files\nodejs\node.exe" `
    -Action Block `
    -Enabled True `
    -Profile Any

# 複数のNode.jsバージョンに対応
$nodePaths = @(
    "C:\Program Files\nodejs\node.exe",
    "C:\Program Files (x86)\nodejs\node.exe",
    "$env:APPDATA\nvm\nodejs\node.exe"
)

foreach ($path in $nodePaths) {
    if (Test-Path $path) {
        New-NetFirewallRule `
            -DisplayName "Block Node.js Outbound ($path)" `
            -Direction Outbound `
            -Program $path `
            -Action Block `
            -Enabled True
    }
}
```

### ルールの削除

```PowerShell
# ルールを削除（管理者権限）
Remove-NetFirewallRule -DisplayName "Block Node.js Outbound"

# 確認付きで削除
Get-NetFirewallRule -DisplayName "Block Node.js Outbound" | Remove-NetFirewallRule -Confirm
```

## よくある質問（FAQ）

### Q1: なぜNode.js通信をブロックする必要があるのですか？

**A**: セキュリティ強化のためです。開発環境で不要な外部通信を制限し、予期しないデータ送信やマルウェアの通信を防ぎます。

### Q2: 通常のnpmコマンドと何が違いますか？

**A**: ファイアウォールルールを自動で操作する点が異なります。手動でルールを切り替える手間を省きます。

### Q3: すべてのnpmコマンドで使用できますか？

**A**: 主要な `install/uninstall/update/ci` をパラメーターでサポートします。その他のコマンドは `-ExtraArgs` で引数を渡すか、必要に応じてスクリプト拡張で対応してください。

### Q4: グローバルインストールにも対応していますか？

**A**: はい。`npm install -g <package>` のようにグローバルフラグを付けて実行できます。

### Q5: エラーが発生した場合、通信は再ブロックされますか？

**A**: 本スクリプトはエラーハンドリング（try/catch/finally）を備え、エラー時でも確実に通信を再ブロックします（DryRun時は変更なし）。

### Q6: `-SkipAdminCheck` はどういうときに使いますか？

**A**: `-DryRun` と組み合わせて検証・テスト時に使用します。管理者権限なしでログ出力やコマンド構文を確認できます。単独使用はエラーになるため、実際の実行には管理者権限が必要です。

### Q7: 他の開発ツール（yarn, pnpm等）でも使えますか？

**A**: 本スクリプトはnpmに最適化されています。類似の方針（通信一時解除→実行→再ブロック）で、別スクリプトを用意するかコマンド呼び出し部分を調整すれば対応可能です。

## 改善提案

旧版のスクリプトからの改善点です：

### 1. エラーハンドリング追加（対応済み）

try/catch/finallyにより、異常時も再ブロックを保証。

### 2. パラメーター化（対応済み）

`-Command`/`-Packages`/`-Global`/`-SaveDev`/`-RuleName`/`-LogPath`/`-DryRun` をサポート。

### 3. ログ記録（対応済み）

詳細ログを出力（パスは `-LogPath` で変更可能）。

### 4. 管理者権限チェック（対応済み）

DryRun時は管理者不要。実行時は管理者権限を自動チェック。

## 参考リンク

- [PowerShell ファイアウォールコマンドレット](https://docs.microsoft.com/powershell/module/netsecurity/)
- [npm ドキュメント](https://docs.npmjs.com/)
- [Windows ファイアウォールの管理](https://docs.microsoft.com/windows/security/threat-protection/windows-firewall/)

## ライセンス

このプロジェクトに含まれるスクリプトは、本リポジトリ直下の `LICENSE` に従います。

## バージョン履歴

### v1.1.0

- `-Command` の追加（install/uninstall/update/ci）
- DryRunの強化（WhatIf相当・全変更スキップ）
- ログ・管理者チェック・ルール存在チェックの導入

### v1.0.0 (初期リリース)

- Node.js送信通信の一時的な許可/ブロック機能
- npm install安全実行スクリプト
- npm uninstall安全実行スクリプト
