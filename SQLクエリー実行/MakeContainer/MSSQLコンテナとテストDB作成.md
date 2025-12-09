# MSSQL コンテナとテストDB作成ガイド

## 目的

このドキュメントは、Podmanを使用してMSQL Server 2022コンテナを作成し、テスト用データベース（appdb）をセットアップするための手順を説明しています。

**前提条件：**
- PowerShell 7.3以上
- Podman / Docker がインストール済み
- docker-compose.yml ファイルが同じフォルダに存在すること
- init_customer_orders.sql ファイルが同じフォルダに存在すること

**準備：**
PowerShellに設定したWindowsTerminal等で、このフォルダをカレントにしてください(フォルダを開いてください)。

---
## コンテナの作成

### コンテナの削除

すでに`mssql2022`コンテナが存在する場合は、以下のコマンドで削除してください。

⚠️ **注意：DBのデータも一緒に消えます**

```PowerShell
# 再起動
podman restart mssql2022

# 停止
podman stop mssql2022

# 削除（停止後）
podman rm mssql2022
```

### コンテナの作成/起動

`docker-compose.yml`の内容に従って、コンテナが作成＆起動されます。

```PowerShell
# 起動
podman-compose up -d
```

---
## テストDBの作成

以下の手順を実行すると、コンテナ内に`appdb`データベースが作成されます。

### ステップ1: 初期化スクリプトをコンテナへコピー

```PowerShell
podman cp .\init_customer_orders.sql mssql2022:/init_customer_orders.sql
```

### ステップ2: DB初期化スクリプトを実行

```PowerShell
podman exec mssql2022 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Str0ngP@ssw0rd2025!" -C -i /init_customer_orders.sql
```

### データ永続化について

コンテナを**停止**しても、作成したDBやデータは消えません。  
コンテナを**削除**すると、作成したDBやデータが「**消えます**」のでご注意ください。

⚠️ **注意：** 現在、コンテナ外部に保存する永続化は実施しておりません

---
## DB作成の確認

DB作成が成功したかを確認するには、以下のコマンドを実行してください。

### データベース一覧の確認

```PowerShell
podman exec mssql2022 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Str0ngP@ssw0rd2025!" -C -Q "SELECT name FROM sys.databases"
```

`appdb` が表示されれば、データベース作成は成功です。

### テーブル一覧の確認

```PowerShell
podman exec mssql2022 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Str0ngP@ssw0rd2025!" -C -d appdb -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES"
```

`Customers` と `Orders` テーブルが表示されれば、テーブル作成も成功です。

---
## トラブルシューティング

### ❌ コンテナが起動しない

**原因：** ポート11433が既に使用されている可能性があります

**対応：**
```PowerShell
# 使用中のプロセスを確認
netstat -ano | findstr :11433

# または docker-compose.yml でポートを変更してください
```

### ❌ sqlcmd コマンド実行時に "Login failed" エラー

**原因：** コンテナ起動直後は SQL Server の初期化に時間がかかります

**対応：**
```PowerShell
# コンテナ起動から30秒～1分程度待機してから実行してください
Start-Sleep -Seconds 30
```

### ❌ init_customer_orders.sql 実行時にエラー

**確認事項：**
- ファイルが UTF-8 (CRLF) エンコーディングであるか確認
- SQL Server バージョンが2022以上か確認
- collation が `Japanese_90_CI_AS_SC_UTF8` に対応しているか確認

### ❌ appdb が作成されたが、テーブルが見つからない

**対応：** init_customer_orders.sql の実行が失敗している可能性があります

```PowerShell
# コンテナログを確認
podman logs mssql2022
```

---
## ファイル構成

```
MakeContainer/
├── MSSQLコンテナとテストDB作成.md          ← このファイル
├── docker-compose.yml                  ← コンテナ設定
└── init_customer_orders.sql            ← DB初期化スクリプト
```

---
## 関連スクリプト

本セットアップ後、以下の親フォルダのスクリプトが使用可能になります：

- **sqlMain.ps1** - SQL ファイルを一括実行するメインスクリプト
  - 利用方法：`SQLクエリー実行/README.md` を参照