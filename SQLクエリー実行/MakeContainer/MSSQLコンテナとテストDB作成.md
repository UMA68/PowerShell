# MSSQL コンテナーとテストDB作成ガイド

## 目的

このドキュメントは、Podmanを使用してMSQL Server 2022コンテナーを作成し、テスト用データベース（appdb）をセットアップするための手順を説明しています。

**前提条件：**

- PowerShell 7.3以上
- Podman / Dockerがインストール済み
- docker-compose.ymlファイルが同じフォルダーに存在すること
- init_customer_orders.sqlファイルが同じフォルダーに存在すること

※ 本手順で使用するSAパスワード **Str0ngP@ssw0rd2025!** は、
本番利用を想定しないローカル検証用のサンプル値です。

**準備：**
PowerShellに設定したWindowsTerminal等で、このフォルダーをカレントにしてください（フォルダーを開いてください）。

---

## コンテナーの作成

### コンテナーの削除

すでに`mssql2022`コンテナーが存在する場合は、以下のコマンドで削除してください。

⚠️ **注意：DBのデータも一緒に消えます**

```PowerShell
# 再起動
podman restart mssql2022

# 停止
podman stop mssql2022

# 削除（停止後）
podman rm mssql2022
```

### コンテナーの作成/起動

`docker-compose.yml`の内容にしたがって、コンテナーが作成＆起動されます。

```PowerShell
# 起動
podman-compose up -d
```

---

## テストDBの作成

以下の手順を実行すると、コンテナー内に`appdb`データベースが作成されます。

### ステップ1: 初期化スクリプトをコンテナーへコピー

```PowerShell
podman cp .\init_customer_orders.sql mssql2022:/init_customer_orders.sql
```

### ステップ2: DB初期化スクリプトを実行

```PowerShell
podman exec mssql2022 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Str0ngP@ssw0rd2025!" -C -i /init_customer_orders.sql
```

### データ永続化について

コンテナーを**停止**しても、作成したDBやデータは消えません。  
コンテナーを**削除**すると、作成したDBやデータが「**消えます**」のでご注意ください。

⚠️ **注意：** 現在、コンテナー外部に保存する永続化は実施しておりません

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

### ❌ コンテナーが起動しない

**原因：** ポート11433がすでに使用されている可能性があります

**対応：**

```PowerShell
# 使用中のプロセスを確認
netstat -ano | findstr :11433

# または docker-compose.yml でポートを変更してください
```

### ❌ sqlcmd コマンド実行時に "Login failed" エラー

**原因：** コンテナー起動直後はSQL Serverの初期化に時間がかかります

**対応：**

```PowerShell
# コンテナ起動から30秒～1分程度待機してから実行してください
Start-Sleep -Seconds 30
```

### ❌ init_customer_orders.sql 実行時にエラー

**確認事項：**

- ファイルがUTF-8 (CRLF) エンコーディングであるか確認
- SQL Serverバージョンが2022以上か確認
- collationが `Japanese_90_CI_AS_SC_UTF8` に対応しているか確認

### ❌ appdb が作成されたが、テーブルが見つからない

**対応：** init_customer_orders.sqlの実行が失敗している可能性があります

```PowerShell
# コンテナログを確認
podman logs mssql2022
```

---

## ファイル構成

```Shell
MakeContainer/
├── MSSQLコンテナとテストDB作成.md          ← このファイル
├── docker-compose.yml                  ← コンテナ設定
└── init_customer_orders.sql            ← DB初期化スクリプト
```

---

## 関連スクリプト

本セットアップ後、以下の親フォルダーのスクリプトが使用可能になります：

- **sqlMain.ps1** - SQLファイルを一括実行するメインスクリプト
  - 利用方法：`SQLクエリー実行/README.md` を参照
