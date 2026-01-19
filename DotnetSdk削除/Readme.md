# DotNetSdk_Uninstall.ps1

.NET SDKを安全にアンインストールするためのPowerShellスクリプト（v1.1.0）

## はじめに

削除ツールを作っておいて何ですが、 .NET SDKの削除は実施しない方が賢明です。古いSDKは通常、システムに悪影響を与えません。むしろ、将来のプロジェクトで必要になる可能性があります。 ただし、特定の状況下でSDKを削除する必要がある場合に、このスクリプトが役立ちます。

なので、.NET SDK削除によるシステム不安定化のリスクを理解した上で、慎重に使用してください。

## 概要

このスクリプトは、インストールされている .NET SDKを **安全** に削除します。以下の特徴があります：

- ✅ **例外型に基づいたログレベル分類** - エラーの重要度を自動判定
- ✅ **CanExecuteProcess フラグによるフロー制御** - 統一的なエラーハンドリング
- ✅ **Helper 関数による再利用可能なコード** - メンテナンス性向上
- ✅ **end ブロックでの確実なリソースクリーンアップ** - COMオブジェクト確実解放
- ✅ **YAML 設定ファイルによる一元管理** - タイムアウト、終了コード等を簡単変更

## 前提条件

- **PowerShell** 7.x以上
- **powershell-yaml** モジュール（YAMLファイル読み込み用）
- **dotnet-core-uninstall** ツール（SDK削除用）
- **.NET SDK** がインストール済み
- **管理者権限**（`-SkipAdminCheck` でスキップ可能）
- **Write-CommonLog.ps1** が `Common` フォルダーに存在
- **DotNetUninst.yaml** が `YAML` フォルダーに存在

## 使用方法

### 管理者権限での起動（推奨）

```powershell
# 管理者として新しい PowerShell を起動し、スクリプトを実行
Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit -Command `"cd '$(Split-Path $PSCommandPath)'; .\DotNetSdk_Uninstall.ps1`""
```

> 権限不足の場合は必ず管理者権限で実行してください。`-SkipAdminCheck` はデバッグ専用です。

### 基本的な実行

```powershell
# 対話的モード（インストール済みSDKの一覧表示後、削除対象を入力）
.\DotNetSdk_Uninstall.ps1
```

### パラメーター指定

```powershell
# 特定バージョンを削除
.\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301"

# 複数バージョンを一括削除
.\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301,8.0.100"

# ドライランモード（削除対象の確認のみ）
.\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301" -WhatIf

# 詳細ログを出力
.\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301" -Verbose

# 管理者権限チェックをスキップ（デバッグ用）
.\DotNetSdk_Uninstall.ps1 -SkipAdminCheck
```

## 主な機能

### 1. YAML 設定ファイルによる一元管理

`YAML/DotNetUninst.yaml` で以下を設定可能：

```yaml
Project:
  Name: DotNetSdk_Uninstall
  Version: "1.1.0"

Uninstall:
  UninstallSeconds: 300  # タイムアウト秒数
  VersionPattern: "^\\d+\\.\\d+\\.\\d+$"  # バージョン形式

Popup:
  Error: 16
  Warning: 48
  Information: 64

RetentionDays: 30  # ログ保持期間（日）

ExitCode:
  Success: 0
  GeneralError: 1
  UserCanceled: 2
  InsufficientPermission: 3
  VersionValidationError: 4
  UninstallFailed: 5
```

### 2. 安全性強化（v1.1.0）

#### CanExecuteProcess フラグによるフロー制御

```powershell
$script:CanExecuteProcess = $true  # 初期化

# エラー発生時
$script:CanExecuteProcess = $false
$script:ExitCode = 1
return
```

エラーが発生した場合でも、endブロックで確実にリソースがクリーンアップされます。

#### 例外型に基づいたログレベル分類

`Get-ExceptionLogLevel` 関数により、例外の型に応じて自動的にログレベルを決定：

- **Terminating 例外** → ERROR
- **Argument/Validation 例外** → WARN
- **OperationCanceled 例外** → WARN
- **その他** → DEBUG

#### Helper 関数

- **`Open-LogIfNeeded`** - ログファイルをプロセスで開く（存在チェック付き）
- **`Stop-ProcessTree`** - プロセスとその子プロセスを再帰的に削除

### 3. 実行フロー

1. **初期化** - YAML設定読み込み、ログファイル準備
2. **権限チェック** - 管理者権限確認
3. **コマンド確認** - dotnet、dotnet-core-uninstallの存在確認
4. **ログクリーンアップ** - 古いログ削除（YAML設定の保持期間に基づく）
5. **SDK 一覧表示** - インストール済みSDKを表示
6. **バージョン入力/検証** - 削除対象バージョンの入力または検証
7. **依存関係チェック** - グローバルツール依存関係確認
8. **バックアップ作成** - 現状のJSON形式バックアップ作成
9. **最終確認** - ユーザー確認ダイアログ
10. **削除実行** - dotnet-core-uninstallでアンインストール（タイムアウト付き）
11. **検証** - SDKリストから削除されているか確認
12. **クリーンアップ** - endブロックで確実にリソース解放

## 終了コード

| コード | 意味 | 原因 |
|--------|------|------|
| 0 | 正常終了 | SDK が正常に削除されました |
| 1 | 一般エラー | 必要なコマンドが見つからない等 |
| 2 | ユーザーキャンセル | ユーザーが処理を中止 |
| 3 | 権限不足 | 管理者権限が必要です |
| 4 | バージョン検証エラー | 指定バージョンが未インストール |
| 5 | アンインストール失敗 | dotnet-core-uninstall 実行エラー |

## ログ出力

ログファイルは `LOG/` ディレクトリに自動生成されます：

```Shell
LOG/
├── DotNetSdk_Uninstall_20241215-150000.log
├── DotNetSdk_Uninstall_20241214-145000.log
└── ...（古いログは YAML 設定の RetentionDays で自動削除）
```

### ログレベル

- **INFO** - 通常の処理ステップ
- **WARN** - 警告情報（エラーではないが注意が必要）
- **ERROR** - エラーが発生
- **DEBUG** - デバッグ情報（詳細な処理内容）

## トラブルシューティング

### PowerShell のバージョンが古い場合

```powershell
# PowerShell 7.x のインストール確認
$PSVersionTable.PSVersion
```

### powershell-yaml モジュールがない場合

```powershell
# モジュールをインストール
Install-Module -Name powershell-yaml -Repository PSGallery
```

### 管理者権限がない場合

```powershell
# 管理者権限の PowerShell を起動して実行
Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit -Command `"cd '$(Split-Path $PSCommandPath)'; .\DotNetSdk_Uninstall.ps1`""
```

### YAML ファイルが見つからない場合

```text
YAML/DotNetUninst.yaml が存在することを確認してください
```

## ファイル構成

```Shell
DotnetSdk削除/
├── Readme.md                               # このファイル
├── Script/
│   └── DotNetSdk_Uninstall.ps1            # メインスクリプト（v1.1.0）
├── YAML/
│   └── DotNetUninst.yaml                  # 設定ファイル
└── LOG/
    └── （実行時に生成）
```

## 改善履歴

### v1.1.0（2024年）

- exit文を廃止、return文に統一（スクリプト呼び出し対応）
- CanExecuteProcessフラグ導入（統一的なフロー制御）
- Get-ExceptionLogLevel関数実装（例外型の自動分類、9パターン対応）
- Helper関数追加（Open-LogIfNeeded, Stop-ProcessTree）
- Stop-ProcessTreeにShouldProcessサポートを追加（-WhatIf/-Confirm対応）
- 全catchでエラーログを残すよう改善（空catch排除）
- Write-Hostを排除し、パイプライン出力に変更
- endブロック強化（COMオブジェクト確実解放）
- 全catchブロック（7個）に例外分類ロジック統合

## 参考資料

- [dotnet-core-uninstall ツール](https://github.com/dotnet/cli-lab/releases)
- [PowerShell 公式ドキュメント](https://learn.microsoft.com/ja-jp/powershell/)
- [powershell-yaml モジュール](https://github.com/cloudbase/powershell-yaml)

## ライセンス

このスクリプトはUMAにより開発・管理されています。

## 注意事項

⚠️ **このスクリプトは .NET SDK を削除します。実行前に必ず:**

1. ドライランモード（`-WhatIf`）で削除対象を確認してください
2. 重要なSDKがインストールされていないことを確認してください
3. バックアップ作成オプションを有効にしてください（デフォルト有効）
4. 本番環境での実行は十分にテストしてから行ってください

⚠️ **タイムアウト設定（YAML `UninstallSeconds`）について:**

- デフォルトは300秒（5分）です
- ネットワークドライブやセキュリティソフトの影響がある場合は増加してください
- タイムアウト時はプロセスが強制削除されます
