# ExportExcel - ExptExcel.ps1

## 概要

SQL Serverデータベースからデータを取得し、Excelファイルとして出力するPowerShellスクリプトです。暗号化されたパスワードを使用してセキュアにデータベース接続を行い、取得したデータを整形してExcelファイルに保存します。

## 主な機能

### 🔐 セキュアなデータベース接続

- **暗号化パスワード**: 暗号化ファイルからパスワードを復号化
- **鍵ファイル認証**: 共通鍵を使用した安全な認証
- **SQL Server認証**: ユーザーID/パスワードによる接続

### 📊 データ処理機能

- **SQL実行**: パラメーター化されたSQLクエリの実行
- **列フィルタリング**: 必要な列のみを抽出（CustomerID, Name, Email, Phone, Address）
- **空データチェック**: データ取得失敗時の適切なエラーハンドリング

### 📁 Excel出力機能

- **自動整形**: 列幅自動調整、先頭行固定、オートフィルター
- **テーブル形式**: Excelテーブルとして出力
- **数値フォーマット**: 文字列として保存（`@`フォーマット）
- **ファイル管理**: 既存ファイルの上書き確認ダイアログ

## 前提条件

### 必須要件

- **Windows 10/11**: Windows環境
- **PowerShell 5.1** 以降（またはPowerShell 7.x）
- **SQL Server**: アクセス可能なSQL Serverインスタンス
- **SqlServer モジュール**: PowerShell Galleryからインストール
- **ImportExcel モジュール**: PowerShell Galleryからインストール

### モジュールのインストール

```powershell
# SqlServerモジュールのインストール（管理者権限で実行）
Install-Module -Name SqlServer -Scope CurrentUser

# ImportExcelモジュールのインストール
Install-Module -Name ImportExcel -Scope CurrentUser
```

### 暗号化ファイルの準備

スクリプト実行には以下のファイルが必要です：

1. **暗号化鍵ファイル**: `Common\Encryption.Key`
2. **暗号化パスワードファイル**: `mssql2022-dev-db.pass`

これらのファイルは、別途提供される暗号化ツールで作成してください。

## ディレクトリ構造

```Shell
PowerShell/
├── Common/
│   └── Encryption.Key              # 暗号化鍵ファイル
└── Excelの操作/
    ├── mssql2022-dev-db.pass       # 暗号化パスワードファイル
    ├── Excel/
    │   └── ExptExcel.xlsx          # 出力Excelファイル（自動生成）
    └── ExportExcel/
        ├── ExptExcel.ps1           # メインスクリプト
        └── Readme.md               # このファイル
```

## 使い方

### 基本的な使用方法

1. **接続情報の設定**

スクリプト内の接続パラメーターを環境に合わせて編集：

```powershell
# パラメータの定義
[string]$serverName = "127.0.0.1,11433"   # サーバー名またはIPアドレス、ポート番号
[string]$databaseName = "appdb"          # データベース名
[string]$userId = "sa"                   # ユーザーID
[string]$TableName = "Customers"         # テーブル名
```

2. **スクリプトの実行**

```powershell
# スクリプトのあるディレクトリに移動
Set-Location "$HOME\GitHub\PowerShell\Excelの操作\ExportExcel"

# スクリプト実行
.\ExptExcel.ps1
```

### 実行結果

スクリプトは以下の処理を順番に実行します：

1. ✅ 必要なモジュールの確認
2. ✅ モジュールのインポート
3. ✅ 暗号化鍵の読み込み
4. ✅ パスワードの復号化
5. ✅ 出力ファイルの存在確認と削除確認
6. ✅ SQL実行とデータ取得
7. ✅ データ検証（空データチェック）
8. ✅ Excelファイル作成と保存
9. ✅ Excelファイルを自動的に開く

```Terminal
Excelファイルを出力しました。
処理が完了しました。
```

## スクリプト詳細

### SQL文のカスタマイズ

スクリプト内のSQL文は以下のように定義されています：

```powershell
[string]$sql = "SELECT CustomerID, Name, Email, Phone, Address FROM [$databaseName].dbo.[$TableName] ;"
```

**カスタマイズ例**:

```powershell
# 条件を追加する場合
$sql = "SELECT CustomerID, Name, Email FROM [$databaseName].dbo.[$TableName] WHERE CustomerID > 100 ;"

# JOIN を使用する場合
$sql = "SELECT c.CustomerID, c.Name, o.OrderDate FROM [$databaseName].dbo.Customers c INNER JOIN [$databaseName].dbo.Orders o ON c.CustomerID = o.CustomerID ;"
```

### Excel出力オプション

Export-Excelのオプション：

| オプション | 説明 |
|-----------|------|
| `-AutoSize` | 列幅を自動調整 |
| `-AutoFilter` | オートフィルターを有効化 |
| `-FreezeTopRow` | 先頭行を固定 |
| `-BoldTopRow` | 先頭行を太字に |
| `-TableName` | Excelテーブル名を指定 |
| `-NumberFormat '@'` | 全セルを文字列フォーマットに |

## トラブルシューティング

### よくある問題と解決方法

#### 1. 「SqlServerモジュールがインストールされていません」エラー

```Terminal
SqlServerモジュールがインストールされていません。処理を終了します。
```

**解決方法**:

```powershell
Install-Module -Name SqlServer -Scope CurrentUser
```

#### 2. 「ImportExcelモジュールがインストールされていません」エラー

```Terminal
ImportExcelモジュールがインストールされていません。処理を終了します。
```

**解決方法**:

```powershell
Install-Module -Name ImportExcel -Scope CurrentUser
```

#### 3. 鍵ファイルが見つからないエラー

```Terminal
鍵の読み込みに失敗しました。
```

**解決方法**:

- `Common\Encryption.Key`ファイルが存在するか確認
- ファイルパスが正しいか確認
- 暗号化鍵作成スクリプトで鍵ファイルを生成

#### 4. パスワード復号化エラー

```Terminal
パスワードの復号化に失敗しました。
```

**解決方法**:

- `mssql2022-dev-db.pass`ファイルが存在するか確認
- 正しい鍵ファイルを使用しているか確認
- パスワードファイルを再作成

#### 5. SQL実行エラー

```Terminal
SQLの実行に失敗しました。
```

**解決方法**:

- SQL Serverが起動しているか確認
- 接続情報（サーバー名、ポート、データベース名）が正しいか確認
- ユーザーIDとパスワードが正しいか確認
- ファイアウォール設定を確認
- テーブルが存在するか確認

#### 6. ファイルロックエラー

```Terminal
ファイルの削除に失敗しました。ファイルが開かれている可能性があります。
```

**解決方法**:

- 既存の`ExptExcel.xlsx`を閉じる
- Excelプロセスをタスクマネージャーで終了
- ファイルを別の場所に移動してから再実行

#### 7. データが取得できない

```Terminal
データが取得できませんでした。
```

**解決方法**:

- テーブルにデータが存在するか確認
- SQL文の構文が正しいか確認
- テーブル名とデータベース名が正しいか確認
- ユーザーにテーブルへのアクセス権限があるか確認

## 高度な使用例

### 例1: 異なるテーブルを出力

```powershell
# スクリプト内のパラメータを変更
[string]$TableName = "Orders"
[string]$sql = "SELECT OrderID, OrderDate, TotalAmount FROM [$databaseName].dbo.[$TableName] ;"
```

### 例2: 複数テーブルをJOINして出力

```powershell
[string]$sql = @"
SELECT 
    c.CustomerID, 
    c.Name, 
    o.OrderID, 
    o.OrderDate
FROM [$databaseName].dbo.Customers c
LEFT JOIN [$databaseName].dbo.Orders o ON c.CustomerID = o.CustomerID
"@
```

### 例3: 条件付きデータ抽出

```powershell
[string]$sql = @"
SELECT CustomerID, Name, Email, Phone, Address 
FROM [$databaseName].dbo.[$TableName] 
WHERE Email IS NOT NULL 
  AND Phone LIKE '03%'
ORDER BY CustomerID DESC
"@
```

### 例4: 出力ファイル名をカスタマイズ

```powershell
# 現在日時を含むファイル名
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
[string]$outputPath = Join-Path $UpperDir "Excel" | Join-Path -ChildPath "ExptExcel_$timestamp.xlsx"
```

## セキュリティに関する注意事項

### ⚠️ 重要な注意点

1. **暗号化ファイルの管理**: 
   - `Encryption.Key`と`.pass`ファイルは厳重に管理してください
   - バージョン管理システム（Git等）にコミットしないでください
   - `.gitignore`に追加することを推奨

2. **パスワードの取り扱い**:
   - スクリプトは一時的にパスワードを平文に変換します（Invoke-Sqlcmdの制約）
   - 実行後は自動的にメモリから削除されます

3. **アクセス権限**:
   - データベースユーザーには最小限の権限のみを付与
   - 読み取り専用権限の使用を推奨

4. **ネットワークセキュリティ**:
   - 本番環境では暗号化接続（SSL/TLS）の使用を推奨
   - `-TrustServerCertificate`オプションの使用は開発環境のみに制限

## 終了コード

- **0**: 正常終了
- **1**: エラー終了（モジュール不足、ファイル未検出、SQL実行エラー等）

## 参考情報

- [SqlServer モジュール](https://docs.microsoft.com/powershell/module/sqlserver/)
- [ImportExcel モジュール](https://github.com/dfinke/ImportExcel)
- [Invoke-Sqlcmd](https://docs.microsoft.com/powershell/module/sqlserver/invoke-sqlcmd)
- [Export-Excel](https://github.com/dfinke/ImportExcel#export-excel)

## バージョン履歴

### v2.0.0 (2026-01-05)

- スクリプト構造の大幅改善（begin-process-end削除）
- モジュール確認関数の導入
- パス結合を`Join-Path`に統一
- COMオブジェクト完全解放
- エラーハンドリング強化（try-catch-finally）
- SQL文のパラメーター化
- 列フィルタリングをSQL側で実施（パフォーマンス向上）
- 空データチェック追加
- ファイルロックエラー対応
- インデント統一とコード整理
- 変数削除時のエラー抑制追加

### v1.0.0 (初期リリース)

- 基本的なSQL実行とExcel出力機能
- 暗号化パスワード対応
- ファイル上書き確認ダイアログ
