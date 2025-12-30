# PowerShell ユーティリティ集

![PowerShell](https://img.shields.io/badge/PowerShell-7.3+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)

実務で役立つPowerShellスクリプト・ユーティリティのコレクションです。開発、セキュリティ、システム管理、データベース操作など、さまざまな用途に対応したツールを提供します。

## 📚 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [共通機能 (Common)](#共通機能-common)
- [ツール一覧](#ツール一覧)
  - [セキュリティツール](#セキュリティツール)
  - [開発ツール](#開発ツール)
  - [システム管理ツール](#システム管理ツール)
  - [データベースツール](#データベースツール)
  - [その他のツール](#その他のツール)
- [セットアップ](#セットアップ)
- [ライセンス](#ライセンス)
- [重要な注意事項](#重要な注意事項)

## 概要

このリポジトリは、日常的な開発・運用業務を効率化するためのPowerShellスクリプト集です。各ツールは独立して動作し、YAML設定ファイルによる柔軟なカスタマイズ、詳細なログ出力、エラーハンドリングなど、プロダクション環境でも使用できる品質を目指しています。

## 前提条件

### 基本要件

- **Windows 10/11**（一部ツールはWindows専用）
- **PowerShell 7.3.9 以上**（推奨）

  ```powershell
  winget install Microsoft.PowerShell
  ```

- **実行ポリシー**: RemoteSigned以上

  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### 共通で必要なモジュール

以下のモジュールは多くのツールで使用されます：

```powershell

# PowerShell-Yaml（YAML設定ファイル読み込み）
Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Scope CurrentUser

# SqlServer（データベースツール用）

Install-Module -Name SqlServer -MinimumVersion 22.1.1 -Scope CurrentUser
```

## 共通機能 (Common)

[Common](Common/) フォルダーには、各ツールで共通的に使用されるユーティリティ関数が含まれています。

| スクリプト | 説明 |
|-----------|------|
| [CheckCommand.ps1](Common/CheckCommand.ps1) | コマンドの存在確認（\`Test-Command\`） |
| [FindModule.ps1](Common/FindModule.ps1) | PowerShellモジュールの存在・バージョン確認（\`Test-ModuleInstalled\`） |
| [Get-EncryptionKey.ps1](Common/Get-EncryptionKey.ps1) | 暗号化鍵ファイルの読み込み |
| [Get-ScriptPaths.ps1](Common/Get-ScriptPaths.ps1) | スクリプトのパス情報取得 |
| [Import-YamlConfig.ps1](Common/Import-YamlConfig.ps1) | YAML設定ファイルの読み込み |
| [NoDoubleActivation.ps1](Common/NoDoubleActivation.ps1) | 二重起動防止機能（Mutex使用） |
| [Write-CommonLog.ps1](Common/Write-CommonLog.ps1) | 統一されたログ出力機能 |

詳細は [Common/Readme.md](Common/Readme.md) をご覧ください。

## ツール一覧

### セキュリティツール

#### 🔐 暗号化鍵の作成

**パス**: [暗号化鍵の作成/](暗号化鍵の作成/)

AES暗号化に使用する共通鍵ファイルを生成します。

- **機能**: 192/256/128ビットの暗号化鍵生成
- **出力**: \`Common/Encryption.Key\`
- **用途**: パスワードや機密情報の安全な管理

```powershell
./暗号化鍵の作成/Script/MakeEncrypted.ps1 -KeySize 256
```

📖 [詳細なドキュメント](暗号化鍵の作成/Readme.md)

#### 🔒 暗号化文字列の作成

**パス**: [暗号化文字列の作成/](暗号化文字列の作成/)

パスワードなどの機密情報を暗号化してファイルに保存します。

- **機能**: AES暗号化による文字列の暗号化
- **入力**: 平文文字列
- **出力**: 暗号化された文字列ファイル

```powershell
./暗号化文字列の作成/Script/MakeEncryptedString.ps1
```

📖 [詳細なドキュメント](暗号化文字列の作成/Readme.md)

#### 🔓 暗号化文字列の復元

**パス**: [暗号化文字列の復元/](暗号化文字列の復元/)

暗号化された文字列を復号化します。

- **機能**: GUIまたはCLIでの復号化
- **入力**: 暗号化ファイル
- **出力**: 復号化された平文

```powershell
./暗号化文字列の復元/Script/StringDecryption.ps1
```

📖 [詳細なドキュメント](暗号化文字列の復元/Readme.md)

### 開発ツール

#### 🔍 DLL逆コンパイル (DecompileDLL)

**パス**: [DecompileDLL/](DecompileDLL/)

.NET DLLファイルを逆コンパイルし、新旧バージョンの差分を視覚的に比較します。

- **機能**:
  - ILSpyCmdによる自動逆コンパイル
  - WinMerge/VS Codeでの差分比較
  - 並列処理による高速化
  - 進捗表示とETA計算
- **対応環境**: Windows 10/11
- **依存**: ILSpyCmd, WinMergeまたはVS Code

```powershell

# 基本的な使用
./DecompileDLL/Script/DecompileDll.ps1

# 並列処理で高速化
./DecompileDLL/Script/DecompileDll.ps1 -Parallel
```

📖 [詳細なドキュメント](DecompileDLL/Readme.md)

#### 📦 ILSpyCmd インストーラー

**パス**: [ILSpyCmdの入手/](ILSpyCmdの入手/)

.NET逆コンパイルツールILSpyCmdを自動的にインストールします。

- **機能**:
  - ILSpyCmdの自動インストール
  - .NET SDKの前提条件チェックと自動インストール
  - ネットワーク接続の検証
  - ロールバック機能
  - 非対話モード対応（\`-NoKeyWait\`）
- **バージョン**: v1.4.0

```powershell
# 対話モード
./ILSpyCmdの入手/Script/getILSpyCmd.ps1

# 非対話モード（自動化・スケジューラー用）
./ILSpyCmdの入手/Script/getILSpyCmd.ps1 -NoKeyWait
```

📖 [詳細なドキュメント](ILSpyCmdの入手/Readme.md)

#### 🛠️ .NET SDK Uninstall Tool 管理

**パス**: [dotNetSdkUninstallToolの入手/](dotNetSdkUninstallToolの入手/)

Microsoftの .NET Uninstall Toolを自動ダウンロード・実行するスクリプトです。

- **機能**: .NET Uninstall Toolの取得と実行
- **用途**: 不要な .NET SDK/Runtimeのクリーンアップ
- **ドキュメント**: [日本語](dotNetSdkUninstallToolの入手/Readme.md) | [English](dotNetSdkUninstallToolの入手/Readme.en.md)

```powershell
./dotNetSdkUninstallToolの入手/Script/DotNetUninstallTool.ps1
```

#### 🗑️ .NET SDK 削除
**パス**: [DotnetSdk削除/](DotnetSdk削除/)

指定した .NET SDKを直接アンインストールします。

```powershell
./DotnetSdk削除/Script/DotNetSdk_Uninstall.ps1
```

📖 [詳細なドキュメント](DotnetSdk削除/Readme.md)

#### 🛡️ Node.js 通信ブロック対応
**パス**: [Node.js通信ブロック対応/](Node.js通信ブロック対応/)

Node.jsの送信通信をブロックしている環境で、npmコマンドを安全に実行します。

- **機能**:
  - 一時的な通信許可と自動再ブロック
  - npm install/uninstall/update/ciの安全実行
  - DryRunモード（管理者権限不要）
  - エラー時でも確実な再ブロック保証
- **対応コマンド**: \`install\`, \`uninstall\`, \`update\`, \`ci\`

```powershell
# パッケージをインストール
./Node.js通信ブロック対応/Script/npm_install_safe.ps1 -Packages "express","lodash"

# DryRunで動作確認
./Node.js通信ブロック対応/Script/npm_install_safe.ps1 -DryRun -Packages "express"

# パッケージをアンインストール
./Node.js通信ブロック対応/Script/npm_uninstall_safe.ps1 -Packages "lodash"
```

📖 [詳細なドキュメント](Node.js通信ブロック対応/Readme.md)

### システム管理ツール

#### 📂 リリースバッチ自動化

**パス**: [リリースバッチ/](リリースバッチ/)

YAML設定に基づいて、ファイルを自動的にリリース先へコピーします。

- **機能**:
  - 複数環境対応（DEV/STG/PROD）
  - バージョニング（既存ファイルのタイムスタンプ付きリネーム）
  - 上書きポリシー切替（Rename/Delete/Skip）
  - リトライ・長パス対応
  - 詳細なログとサマリ出力
  - 二重起動防止

```powershell
# 本番環境へリリース
./リリースバッチ/Script/relMain.ps1

# 開発環境へリリース
./リリースバッチ/Script/relMain.ps1 -EnvFileName EnvDEV.yaml
```

📖 [詳細なドキュメント](リリースバッチ/Readme.md)

#### 🔓 ファイルアクセスブロック解除

**パス**: [ファイルアクセスブロック解除/](ファイルアクセスブロック解除/)

ダウンロードファイルの \`Zone.Identifier\` を削除し、Windowsのブロックを一括解除します。

- **機能**:
  - Zone.Identifier自動検出
  - ディレクトリの再帰的スキャン
  - 拡張子・フォルダパターンによる除外設定
  - 詳細ログとサマリ表示
  - 二重起動防止

```powershell
# デフォルトフォルダを処理
./ファイルアクセスブロック解除/Script/unblock_files.ps1

# 特定のディレクトリを処理
./ファイルアクセスブロック解除/Script/unblock_files.ps1 -TargetPath "C:\Downloads"
```

📖 [詳細なドキュメント](ファイルアクセスブロック解除/Readme.md)

#### 📦 必要なモジュールの導入

**パス**: [必要なモジュールの導入/](必要なモジュールの導入/)

YAML設定ファイルで指定したPowerShellモジュールを一括インストールします。

```powershell
./必要なモジュールの導入/Script/[メインスクリプト]
```

📖 [詳細なドキュメント](必要なモジュールの導入/Readme.md)

### データベースツール

#### 🗄️ SQLクエリー実行

**パス**: [SQLクエリー実行/](SQLクエリー実行/)

SQL Serverのクエリファイルを自動実行し、結果をログに記録します。

- **機能**:
  - 複数SQLファイルの順次実行
  - 文字エンコーディング自動変換（nkf32使用）
  - パスワードの暗号化・復号化
  - 実行結果の整形とログ記録
  - 処理統計とサマリ表示
  - 二重起動防止
- **対応**: SQL Server 2016/2019/2022

```powershell
./SQLクエリー実行/Script/sqlMain.ps1
```

**テスト環境構築**:

```bash
# Dockerでテストデータベースを作成
cd SQLクエリー実行/MakeContainer
docker-compose up -d
```

📖 [詳細なドキュメント](SQLクエリー実行/Readme.md)

### その他のツール

#### 🤖 Obsidian Copilot

**パス**: [ObsibianCopilot/](ObsibianCopilot/)

Obsidian Copilot関連のユーティリティスクリプト集です。

- CSV出力
- モデル表示
- QA登録時のコスト予測

📖 [詳細なドキュメント](ObsibianCopilot/Readme.md)

## セットアップ

### 1. リポジトリのクローン

```powershell
git clone https://github.com/[your-username]/PowerShell.git
cd PowerShell
```

### 2. 実行ポリシーの設定

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. 必要なモジュールのインストール

```powershell
# PowerShell-Yaml
Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Scope CurrentUser

# SqlServer（データベースツール使用時）
Install-Module -Name SqlServer -MinimumVersion 22.1.1 -Scope CurrentUser
```

### 4. 暗号化鍵の作成（オプション）

セキュリティツールを使用する場合：

```powershell
./暗号化鍵の作成/Script/MakeEncrypted.ps1
```

## ライセンス

このリポジトリで公開しているPowerShellスクリプトは、[MIT LICENSE](LICENSE) にて公開します。

- 私用・商用利用について制限はありません
- コードの変更や拡張を自由に行えます
- 遠慮なく業務や個人プロジェクトに活用してください

## 重要な注意事項

### ⚠️ 免責事項

**このリポジトリで公開している情報は、あくまでサンプルコードであり無保証です。**

- このリポジトリで公開するコードおよび情報に関して、いかなる保証も行いません
- 著者はこれらのコードおよび情報の利用により発生したいかなる損害に対しても責任を負いません
- 実際の運用にあたっては、**必ず自己責任で行ってください**

### 🔒 セキュリティに関する注意

**鍵ファイルや暗号化データ、パスワードについて:**

- リポジトリ内の鍵ファイルや暗号化データは**サンプル用**です
- **実際の運用では、必ず独自の鍵・パスワードを作成してください**
- 本番環境で使用する鍵ファイルは：
  - Git管理外に配置する
  - \`.gitignore\` に追加する
  - 誤ってコミットしないよう厳重に注意する
- 各ツールで自作の鍵を生成し、適切に管理してください

### 📋 推奨事項

1. **テスト環境での検証**: 本番環境で使用する前に、必ずテスト環境で動作を確認してください
2. **バックアップ**: 重要なファイルを操作する前に、必ずバックアップを取得してください
3. **ログの確認**: 各ツールが出力するログを確認し、想定通りの動作をしているか検証してください
4. **権限管理**: 管理者権限が必要なツールは、必要最小限の範囲で使用してください

## 📚 追加リソース

- [SCOPE_GUIDELINES.md](SCOPE_GUIDELINES.md) - スコープガイドライン
- 各ツールの詳細は、それぞれのディレクトリ内の \`Readme.md\` を参照してください

## 🤝 貢献

Issue報告やPull Requestを歓迎します。

---

**最終更新**: 2025年12月30日
