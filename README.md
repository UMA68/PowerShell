# PowerShell ユーティリティ集

実務で役立つPowerShellユーティリティ集です。
テスト（Pester）と静的解析（PSScriptAnalyzer）を前提に、迷わず・壊れず・あとで自分が助かる自動化を積み上げています。
定年後も通用する「安全に使えるPowerShellの型」を残すことを目的としています。

※ 本リポジトリはPublic化前にaudit-prepublic.ps1による公開前チェックを実施しています。

![PowerShell](https://img.shields.io/badge/PowerShell-7.x-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![CI](https://github.com/UMA68/PowerShell/actions/workflows/pester.yml/badge.svg)
![PSScriptAnalyzer](https://img.shields.io/badge/PSScriptAnalyzer-enabled-brightgreen.svg)

![Code Quality](https://img.shields.io/badge/Code%20Quality-Good-brightgreen.svg)

---

## 🔬 品質と設計方針（Public 向け補足）

このリポジトリは **個人および業務でそのまま利用できる完成コードを公開するものではありません**。
個人環境で検証・設計した **サンプル／試作スクリプト集** を目的として公開しています。

### 🤖 AI アシストについて（補足）
一部のコードや文書は、AIツール（Microsoft Copilotなど）のサポートを受けて作成しています。
- 最終的な判断や品質チェックは人間が行っています
- 真実の所在（Single Source of Truth）はGitHub上のコードです
- 生成物はPester / PSScriptAnalyzerで検証しています

### クリーンルーム運用

#### クリーンルーム宣言

- 本リポジトリは業務環境とは完全分離した検証用環境で作成・管理しています。
- 実在する会社情報・個人情報・メールアドレスは含めません。
- 例示に使用するメールアドレス・ドメインは `example.com` / `example.jp` / `example.co.jp` のみとします。
- 実装コードは、業務端末ではゼロから再入力・再構築する運用とします（ファイルは持ち込まない）。
- ログ・テスト結果・生成物（XML/LOG等）は、公開前監査と `.gitignore` 方針に基づきGitに含めません。
- 本リポジトリは業務用ではなく、安全な検証・設計のためのサンプル集として公開します。

- 業務環境（ネット分離・管理端末）とは **ファイルを移動せず完全分離**
- 実装コードは業務端末で **ゼロから再入力・再構築** する運用を徹底
- 本リポジトリに **業務情報・機密情報は含まれません**

## 🔍 公開前チェック（任意）

このリポジトリは **クリーンルーム運用** を前提としており、公開前に機密情報が混入していないことを確認する必要があります。

公開前に **`audit-prepublic.ps1`** を実行することで、以下のような「混入してはいけない情報」を機械的に検出できます：

- 実在メールアドレス／実在ドメイン（※ドメイン名は外部から注入）
- password / token / secretなどの「機密値を示唆するキーワード」
- ユーザー名・マシン名を含む絶対パス  
  例：`C:\Users\...` / `/Users/...` / `/home/...` / `\\server\share`
- HOSTNAME / COMPUTERNAMEなど環境情報の漏洩
- `testResults.xml` や `LOG/*.xml` など、テスト結果・ログの成果物ファイル

### 🔐 クリーンルーム方針（重要）
- **スクリプト内には実在ドメインを一切ハードコードしません。**  
- 実際に禁止したいドメインは **環境変数またはパラメーターで外から注入します**。  
- READMEでは例示用として **example.* ドメインのみを使用** します。[1](./audit-prepublic.ps1)

---

## 🔧 使用例（Forbidden ドメインを外部注入して監査）

公開前に、禁止したいドメイン（例：`example.co.jp`）を環境変数として渡してスクリプトを実行します。

```powershell
# 例：Forbidden ドメイン（サンプル値）を指定して公開前監査を実行
$env:FORBIDDEN_DOMAIN_REGEX = '@(example\.co\.jp)$'

pwsh ./audit-prepublic.ps1
```
または、パラメーターで直接渡すこともできます
```powershell
pwsh ./audit-prepublic.ps1 -ForbiddenDomainRegex '@(example\.co\.jp)$'
```

### 品質保証（CI）

- **Pester** による自動テスト（ローカル / GitHub Actions）
- **PSScriptAnalyzer** による静的解析（明示ルールのみ適用）
- CIでは *テスト + 静的解析* を必須とし、品質基準を満たす変更のみを許可します

この構成により、
> 「実務に持ち込めるかどうか」を判断するための *安全な検証台*  
として利用できることを目的としています。

---

## 📚 目次

- [PowerShell ユーティリティ集](#powershell-ユーティリティ集)
  - [🔬 品質と設計方針（Public 向け補足）](#-品質と設計方針public-向け補足)
    - [🤖 AI アシストについて（補足）](#-ai-アシストについて補足)
    - [クリーンルーム運用](#クリーンルーム運用)
      - [クリーンルーム宣言](#クリーンルーム宣言)
  - [🔍 公開前チェック（任意）](#-公開前チェック任意)
    - [🔐 クリーンルーム方針（重要）](#-クリーンルーム方針重要)
  - [🔧 使用例（Forbidden ドメインを外部注入して監査）](#-使用例forbidden-ドメインを外部注入して監査)
    - [品質保証（CI）](#品質保証ci)
  - [📚 目次](#-目次)
  - [概要](#概要)
  - [前提条件](#前提条件)
    - [基本要件](#基本要件)
    - [共通で必要なモジュール](#共通で必要なモジュール)
  - [共通機能 (Common)](#共通機能-common)
  - [ツール一覧](#ツール一覧)
    - [セキュリティツール](#セキュリティツール)
      - [🔐暗号化鍵の作成](#暗号化鍵の作成)
      - [🔒暗号化文字列の作成](#暗号化文字列の作成)
      - [🔓暗号化文字列の復元](#暗号化文字列の復元)
    - [開発ツール](#開発ツール)
      - [🔍DLL逆コンパイル (DecompileDLL)](#dll逆コンパイル-decompiledll)
      - [📦ILSpyCmd インストーラー](#ilspycmd-インストーラー)
      - [🛠️.NET SDK Uninstall Tool 管理](#️net-sdk-uninstall-tool-管理)
      - [🗑️.NET SDK 削除](#️net-sdk-削除)
      - [🛡️Node.js 通信ブロック対応](#️nodejs-通信ブロック対応)
    - [システム管理ツール](#システム管理ツール)
      - [📂リリースバッチ自動化](#リリースバッチ自動化)
      - [🔓ファイルアクセスブロック解除](#ファイルアクセスブロック解除)
      - [📦必要なモジュールの導入](#必要なモジュールの導入)
    - [データベースツール](#データベースツール)
      - [🗄️SQLクエリー実行](#️sqlクエリー実行)
    - [Excel操作ツール](#excel操作ツール)
      - [📊Excelの操作](#excelの操作)
        - [📊ExcelBook比較](#excelbook比較)
        - [💬Excelセルコメント](#excelセルコメント)
        - [🗄️ExportExcel](#️exportexcel)
    - [その他のツール](#その他のツール)
      - [🤖Obsidian Copilot](#obsidian-copilot)
  - [セットアップ](#セットアップ)
    - [1. リポジトリのFork](#1-リポジトリのfork)
    - [2. リポジトリのクローン](#2-リポジトリのクローン)
    - [3. 元リポジトリ（upstream）の設定と作業ブランチの作成](#3-元リポジトリupstreamの設定と作業ブランチの作成)
      - [upstreamリモートの設定](#upstreamリモートの設定)
      - [推奨ワークフロー](#推奨ワークフロー)
    - [4. 実行ポリシーの設定](#4-実行ポリシーの設定)
    - [5. 必要なモジュールのインストール](#5-必要なモジュールのインストール)
      - [推奨方法：ショートカットを使用](#推奨方法ショートカットを使用)
      - [手動インストール（オプション）](#手動インストールオプション)
    - [6. テストの実行](#6-テストの実行)
      - [ローカルテスト（pwsh）](#ローカルテストpwsh)
    - [CI（GitHub Actions）](#cigithub-actions)
    - [7. コード品質チェック](#7-コード品質チェック)
    - [8. 暗号化鍵の作成（オプション）](#8-暗号化鍵の作成オプション)
    - [9. デバッグ設定（開発時）](#9-デバッグ設定開発時)
      - [利用可能なデバッグ構成](#利用可能なデバッグ構成)
      - [設定の追加方法](#設定の追加方法)
      - [`launch.json`の設定例](#launchjsonの設定例)
  - [ライセンス](#ライセンス)
  - [重要な注意事項](#重要な注意事項)
    - [⚠️ 免責事項](#️-免責事項)
    - [🔒 セキュリティに関する注意](#-セキュリティに関する注意)
    - [📋 推奨事項](#-推奨事項)
  - [📚 追加リソース](#-追加リソース)
  - [Release Policy](#release-policy)
  - [🤝 貢献](#-貢献)
    - [貢献の方法](#貢献の方法)
    - [コーディング規約](#コーディング規約)
  - [CI / 運用ポリシー](#ci--運用ポリシー)

## 概要

このリポジトリは、日常的な開発・運用業務を効率化するためのPowerShellスクリプト集です。各ツールは独立して動作し、YAML設定ファイルによる柔軟なカスタマイズ、詳細なログ出力、エラーハンドリングなど、プロダクション環境でも使用できる品質を目指しています。
本リポジトリの正式サポートはPowerShell 7.xのみです（原則として最新）。

## 前提条件

### 基本要件

**PowerShell 7.x のみサポートし、Windows PowerShell 5.1 は動作保証しません。**

- **対応 OS: Windows 10/11**（一部ツールはWindows専用）
- **PowerShell 7.x（原則として最新）**
- **Windows PowerShell 5.1 は非対応**（動作保証しない）
  - 詳細は [ADR-0007](docs/adr/0007-drop-windows-powershell-5.1.md) を参照

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

# ImportExcel（Excel操作ツール用）
Install-Module -Name ImportExcel -Scope CurrentUser
```

## 共通機能 (Common)

[Common](Common/) フォルダーには、各ツールで共通的に使用されるユーティリティ関数が含まれています。

| スクリプト | 説明 |
| ----------- | ------ |
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

#### 🔐暗号化鍵の作成

**パス**: [暗号化鍵の作成/](暗号化鍵の作成/)

AES暗号化に使用する共通鍵ファイルを生成します。

- **機能**: 192/256/128ビットの暗号化鍵生成
- **出力**: \`Common/Encryption.key\`
- **用途**: パスワードや機密情報の安全な管理

```powershell
./暗号化鍵の作成/Script/MakeEncrypted.ps1 -KeySize 256
```

📖 [詳細なドキュメント](暗号化鍵の作成/Readme.md)

#### 🔒暗号化文字列の作成

**パス**: [暗号化文字列の作成/](暗号化文字列の作成/)

パスワードなどの機密情報を暗号化してファイルに保存します。

- **機能**: AES暗号化による文字列の暗号化
- **入力**: 平文文字列
- **出力**: 暗号化された文字列ファイル

```powershell
./暗号化文字列の作成/Script/MakeEncryptedString.ps1
```

📖 [詳細なドキュメント](暗号化文字列の作成/Readme.md)

#### 🔓暗号化文字列の復元

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

#### 🔍DLL逆コンパイル (DecompileDLL)

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

#### 📦ILSpyCmd インストーラー

**パス**: [ILSpyCmdの入手/](ILSpyCmdの入手/)

.NET逆コンパイルツールILSpyCmdを自動的にインストールします。

- **機能**:
  - ILSpyCmdのインストール状態確認とバージョン比較
  - .NET SDKの存在確認と自動インストール（タイムアウト10分・ロールバック対応）
  - ネットワーク接続の検証（NuGet.orgへICMP/HTTPで確認）
  - インストーラーファイルの整合性検証
  - 例外タイプに基づくログレベル自動分類
  - 非対話モード（`-NoKeyWait`）- ポップアップ抑止・スケジューラー用
- **バージョン**: v1.4.0（2026-01-07）
- **新機能（v1.4.0）**:
  - EnvYamlの柔軟な解決（ファイル名のみ、相対パス、絶対パス対応）
  - 例外分類ログ（FileNotFoundException/UnauthorizedAccessException等を自動振り分け）
  - 必須フィールド検証の強化

```powershell
# 基本実行（対話モード）
./ILSpyCmdの入手/Script/getILSpyCmd.ps1

# カスタム YAML 指定
./ILSpyCmdの入手/Script/getILSpyCmd.ps1 -EnvYaml "custom.yaml"

# 非対話モード（スケジューラー・CI/CD 用）
./ILSpyCmdの入手/Script/getILSpyCmd.ps1 -NoKeyWait

# 管理者権限で実行（SDK 導入時に必要）
Start-Process -FilePath pwsh -ArgumentList "-File","./ILSpyCmdの入手/Script/getILSpyCmd.ps1" -Verb RunAs
```

【検証スクリプト】

- `Verify_v1.4.0.ps1` によりv1.3.0（9項目）とv1.4.0（11項目）の合計20項目を自動検証します。
- 実行例（PowerShell 7）：

```powershell
pwsh -NoProfile -File "./ILSpyCmdの入手/Script/Verify_v1.4.0.ps1"
```

- 期待結果（成功時）：
  - `【v1.3.0 検証】 9 / 9 合格`
  - `【v1.4.0 検証】 11 / 11 合格`
  - `総合結果: 20 / 20 合格`

📖 [詳細なドキュメント](ILSpyCmdの入手/Readme.md) — 終了コード、YAML設定、安全な検証レシピを含む

#### 🛠️.NET SDK Uninstall Tool 管理

**パス**: [dotNetSdkUninstallToolの入手/](dotNetSdkUninstallToolの入手/)

Microsoftの .NET Uninstall Toolを自動ダウンロード・実行するスクリプトです。

- **機能**: .NET Uninstall Toolの取得と実行
- **用途**: 不要な .NET SDK/Runtimeのクリーンアップ

📖 [詳細なドキュメント](dotNetSdkUninstallToolの入手/Readme.md)

```powershell
./dotNetSdkUninstallToolの入手/Script/DotNetUninstallTool.ps1
```

#### 🗑️.NET SDK 削除

**パス**: [DotnetSdk削除/](DotnetSdk削除/)

指定した .NET SDKを直接アンインストールします。

```powershell
./DotnetSdk削除/Script/DotNetSdk_Uninstall.ps1
```

📖 [詳細なドキュメント](DotnetSdk削除/Readme.md)

#### 🛡️Node.js 通信ブロック対応

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

#### 📂リリースバッチ自動化

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

#### 🔓ファイルアクセスブロック解除

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

#### 📦必要なモジュールの導入

**パス**: [必要なモジュールの導入/](必要なモジュールの導入/)

YAML設定ファイルで指定したPowerShellモジュールを一括インストールします。

```powershell
./必要なモジュールの導入/Script/[メインスクリプト]
```

📖 [詳細なドキュメント](必要なモジュールの導入/Readme.md)

### データベースツール

#### 🗄️SQLクエリー実行

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

### Excel操作ツール

#### 📊Excelの操作

**パス**: [Excelの操作/](Excelの操作/)

PowerShellを使用してExcelファイルを操作するための各種スクリプト集です。ImportExcelモジュールやExcel COMオブジェクトを活用して、データの比較、コメント操作、SQL Serverからのデータエクスポートなど、さまざまなExcel操作を自動化できます。

##### 📊ExcelBook比較

2つのExcelファイルの内容を比較し、差分がある行を自動的に強調表示します。

- **機能**:
  - 2つのExcelブック（typeA.xlsxとtypeB.xlsx）の指定シート間でデータ比較
  - CD、KEY、Chr1～3、Num1～3の各列を基準に差分を検出
  - 差分がある行をシアン色で自動ハイライト
  - 差分データを`compdata.xlsx`として出力
  - オートフィルターとウィンドウ固定機能
- **使用技術**: ImportExcelモジュール、Excel COMオブジェクト

```powershell
./Excelの操作/ExcelBook比較/ExcelComp.ps1
```

##### 💬Excelセルコメント

Excelのセルにテキストとコメントを書き込み、コメント内容を別セルに抽出します。

- **機能**:
  - セルに値とコメントを記入
  - コメント枠のサイズを自動調整
  - マウスオーバー時のみ表示される設定
  - セルコメントの内容を取得して別セルに出力
  - コメントがない場合のエラーハンドリング
- **使用技術**: Excel COMオブジェクト

```powershell
./Excelの操作/Excelセルコメント/WriteCell.ps1
```

##### 🗄️ExportExcel

SQL Serverデータベースからデータを取得し、Excelファイルとして出力します。

- **機能**:
  - 暗号化されたパスワードを使用したセキュアなDB接続
  - パラメーター化されたSQLクエリの実行
  - 必要な列のみを抽出してExcel出力
  - 列幅自動調整、オートフィルター、先頭行固定
  - Excelテーブル形式での出力
  - 既存ファイルの上書き確認ダイアログ
- **使用技術**: SqlServerモジュール、ImportExcelモジュール、暗号化認証

```powershell
./Excelの操作/ExportExcel/ExptExcel.ps1
```

📖 [詳細なドキュメント](Excelの操作/Readme.md)

### その他のツール

#### 🤖Obsidian Copilot

**パス**: [ObsibianCopilot/](ObsibianCopilot/)

Obsidian Copilot関連のユーティリティスクリプト集です。

- CSV出力
- モデル表示
- QA登録時のコスト予測

📖 [詳細なドキュメント](ObsibianCopilot/Readme.md)

## セットアップ

### 1. リポジトリのFork

このリポジトリをご自身のGitHubアカウントにForkしてください。

1. [リポジトリページ](https://github.com/UMA68/PowerShell)を開く
2. 右上の「Fork」ボタンをクリック
3. ご自身のアカウントへのForkが完了

### 2. リポジトリのクローン

```powershell
git clone https://github.com/[your-username]/PowerShell.git
cd PowerShell
```

### 3. 元リポジトリ（upstream）の設定と作業ブランチの作成

#### upstreamリモートの設定

Fork元の最新変更を取り込めるよう、upstreamリモートを設定します。

```powershell
# upstreamリモートを追加
git remote add upstream https://github.com/UMA68/PowerShell.git

# 設定確認
git remote -v
```

#### 推奨ワークフロー

**mainブランチは同期専用**とし、実際の作業は**作業用ブランチ**で行います。

```powershell
# 1. 元リポジトリの最新情報を取得
git fetch upstream

# 2. mainブランチを最新に更新（自分の変更は含めない）
git checkout main
git merge upstream/main
git push origin main

# 3. 作業用ブランチを作成して切り替え
git checkout -b feature/my-improvement

# 4. 作業を行い、コミット
git add .
git commit -m "feat: add new feature"

# 5. 自分のForkへプッシュ
git push origin feature/my-improvement
```

**Pull Request作成時**:

1. 作業ブランチを自分のForkへプッシュ後、GitHubのリポジトリページを開く
2. 「Compare & pull request」ボタンが表示されるのでクリック
   - または、「Pull requests」タブ →「New pull request」をクリック
3. Pull Requestの設定を確認:
   - **base repository**: `UMA68/PowerShell` (元リポジトリ）
   - **base**: `main` (元リポジトリのmainブランチ）
   - **head repository**: `[your-username]/PowerShell` (自分のFork)
   - **compare**: `feature/my-improvement` (作業ブランチ）
4. タイトルと説明を記入:
   - タイトル: 変更内容を簡潔に（例: "feat: SQLクエリ実行時のエラーハンドリング改善"）
   - 説明: 変更の詳細、背景、テスト結果などを記載
5. 「Create pull request」をクリックして作成

**レビュー・マージ後**:

```powershell
# 元リポジトリに取り込まれたら、mainブランチを同期
git checkout main
git fetch upstream
git merge upstream/main
git push origin main

# 作業ブランチは削除（オプション）
git branch -d feature/my-improvement
git push origin --delete feature/my-improvement
```

**作業ブランチの更新**（元リポジトリの変更を取り込む場合）:

```powershell
# mainブランチを最新化
git checkout main
git fetch upstream
git merge upstream/main
git push origin main

# 作業ブランチに最新のmainをマージ
git checkout feature/my-improvement
git merge main
```

### 4. 実行ポリシーの設定

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 5. 必要なモジュールのインストール

#### 推奨方法：ショートカットを使用

`必要なモジュールの導入` フォルダー内の「`指定モジュールの導入.ps1 - ショートカット.lnk`」を実行してください。
このショートカットで、必要なすべてのモジュールが自動的にインストールされます。

#### 手動インストール（オプション）

```powershell
# PowerShell-Yaml
Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Scope CurrentUser

# SqlServer（データベースツール使用時）
Install-Module -Name SqlServer -MinimumVersion 22.1.1 -Scope CurrentUser

# ImportExcel（Excel操作ツール使用時）
Install-Module -Name ImportExcel -Scope CurrentUser

# PSScriptAnalyzer（コード品質チェック）
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser

# Pester（テスト実行時）
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser
```

### 6. テストの実行

リポジトリの品質を保つため、変更前後にテストを実行してください（PowerShell 7.x / `pwsh` 前提）：

`Tests/Integration/InstMain.Tests.ps1` の設計方針は、
[ADR-0020: InstMain 統合テストの共通化方針とテスト基盤設計](docs/adr/0020-instmain-test-architecture.md)
に従います。

#### ローカルテスト（pwsh）

<!-- updated -->

```powershell
# PowerShell 7.x（pwsh）でローカルの Unit テストを実行する例
pwsh -NoProfile -Command "Invoke-Pester -Path .\Tests\ -Tag 'Unit'"

# Integration テストがある場合
pwsh -NoProfile -Command "Invoke-Pester -Path .\Tests\Integration\"

# DecompileDll 統合テスト（Pester 5 ランナー経由）
pwsh -NoProfile -File .\Run-Pester5.ps1 -DecompileDll

# DecompileDll 統合テスト（直接実行）
pwsh -NoProfile -Command "Invoke-Pester -Path .\Tests\Integration\DecompileDll.Tests.ps1"
```

> **Note**: `DecompileDll.Tests.ps1` では、`Show-ErrorPopup` がブロッキングになる2ケース（`Error-FileNotFound-OldEmpty` / `Error-GeneralError-InvalidYaml`）を既定で `Skip` としています。

```powershell
# PowerShell 7.x を起動
pwsh

# Unit テストのみ実行
Invoke-Pester -Path .\Tests\ -Tag 'Unit' -Verbose
```

```powershell
# すべてのテストを実行
Invoke-Pester -Path .\Tests\ -Verbose

# Integration テストのみ実行
Invoke-Pester -Path .\Tests\ -Tag 'Integration' -Verbose

# 特定のテストファイルを実行
Invoke-Pester -Path .\Tests\Common\Get-ScriptPaths.Tests.ps1 -Verbose

# テストカバレッジを測定
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = .\Common\*.ps1
$config.CodeCoverage.OutputPath = 'coverage.xml'
Invoke-Pester -Configuration $config

# カバレッジレポートを確認
# coverage.xml を確認
```

**詳細**: [Tests/README.md](Tests/README.md) をご覧ください。

### CI（GitHub Actions）

CIでもローカルでも、PowerShell 7.x（原則として最新）を前提にしています。GitHub Actionsでは [pester.yml](.github/workflows/pester.yml) が `windows-latest` 同梱の `pwsh` を使用してPowerShell 7.x向けテストを実行します。詳細は [pester.yml](.github/workflows/pester.yml) と [ADR-0007](docs/adr/0007-drop-windows-powershell-5.1.md) を参照してください。

### 7. コード品質チェック

すべての変更はPSScriptAnalyzerのチェックを通過する必要があります：

変更ファイルのみを対象にする場合は、`scripts/Invoke-ScriptAnalyzerChanged.ps1` を使います（`PSScriptAnalyzerSettings.psd1` を必ず使用）。

```powershell
# ローカル実行例（直近コミットとの差分）
pwsh ./scripts/Invoke-ScriptAnalyzerChanged.ps1 -BaseRef HEAD~1 -HeadRef HEAD

# ローカル実行例（mainとの差分）
pwsh ./scripts/Invoke-ScriptAnalyzerChanged.ps1 -BaseRef origin/main -HeadRef HEAD
```

```powershell
# CI 実行例（PR のベースブランチとの差分）
pwsh ./scripts/Invoke-ScriptAnalyzerChanged.ps1 -BaseRef origin/main -HeadRef HEAD -FailOnSeverity Error,Warning
```

```powershell
# 自動生成物を除いた PowerShell ファイルを対象にコード品質をチェック
Get-ChildItem -Recurse -File -Include *.ps1,*.psm1,*.psd1 |
  Where-Object {
    $_.FullName -notmatch '\\.venv\\' -and
    $_.FullName -notmatch '\\.localmodules\\' -and
    $_.FullName -notmatch '(\\|^)(Tests|docs|adr|LOG)(\\|$)' -and
    $_.FullName -notmatch '\\.github\\'
  } |
  ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings .\PSScriptAnalyzerSettings.psd1 }

# Error/Warning レベルのみをチェック（推奨）
Get-ChildItem -Recurse -File -Include *.ps1,*.psm1,*.psd1 |
  Where-Object {
    $_.FullName -notmatch '\\.venv\\' -and
    $_.FullName -notmatch '\\.localmodules\\' -and
    $_.FullName -notmatch '(\\|^)(Tests|docs|adr|LOG)(\\|$)' -and
    $_.FullName -notmatch '\\.github\\'
  } |
  ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings .\PSScriptAnalyzerSettings.psd1 } |
  Where-Object { $_.Severity -in 'Error', 'Warning' }
```

> **Note**: Information レベルの警告は推奨ですが必須ではありません。詳細は [ADR-0006](docs/adr/0006-psscriptanalyzer-information-level.md) を参照してください。

> **Note**: リポジトリ全体のチェックは、`.venv` などの自動生成物を拾わないよう PowerShell で対象ファイルを列挙して実行します。実際の適用ルール・除外ルールの正本は [PSScriptAnalyzerSettings.psd1](PSScriptAnalyzerSettings.psd1) です。`LOG/`（配下含む）および検証成果物（例: `coverage.xml`, `testResults.xml`）は対象外として扱います。方針の背景は [ADR-0011](docs/adr/0011-repository-wide-scriptanalyzer-policy.md) を参照してください。

### 8. 暗号化鍵の作成（オプション）

セキュリティツールを使用する場合：

```powershell
./暗号化鍵の作成/Script/MakeEncrypted.ps1
```

### 9. デバッグ設定（開発時）

VS Codeでスクリプトをデバッグする際は、各種パラメーターを組み合わせたデバッグ構成を使用することで、開発作業がより効率的に進みます。ご自身の環境に合わせて `.vscode/launch.json` を設定してください（Git管理対象外）。

#### 利用可能なデバッグ構成

| 構成名 | 説明 | 用途 |
| ------ | ------ | ------ |
| **通常実行** | スクリプトを通常モードで実行 | 実際の処理を実行 |
| **WhatIfモード** | 実行結果をプレビュー | 処理内容を事前確認 |
| **DryRunモード** | 実際の変更を行わずにテスト | リスク低減デバッグ |
| **WhatIf + Verbose** | 詳細情報付きプレビュー | 詳細な動作確認 |
| **SkipAdminCheck Only** | 管理者チェックをスキップ | 権限不要なテスト |
| **SkipAdminCheck and DryRun** | 管理者チェックなしのDryRun | 安全なテスト実行 |

#### 設定の追加方法

1. VS Codeで `.vscode/launch.json` を開く
2. 下記の設定例をコピーし、`launch.json` の `"configurations"` セクションに追加
3. F5キーでデバッグを開始

#### `launch.json`の設定例

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "PowerShell: 通常実行",
      "type": "PowerShell",
      "request": "launch",
      "script": "${file}",
      "args": []
    },
    {
      "name": "PowerShell: WhatIfモード",
      "type": "PowerShell",
      "request": "launch",
      "script": "${file}",
      "args": ["-WhatIf"]
    },
    {
      "name": "PowerShell: DryRunモード",
      "type": "PowerShell",
      "request": "launch",
      "script": "${file}",
      "args": ["-DryRun"]
    },
    {
      "name": "PowerShell: WhatIf + Verbose",
      "type": "PowerShell",
      "request": "launch",
      "script": "${file}",
      "args": ["-WhatIf", "-Verbose"]
    },
    {
      "name": "PowerShell: SkipAdminCheck Only",
      "type": "PowerShell",
      "request": "launch",
      "script": "${file}",
      "args": ["-SkipAdminCheck"]
    },
    {
      "name": "PowerShell: SkipAdminCheck and DryRun",
      "type": "PowerShell",
      "request": "launch",
      "script": "${file}",
      "args": ["-SkipAdminCheck", "-DryRun"]
    }
  ]
}
```

詳細な設定は、ご自身の環境に合わせてカスタマイズしてください。`.vscode/launch.json`はGit管理対象外となっているため、各開発者が独自の設定を維持できます。

これらの構成を利用することで、スクリプトの動作確認やデバッグを効率良く行えます。

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
- [CONTRIBUTING.md](CONTRIBUTING.md) - 貢献ガイドライン
- 各ツールの詳細は、それぞれのディレクトリ内の \`Readme.md\` を参照してください

## Release Policy

- このリポジトリのタグは変更履歴そのものではなく、公開の節目を示します。
- すべての変更でリリースは行いません。
- Release Notesは、利用者が更新要否を判断するための案内です。
- [ADR-0016: Release & Tagging Policy](docs/adr/0016-release-and-tagging-policy.md)

## 🤝 貢献

このプロジェクトへの貢献を歓迎します！

### 貢献の方法

- **バグ報告**: [Issue](https://github.com/UMA68/PowerShell/issues)でバグレポートテンプレートを使用
- **機能提案**: [Issue](https://github.com/UMA68/PowerShell/issues)で機能リクエストテンプレートを使用
- **コード貢献**: [CONTRIBUTING.md](CONTRIBUTING.md)を参照してプルリクエストを作成

### コーディング規約

貢献する際は以下を遵守してください：

- [SCOPE_GUIDELINES.md](SCOPE_GUIDELINES.md)に従った変数スコープの使用
- PSScriptAnalyzerのチェックを通過すること（Error/Warningレベルは必須）

  ```powershell
  # Error/Warning レベルのみをチェック
  Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 |
    Where-Object { $_.Severity -in 'Error', 'Warning' }
  ```
  
  Informationレベルの扱いについては [ADR-0006](docs/adr/0006-psscriptanalyzer-information-level.md) を参照。除外対象とルールの正本は [PSScriptAnalyzerSettings.psd1](PSScriptAnalyzerSettings.psd1) および [ADR-0011](docs/adr/0011-repository-wide-scriptanalyzer-policy.md) を参照。

- [Conventional Commits](https://www.conventionalcommits.org/)に従ったコミットメッセージ
- 適切なドキュメントとコメントの追加

詳細は [CONTRIBUTING.md](CONTRIBUTING.md) をご覧ください。

---

## CI / 運用ポリシー

- このリポジトリのCIは **品質ゲート**として運用されます。
- 定期CI（四半期）は、PowerShell / GitHub Actionsの  
  **環境変化を検知する目的**で実行されます。
- CIが失敗した場合、**自動的に修正やマージは行いません**。
  人が内容を確認し、判断します。

CI失敗時の判断は、  
[docs/Playbook.md](docs/guides/Playbook.md)および **CI Failure Review Issue テンプレ**を用いて記録します。

詳細な設計判断については  
[ADR-0013: 定期（四半期）CIを環境変化検知専用とし、人間判断を前提とする](docs/adr/0013-quarterly-ci-as-environment-signal.md)  
を参照してください。

**最終更新**: 2026年2月25日

