# SQLクエリー実行スクリプト

SQL Serverのクエリファイルを自動実行し、結果をログに記録するPowerShellスクリプトです。

## 概要

このスクリプトは、指定されたフォルダー内の複数のSQLファイルを順序を保持して実行し、以下の処理を行います：

- SQLファイルの文字エンコーディング自動変換（UTF-8/CRLF対応）
- 接続情報の暗号化・復号化処理
- 実行結果の整形とログ記録
- エラーハンドリングと処理統計
- 二重起動防止機能
- 処理時間計測と成功率表示
- ログファイルの自動表示

## 主な機能

- **YAML設定ファイル**: 柔軟な構成管理
- **暗号化パスワード**: 安全な認証情報管理
- **文字コード自動変換**: nkf32による自動検出・変換
- **SQL Server 2019+対応**: TrustServerCertificate自動設定
- **詳細エラーログ**: 例外タイプとメッセージを記録
- **処理結果サマリ**: 成功数、エラー数、成功率を表示
- **COM安全管理**: リソースの確実な解放
- **変数スコープ統一**: 一貫性のある変数管理

## システム要件

### PowerShell

- **バージョン**: 7.3.9以上（YAML対応）
- **実行ポリシー**: RemoteSignedまたはUnrestricted

### 必須モジュール

| モジュール | バージョン |
|-----------|-----------|
| PowerShell-Yaml | 0.4.7 |
| SqlServer | 22.1.1 |

### 外部ツール

- **nkf32** - 文字コード変換ツール（日本語ファイル対応）

### SQL Server

- **2022以降** (TrustServerCertificate対応）
- または2019/2016（動作確認済み）

## ディレクトリ構造

```Shell
PowerShell/
├── Common/
│   ├── Encryption.key              # 復号化鍵
│   ├── NoDoubleActivation.ps1       # 二重起動チェック
│   └── CheckCommand.ps1            # コマンド検証
├── SQLクエリー実行/
│   ├── Script/
│   │   └── sqlMain.ps1             # メインスクリプト
│   ├── YAML/
│   │   └── sql.yaml                # 設定ファイル（重要）
│   ├── SQL/
│   │   ├── 01_init.sql
│   │   ├── 02_insert.sql
│   │   ├── 03_verify.sql
│   │   └── ...
│   ├── LOG/                        # ログ出力先（自動作成）
│   ├── mssql2022-dev-db.pass       # 暗号化パスワード
│   └── MakeContainer/              # DB初期構築用フォルダ
│       ├── docker-compose.yml
│       ├── init_customer_orders.sql
│       └── MSSQLコンテナとテストDB作成.md
```

## 実行環境について

### ホスト環境での実行

このスクリプトは **Windows ホスト上で実行** されます。SQL Serverはコンテナー（Docker/Podman）または物理/仮想マシン上で稼働し、ネットワーク経由で接続します。

**実行マシン:**

- PowerShell 7.3.9以上がインストール
- nkf32ツールがインストール
- SQL Serverへの通信可能なネットワーク環境

---

## インストール手順

### 0. PowerShell UTF-8設定（重要）

スクリプト実行前に、PowerShellをUTF-8モードで起動してください。以下のいずれかの方法で設定：

#### 方法A：スクリプト内で自動設定

```powershell
# スクリプトの最初で以下を実行
[System.Environment]::SetEnvironmentVariable('PYTHONIOENCODING', 'utf-8', 'Process')
chcp 65001 | Out-Null
```

#### 方法B：実行前にターミナルで設定

```powershell
chcp 65001
.\\ sqlMain.ps1
```

### 1. 外部ツールのインストール

#### nkf32 のインストール（優先度：高）

UTF-8 CRLF自動変換に必須です：

```powershell
# Option A: Chocolatey を使用
choco install nkf32

# Option B: 手動インストール
# 1. https://ja.osdn.net/projects/nkf/releases/ からダウンロード
# 2. nkf32.exe を System32 または PATH内のフォルダにコピー
# 3. 確認
nkf32 --version
```

##### nkf32 使用オプション一覧

sqlMain.ps1では以下のオプションでファイル文字エンコーディングの自動検出と変換を行います：

| オプション | 機能 | 用途 |
|-----------|------|------|
| `--guess` | ファイルの文字エンコーディング自動判定 | 入力ファイルの文字コード検出 |
| `--ms-ucs-map` | Microsoftの拡張UCS マッピングを使用 | SQL Server との互換性向上 |
| `-x` | 入力に対して `-X` フラグを強制 | 文字エンコーディング混在時の安全化 |
| `-wLw` | 改行コードをCRLFに変換（`-w` は出力を`w`モード） | Windows文法への統一 |
| `-O` | 出力ファイルを指定 | 変換結果を別ファイルに保存 |

##### 実装例

```powershell
# ステップ1: ファイルの文字エンコーディングを検出
$fileEncoding = & nkf32 --guess $sqlFile.FullName
# 例: "Shift_JIS (CRLF)", "EUC-JP (LF)", "UTF-8 (CRLF)" など

# ステップ2: UTF-8(CRLF)でない場合は変換
if ($fileEncoding -ne "UTF-8 (CRLF)") {
    $tempFile = $sqlFile.FullName + ".utf8(CRLF)"
    & nkf32 --ms-ucs-map -x -wLw -O $sqlFile.FullName $tempFile
    # 結果: $tempFile がUTF-8(CRLF)で保存される
}
```

##### 検出可能な文字エンコーディング（代表例）

| 検出結果 | エンコーディング | 改行コード |
|--------|----------------|---------|
| UTF-8 (LF) | UTF-8 | LF |
| UTF-8 (CRLF) | UTF-8 | CRLF |
| Shift_JIS (LF) | Shift-JIS | LF |
| Shift_JIS (CRLF) | Shift-JIS | CRLF |
| EUC-JP (LF) | EUC-JP | LF |
| EUC-JP (CRLF) | EUC-JP | CRLF |

### 2. 必須モジュールのインストール

```powershell
Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7 -Force
Install-Module -Name SqlServer -RequiredVersion 22.1.1 -Force
```

### 3. テストDB環境のセットアップ

#### 初回セットアップ（Docker/Podman でのDB構築）

以下のフォルダーでMSSQL Server 2022コンテナーとテストDBを作成します：

```powershell
cd "MakeContainer"
# MSSQLコンテナとテストDB作成.md の手順に従う
```

**必要なファイル:**

- `docker-compose.yml` - コンテナー構成
- `init_customer_orders.sql` - DB初期化スクリプト

詳細は `MakeContainer/MSSQLコンテナとテストDB作成.md` を参照

### 4. 鍵ファイルとパスワードの作成

`Common/` フォルダーに移動し、以下のスクリプトを実行：

```powershell
# 鍵ファイル作成
.\\MakeEncrypted.ps1

# 暗号化パスワード作成
.\\MakeEncryptedString.ps1
```

詳細は `暗号化鍵の作成/` フォルダーの説明を参照

## 使用方法

### 基本的な実行

```powershell
cd "C:\Users\徳永光浩\GitHub\PowerShell\SQLクエリー実行\Script"
.\\ sqlMain.ps1
```

### パラメーター指定

```powershell
# カスタム設定ファイルと鍵ファイルを指定
.\\ sqlMain.ps1 -DecryptionKey "MyEncryption.key" -EnvYaml "production.yaml"
```

#### パラメーター

| パラメーター | 型 | デフォルト | 説明 |
|-----------|----|---------|----|
| `DecryptionKey` | string | "Encryption.key" | 復号化鍵ファイル名 |
| `EnvYaml` | string | "sql.yaml" | 設定ファイル名 |

## 設定ファイル (sql.yaml)

### 基本構成

```yaml
# =================
Project: ExecuteSQL
Version: 1.0.0
# =================

# -----------------
# 実行環境
# -----------------
PowerShell: 
 Version: 7.3.9

Module:
 Powershell-Yaml:
  Name: Powershell-Yaml
  Version: 0.4.7
 SqlServer:
  Name: SqlServer
  Version: 22.1.1

# -----------------
# 接続情報（SQL Server）
# -----------------
HOST:
 SERVER: 127.0.0.1                       # SQL Serverホスト（IPまたはホスト名）
 PORT: 11433                             # ポート番号（Dockerなど非標準の場合は指定）
 DATABASE: appdb                         # 対象データベース名
 USERNAME: sa                            # SQL認証ユーザー名
 PWF: mssql2022-dev-db.pass             # 暗号化パスワードファイル（相対パス）
 VERSION: Microsoft SQL Server 2022...   # バージョン情報（自動検出）

# -----------------
# ログ設定
# -----------------
LOG:
 FOLDER: LOG                             # ログ保存先フォルダ（相対パス）
 FILENAME: log                           # ログファイル基本名
 EXTENSION: .log                         # ファイル拡張子
                                         # 実際のファイル: log_yyyyMMdd_HHmmss.log

# -----------------
# SQL実行設定
# -----------------
RELEASE:
 SQL:
  FolderBy:
   - SQL                                 # SQLファイル格納フォルダ（相対パス）
```

### 設定項目の詳細

#### HOST セクション

- **SERVER**: SQL Serverのホスト名またはIPアドレス
- **PORT**: ポート番号（デフォルト: 1433）
  - Dockerなどで非標準ポートの場合は指定
- **DATABASE**: 接続先データベース名
- **USERNAME**: SQL Server認証のユーザー名
  - Windows認証は別途対応が必要
- **PWF**: パスワードファイル名（暗号化済み）
- **VERSION**: `SELECT @@VERSION;` の出力結果
  - SQL Serverバージョン判定に使用

#### LOG セクション

- **FOLDER**: ログ出力先（相対パスは親フォルダーからの相対位置）
- **FILENAME**: ログファイル名基本部分
  - 実際のファイル名: `{FILENAME}_{yyyyMMdd_HHmmss}{EXTENSION}`
  - 例: `log_20251209_140530.log`
- **EXTENSION**: ファイル拡張子

## SQLファイル形式

### 対応形式

- **拡張子**: `.sql`
- **文字エンコーディング**: UTF-8/Shift-JISなど任意（自動変換）
- **改行コード**: LF/CRLFなど任意（自動的にCRLFに統一）
- **文字セット**: 日本語対応（nkf32による変換）

### ファイル例

```sql
-- 01_init.sql
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    Name NVARCHAR(100) COLLATE Japanese_90_CI_AS_SC_UTF8,
    Email NVARCHAR(100) COLLATE Japanese_90_CI_AS_SC_UTF8
);
GO
```

```sql
-- 02_insert.sql
INSERT INTO dbo.Customers (CustomerID, Name, Email)
VALUES 
    (1, '太郎', 'taro@example.com'),
    (2, '花子', 'hanako@example.com');
GO
```

### ファイル名規約（重要）

- ファイルは **英数字でソートされた順序** で実行されます
- **実行順序が重要な場合は、必ずファイル名に番号を付けてください**
  - ✅ **推奨**: `01_init.sql`, `02_insert.sql`, `03_verify.sql`
  - ❌ **非推奨**: `init.sql`, `insert.sql`, `verify.sql`（実行順序不定）

### バッチ分割

ファイル内で複数のバッチを実行する場合は `GO` で区切ってください：

```sql
-- ステートメント1
CREATE TABLE ...
GO

-- ステートメント2
INSERT INTO ...
GO
```

## ログファイル

### ログの場所

```log
SQLクエリー実行/LOG/log_yyyyMMdd_HHmmss.log
```

### ログの内容

```log
====================================
01_init.sql
====================================
(結果セットなし)
====================================

====================================
02_insert.sql
====================================

CustomerID  Name      Email
-----------  --------  ----
1           太郎      taro@example.com
2           花子      hanako@example.com

====================================

実行完了: 合計 3 件 (成功: 3 件, エラー: 0 件)
```

### ログ情報

各SQLファイルについて以下が記録：

- ファイル名
- 実行結果（テーブル形式）
- エラーメッセージ（発生時）
- 処理統計（合計件数、成功数、エラー数）

## 処理フロー

スクリプトは以下の順序で処理を実行します：

1. **パラメーター検証**
   - パス存在チェック（空・特殊文字・長さ）
   - YAML設定ファイル検証

2. **二重起動チェック**
   - Mutex使用による同時実行防止
   - 既存プロセスがある場合は警告を表示して終了

3. **環境チェック**
   - nkf32コマンド存在確認
   - PowerShell-Yamlモジュール検証

4. **YAML設定読込**
   - `-Raw`オプションで文字列として読込
   - ConvertFrom-YamlでPowerShellオブジェクトに変換

5. **ディレクトリ構造検証**
   - SQLフォルダー存在確認
   - LOGフォルダー存在確認（なければ作成）

6. **SQLファイル取得**
   - `*.sql` パターンでフィルタリング
   - ファイル名順でソート

7. **鍵ファイル読込**
   - AES暗号化鍵をSecureStringとして読込
   - 読込成功を通知

8. **パスワード復号化**
   - 暗号化パスワードファイルから読込
   - 鍵ファイルを使用して復号化

9. **ログファイル初期化**
   - タイムスタンプ付きログファイル作成
   - 開始ログ記録（HOST、USER、Server、Database）

10. **各SQLファイル処理**
    - nkf32でUTF-8/CRLF変換
    - SQL Server接続とクエリ実行
    - 結果の整形とログ記録
    - 例外発生時は型情報を含むエラーログ出力

11. **処理結果集計**
    - 成功数、エラー数、成功率を計算
    - 処理時間を「分:秒」形式で表示

12. **ログ自動表示**
    - 処理完了後にログファイルを自動的に開く

13. **クリーンアップ**
    - パスワード変数のクリア
    - COMオブジェクトの解放

14. **エラー時キー待機**
    - エラーが発生した場合、キー入力を待機
    - ショートカット実行時のウィンドウ即時クローズを防止

## トラブルシューティング

### エラーメッセージと対応

| エラーメッセージ | 原因 | 対応方法 |
|-------------|------|--------|
| "PowerShell-Yamlモジュールがインストール..." | モジュール未インストール | `Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7 -Force` を実行 |
| "sql.yamlファイルが見つかりません" | 設定ファイル未配置 | `SQLクエリー実行/YAML/` フォルダーに sql.yaml を配置 |
| "SQLフォルダーが見つかりません" | SQL格納フォルダーなし | `SQLクエリー実行/SQL/` フォルダーを作成し、SQLファイルを配置 |
| "鍵ファイルが見つかりません" | 暗号化鍵未配置 | `PowerShell/Common/` フォルダーに Encryption.key を配置 |
| "パスワードファイルが見つかりません" | パスワードファイル未配置 | sql.yaml の PWF で指定したファイルを配置 |
| "パスワードの復号化に失敗しました" | 鍵またはパスワードが破損 | 鍵ファイルとパスワードを再作成 |
| "Cannot insert duplicate key..." または "Violation of UNIQUE KEY constraint" | データベース制約違反 | 既存データをクリア、または DB を初期化してから再実行 |
| "nkf32: command not found" | nkf32 未インストール | インストール手順を確認し nkf32 をインストール |
| "Invalid character encoding" | ファイルエンコーディングエラー | SQLファイルを UTF-8 で再保存 |
| "すでに実行中です" | 二重起動検出 | 既存プロセスを確認・終了してから再実行 |

### よくある問題

#### 1. 文字エンコーディングエラー

**症状**: SQLファイル内の日本語が文字化けする

**解決方法**:

- SQLファイルをUTF-8(CRLF)で保存
- nkf32が正しくインストールされているか確認

```powershell
# nkf32の確認
nkf32 --version
```

#### 2. ネットワーク接続エラー

**症状**: "Named Pipes provider, error: 40"

**解決方法**:

- SQL Serverの接続情報を確認
  - ホスト名/IP
  - ポート番号（Dockerの場合は確認）
- ファイアウォール設定を確認
- SQL Server認証が有効か確認

#### 3. 二重起動エラー

**症状**: "すでに実行中です" のメッセージが表示

**解決方法**:

- すでに実行中のスクリプトがないか確認
- プロセスを確認/終了

```powershell
# プロセス確認
Get-Process | grep -i sqlMain

# 強制終了
Stop-Process -Name powershell -Force
```

#### 4. パスワード関連エラー

**症状**: "パスワードの復号化に失敗しました"

**解決方法**:

- 鍵ファイルが正しいか確認
- パスワードファイルが破損していないか確認
- 別のマシンで実行した場合、鍵が異なる可能性

```powershell
# 新しい鍵とパスワードで再作成
cd "暗号化鍵の作成"
.\\ MakeEncrypted.ps1
.\\ MakeEncryptedString.ps1
```

#### 5. ショートカット実行時のウィンドウクローズ

**症状**: エラー発生時にウィンドウがすぐ閉じて内容が見えない

**解決方法**:

- v2.0.0以降、エラー発生時は自動的にキー入力待機
- メッセージを確認後、任意のキーで終了
- ログファイルでも詳細確認可能

#### 6. SQL例外の詳細確認

**症状**: SQL実行エラーの原因を特定したい

**解決方法**:

- v2.0.0以降、例外タイプがログに記録される
- ログファイルで `System.Data.SqlClient.SqlException` などの型情報を確認
- エラーメッセージと併せて原因を特定

## セキュリティに関する注意

### パスワード管理

1. **暗号化鍵（Encryption.key）**
   - マシン固有の鍵
   - 別のマシンに移行する場合は鍵を再作成
   - バージョン管理システムにはコミットしない

2. **暗号化パスワード（*.pass）**
   - 暗号化されているため保存可能
   - ただし鍵が漏洩すると復号化される可能性
   - バージョン管理にコミットする際は注意

### 環境変数

パスワードを環境変数で指定する場合：

```powershell
# 環境変数にセット（セッション中のみ有効）
\ = "your_password"
```

## 実行例

### シンプルな実行

```powershell
.\\ sqlMain.ps1
# ログ出力: LOG/log_20251209_140530.log
```

### カスタム設定で実行

```powershell
.\\ sqlMain.ps1 -DecryptionKey "prod.key" -EnvYaml "production.yaml"
```

### 定期実行（Windows タスクスケジューラ）

1. **タスクスケジューラを開く**
   - `taskschd.msc`

2. **基本タスクを作成**
   - 名前: "SQLクエリー自動実行"
   - トリガー: 毎日　02:00

3. **操作を設定**
   `
   プログラム: C:\\Windows\\System32\\pwsh.exe
   引数: -NoProfile -ExecutionPolicy Bypass -File "C:\\Users\\...\\sqlMain.ps1"
   `

## 出力形式

### 標準出力

```Shell
鍵ファイル『Encryption.key』を読み込みました。
====================================
01_init.sql
====================================
(結果セットなし)
====================================
...
実行完了: 合計 3 件 (成功: 3 件, エラー: 0 件)
```

### ログファイル出力

同じ情報が `LOG/log_*.log` に記録される

### エラー時

```log
///エラーが発生しました。///
Msg 2627, Level 14, State 1
Violation of UNIQUE KEY constraint
```

## パフォーマンスチューニング

### 大量ファイル実行時

SQLクエリーのタイムアウトが必要な場合、`sqlMain.ps1` を編集：

```powershell
# sqlMain.ps1 の process ブロック内
\ = @{
    ErrorAction     = 'Stop'
    InputFile       = \.FullName
    ServerInstance  = \
    Database        = \
    Username        = \
    Password        = \
    QueryTimeout    = 300  # 秒単位（0=無制限）
}
```

### ネットワーク遅延対策

コンテナー環境での遅延がある場合は、実行前に待機：

```powershell
# SQL Server 起動後、30秒待機して実行
Start-Sleep -Seconds 30
.\\ sqlMain.ps1
```

## 関連スクリプト

| スクリプト | 場所 | 用途 |
|-----------|------|------|
| MakeEncrypted.ps1 | 暗号化鍵の作成/ | 復号化鍵を生成 |
| MakeEncryptedString.ps1 | 暗号化文字列の作成/ | パスワードを暗号化 |
| StringDecryption.ps1 | 暗号化文字列の復元/ | パスワードを復号化 |
| NoDoubleActivation.ps1 | Common/ | 二重起動を防止 |
| CheckCommand.ps1 | Common/ | 必要ツールを検証 |

## ライセンス

MIT License

## サポート

問題が発生した場合：

1. ログファイルで詳細エラーを確認
2. トラブルシューティングセクションを参照
3. 必要に応じて設定ファイルを見直し

## バージョン履歴

### v2.0.0 (2025-12-12)

#### アーキテクチャ改善

- **exit文の完全排除**: すべての`exit`を`$script:CanExecuteProcess`フラグと`return`に置換
- **endブロック保証**: エラー時でもクリーンアップとログ表示が確実に実行される設計

#### 新機能

- **ShowPopupヘルパー**: COMオブジェクトの安全な解放を保証する共通関数を実装
- **ログ自動表示**: 処理完了後、ログファイルを自動的に開いて結果を確認可能
- **処理時間表示**: 実行時間を「MM:Min SS:Sec」形式で表示
- **成功率表示**: 処理成功率を百分率で計算・表示
- **エラー時キー待機**: ショートカット実行時にエラーメッセージを確認可能

#### エラーハンドリング強化

- **例外タイプログ**: エラー発生時に例外の完全修飾名を記録 (`GetType().FullName`)
- **詳細な開始ログ**: HOST、USER、Server、Databaseの情報を記録
- **Test-Command/Test-NoDoubleActivation戻り値チェック**: 初期チェックの信頼性向上

#### コード品質改善

- **パラメーター検証順序**: 空文字→特殊文字→長さの論理的な順序に修正
- **変数スコープ統一**: `$password` → `$script:password` で一貫性を確保
- **セキュリティ強化**: endブロックでパスワード変数を確実にクリア

### v1.0.0 (2025-12-09)

- 初版リリース
- PowerShell 7.3.9対応
- SQL Server 2022対応（2019/2016でも動作）
- 日本語ファイル対応（UTF-8 CRLF自動変換）
- 暗号化パスワード対応
- Docker/Podmanコンテナー環境対応
- ファイル名順序実行
- エラーハンドリングと統計情報表示

---

**最終更新:** 2025年12月12日
