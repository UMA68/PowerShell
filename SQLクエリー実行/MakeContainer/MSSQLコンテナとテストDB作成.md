PowerShellに設定したWindowsTerminal等で、
このフォルダをカレントにしてください(フォルダを開いてください)。

---
## コンテナの作成

### コンテナの削除

すでに`mssql2022`コンテナが存在する場合は、以下のコマンドで
削除してください。
※注意：DBのデータも一緒に消えます

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
## テストDBの削除

以下を実行すると、コンテナ内に`appdb`が作成されます。

1. コンテナへコピー
```PowerShell
podman cp .\init_customer_orders.sql mssql2022:/init_customer_orders.sql
```
1. 一括実行
```PowerShell
podman exec mssql2022 /opt/mssql-tools18/bin/sqlcmd `
  -S localhost -U sa -P "Str0ngP@ssw0rd2025!" -C `
  -i /init_customer_orders.sql
  ```
  
  
コンテナを**停止**しても、作成したDBやデータは消えません。  
コンテナを**削除**すると、作成したDBやデータが「**消えます**」のでご注意ください。

(つまり、コンテナ外部に保存する永続化を実施しておりません)