# リリースバッチ自動化スクリプト

YAML設定に基づいてファイルを自動的にリリース先へコピーするPowerShellスクリプトです。

## 概要

`relMain.ps1` は、YAML設定ファイルで定義されたリリースタイプごとに、リリース元フォルダーからリリース先フォルダーへファイルを自動コピーします。開発環境（DEV）、ステージング環境（STG）、本番環境（PROD）など、複数の環境設定に対応しています。

## 主な機能

- ✅ **複数環境対応**: DEV/STG/PRODなど環境別のYAML設定ファイル
- ✅ **バージョニング**: 既存ファイルをタイムスタンプ付きでリネーム保存
- ✅ **多言語メッセージ**: 日本語/英語のメッセージ表示
- ✅ **自動ログ生成**: 実行ログを自動生成（機密情報マスキング対応）
- ✅ **二重起動防止**: 同時実行を防止する早期チェック機能
- ✅ **セキュリティ**: ログディレクトリ・ファイルのパーミッション管理
- ✅ **検証機能**: PowerShellバージョン・必須モジュールの自動チェック
- ✅ **スコープ管理**: `$script:` による一貫した変数管理
- ✅ **上書きポリシー切替**: Rename/Delete/Skipの切替をYAMLで指定
- ✅ **リトライ/長パス対応**: 再試行回数・待機時間と長パス有効化をYAMLで指定
- ✅ **サマリ出力**: コピー/リネーム/削除/失敗件数をタイプ単位で集計

## 前提条件
Env.yamlの設定を使用するには、以下の前提条件を満たす必要があります。

Cドライブのルートに `SandBox\TEST_FOLDER` ディレクトリが存在し、実行ユーザーが書き込み権限を持っていること。

```
C:\SANDBOX
└─TEST_FOLDER
    ├─リリース元
    │  ├─LOG
    │  ├─TYPE_A
    │  │      TEST_A_01.txt
    │  │      TEST_A_02.txt
    │  │      TEST_A_03.txt
    │  │      
    │  ├─TYPE_B
    │  └─TYPE_C
    └─リリース先
        ├─TYPE_A
        │  ├─DEV
        │  ├─PROD
        │  └─STG
        ├─TYPE_B
        │  ├─DEV
        │  ├─PROD
        │  └─STG
        └─TYPE_C
            ├─DEV
            ├─PROD
            └─STG
```

### 検証用フォルダー作成（任意）

検証環境用のフォルダー構成は、以下のスクリプトで作成できます。
```powershell
# DryRun
.\make_sandbox_folders.ps1 -WhatIf

# 実行
.\make_sandbox_folders.ps1
```
※ スクリプトは、本リポジトリのルートにあります。

### 必須環境

- **PowerShell**: 7.3.9以上
- **実行ポリシー**: RemoteSigned以上

### 必須モジュール

以下のモジュールが自動的にインポートされます（未インストールの場合は手動インストールが必要）：

- `PowerShell-Yaml` 0.4.7以上
- `SqlServer` 22.1.1以上

```powershell
# モジュールインストール例
Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Scope CurrentUser
Install-Module -Name SqlServer -MinimumVersion 22.1.1 -Scope CurrentUser
```

## ディレクトリ構造

```Shell
PowerShell/
├── Common/
│   ├── Encryption.key              # 暗号化鍵（将来使用予定）
│   ├── FindModule.ps1              # モジュール検索関数
│   ├── NoDoubleActivation.ps1      # 二重起動防止機能
│   └── Write-CommonLog.ps1         # ログ出力関数
└── リリースバッチ/
    ├── Readme.md                   # このファイル
    ├── Script/
    │   ├── relMain.ps1             # メインスクリプト
    │   └── CopyItemCustom.ps1      # ファイルコピー処理
    ├── YAML/
    │   ├── EnvDEV.yaml             # 開発環境設定
    │   ├── EnvSTG.yaml             # ステージング環境設定
    │   └── EnvPROD.yaml            # 本番環境設定
    └── LOG/                         # 自動作成
        └── relMain_YYYYMMDD-HHmmss.log
```

## 使用方法

### 基本的な使い方

```powershell
# デフォルト（DEV環境）で実行
.\Script\relMain.ps1

# STG環境で実行
.\Script\relMain.ps1 -EnvYaml "EnvSTG.yaml"

# PROD環境で実行
.\Script\relMain.ps1 -EnvYaml "EnvPROD.yaml"
```

### パラメーター

#### `-EnvYaml`

環境設定YAMLファイル名を指定します（デフォルト: `EnvDEV.yaml`）

**有効な値:**

- `EnvDEV.yaml` - 開発環境
- `EnvSTG.yaml` - ステージング環境
- `EnvPROD.yaml` - 本番環境

**検証ルール:**

- `.yaml` または `.yml` 拡張子が必須
- ファイル名に使用できない文字（`\ / : " * ? < > |`）を含まない
- 空白文字のみの入力は不可
- 最大255文字

#### `-DecryptionKey`

暗号化鍵ファイル名を指定します（デフォルト: `Encryption.key`）

**注意:** 現在このパラメーターは未使用です。将来的にリリース設定に機密情報（パスワード、APIキーなど）を含める場合の暗号化・復号化機能用に予約されています。

実装例は `SQLクエリー実行/Script/sqlMain.ps1` の復号化処理を参照してください。

**検証ルール:**

- ファイル名に使用できない文字を含まない
- 空白文字のみの入力は不可
- 最大255文字

## YAML設定ファイル

### 設定例（EnvDEV.yaml）

```yaml
# 環境設定
Environment: DEV
Language: ja  # ja: 日本語, en: 英語

# 必須モジュール
RequiredModules:
  - Name: SqlServer
    MinimumVersion: 22.1.1

# リリース設定
ReleaseTypes:
  - Type: TYPE_A
    SourcePath: C:\Projects\AppA\Release
    DestinationPath: \\Server\Share\AppA
    Files:
      - app.exe
      - config.xml
      - libs\*.dll
  
  - Type: TYPE_B
    SourcePath: C:\Projects\AppB\Output
    DestinationPath: \\Server\Share\AppB
    Files:
      - service.exe
      - settings.json

# メッセージ定義
Messages:
  ja:
    Error_NoYamlFile: "YAMLファイルが見つかりません: {0}"
    Error_InvalidYaml: "YAML読み込みエラー: {0}"
    # ... その他のメッセージ
  en:
    Error_NoYamlFile: "YAML file not found: {0}"
    Error_InvalidYaml: "YAML read error: {0}"
    # ... その他のメッセージ
```

### 主要な設定項目

| 項目 | 説明 | 必須 |
|------|------|:----:|
| `Environment` | 環境名（DEV/STG/PROD） | ✓ |
| `Language` | メッセージ言語（ja/en） | ✓ |
| `RequiredModules` | 必須モジュールリスト | ✓ |
| `ReleaseTypes` | リリース定義の配列 | ✓ |
| `Messages` | メッセージ定義（多言語対応） | ✓ |

### リリースタイプ設定

各リリースタイプには以下の項目を指定します：

| 項目 | 説明 | 例 |
|------|------|-----|
| `Type` | リリースタイプ名 | TYPE_A |
| `SourcePath` | コピー元パス | C:\Projects\App |
| `DestinationPath` | コピー先パス | \\Server\Share |
| `Files` | コピー対象ファイルパターン | *.exe, config.xml |
| `OverwritePolicy` | 上書きポリシー (`RenameThenCopy`/`DeleteThenCopy`/`SkipIfExists`) | RenameThenCopy |
| `RetryCount` | 再試行回数（0で無効） | 3 |
| `RetryDelayMs` | 再試行待機ミリ秒 | 200 |
| `EnableLongPath` | 長パスを`\\?\`で有効化するか | true |

## ログ出力

### ログファイル

ログファイルは `LOG/` ディレクトリに自動生成されます。

#### LOG設定例

```yaml
LOG:
  Path: \\localhost\C$\SandBox\TEST_FOLDER\リリース元\LOG
  FILENAME: release(DEV)
  EXTENSION: .log
  USERS:                     # 追加閲覧ユーザー（配列、省略可）
    - "DOMAIN\\AuditUser"    # 監査ユーザー
    - "DOMAIN\\ReviewUser"   # レビュアー
```

#### アクセス権ポリシー

- ログディレクトリ: 実行ユーザー=フル、`USERS`=読み取り
- ログファイル: 実行ユーザー=読み書き、`USERS`=読み取り
- `USERS` に実行ユーザーと同一のユーザーが含まれる場合は、重複付与を避け読み取りのみ

**ファイル名形式:** `relMain_YYYYMMDD-HHmmss.log`

**例:** `relMain_20251210-143025.log`

### ログ内容

- スクリプト開始・終了時刻
- 実行環境情報（ユーザー名、ホスト名、PowerShellバージョン）
- YAML設定の読み込み結果
- 各リリースタイプのコピー処理結果
- エラーメッセージ
- 実行時間（分:秒）

### 機密情報マスキング

ログには機密情報マスキング機能が実装されています。以下のパターンは自動的に `****` に置き換えられます：

- パスワード
- トークン
- APIキー
- シークレット
- 接続文字列

## エラー処理

### 二重起動防止

スクリプトは二重起動を防止します。すでに実行中の場合、以下のメッセージが表示され終了します：

```text
スクリプトは既に実行中です。
```

### バージョンチェック

PowerShell 7.3.9未満の環境では実行できません：

```text
このスクリプトはPowerShell 7.3.9以降が必要です。現在のバージョン: 7.x.x
```

### モジュールチェック

必須モジュールが見つからない場合、エラーメッセージが表示されます：

```text
必須モジュール 'SqlServer' (最小バージョン: 22.1.1) が見つかりません。
```

## トラブルシューティング

### Q: YAMLファイルが読み込めない

**A:** 以下を確認してください：

1. YAMLファイルが `YAML/` ディレクトリに存在するか
2. ファイル名のスペルが正しいか
3. YAML構文が正しいか（インデント、コロン、ハイフンなど）

### Q: ファイルコピーが失敗する

**A:** 以下を確認してください：

1. コピー元パスが存在するか
2. コピー先パスへの書き込み権限があるか
3. ネットワークドライブの場合、接続が有効か
4. ファイルが他のプロセスで使用中でないか

### Q: ログファイルが作成されない

**A:** 以下を確認してください：

1. `LOG/` ディレクトリへの書き込み権限があるか
2. ディスク容量が十分にあるか
3. ウイルス対策ソフトがブロックしていないか

## セキュリティ

### パーミッション管理

スクリプトは自動的に以下のパーミッションを設定します：

- **LOGディレクトリ**: 実行ユーザーのみアクセス可能
- **ログファイル**: 実行ユーザーのみ読み書き可能

### 機密情報の取り扱い

現在、YAML設定ファイルに機密情報を含めることはサポートされていません。将来のバージョンで暗号化機能を実装予定です。

**将来の暗号化機能:**

- パスワード、APIキーなどの暗号化保存
- 鍵ファイルによる復号化
- 実装例: `SQLクエリー実行/Script/sqlMain.ps1`

## 変更履歴

### v1.3.0 (2026-01-20)

- ✅ CopyItemCustom.ps1: 関数呼び出し名の修正（197行目）
- ✅ relMain.ps1からの実行エラーを解消
- ✅ PSScriptAnalyzer警告をすべて解決（40+件）
- ✅ コードスタイルの統一（スペース、括弧の配置）
- ✅ 空のcatchブロックにエラー処理を追加
- ✅ 内部関数のヘルプコメント追加
- ✅ 関数名を単数形に変更（Invoke-ReleaseRule）

### v1.2.0 (2025-12-10)

- ✅ 変数スコープの統一（`$script:` プレフィックス）
- ✅ パラメーター検証の強化（ValidateScript属性）
- ✅ ログ出力の重複削除（秒数表示を削除、Min:Sec形式のみ）
- ✅ 未使用変数の文書化（$DecryptionKey, $KeyPath）
- ✅ パス結合を `Join-Path` に統一
- ✅ 全exitポイントでCOMオブジェクト解放
- ✅ ログファイルセキュリティ機能追加
- ✅ 二重起動チェックを `begin` ブロックに移動（早期チェック）
- ✅ COMオブジェクト管理を関数化
- ✅ ファイルコピーの上書きポリシーをYAMLで切替（Rename/Delete/Skip）
- ✅ 削除/リネーム/コピーに再試行（回数・待機をYAMLで設定）
- ✅ 長パス対応をYAMLで切替
- ✅ コピー結果のサマリログ（Copied/Renamed/Deleted/Failed）を出力

### v1.1.0 (2025-12-09)

- ✅ マルチ言語メッセージサポート実装
- ✅ スクリプトブロックによるメッセージ管理
- ✅ ログディレクトリパーミッション管理

### v1.0.0 (2025-11-20)

- ✅ 初版リリース
- ✅ 基本的なリリース機能実装

## 関連リンク

- **GitHub**: [https://github.com/UMA68/PowerShell](https://github.com/UMA68/PowerShell)
- **Wiki**: [https://github.com/UMA68/PowerShell/wiki](https://github.com/UMA68/PowerShell/wiki)
- **スコープガイドライン**: [../SCOPE_GUIDELINES.md](../SCOPE_GUIDELINES.md)

## ライセンス

このプロジェクトのライセンスについては、リポジトリルートの `LICENSE` ファイルを参照してください。

## 作成者

UMA68

## お問い合わせ

問題や質問がある場合は、GitHubのIssuesページでお知らせください。
