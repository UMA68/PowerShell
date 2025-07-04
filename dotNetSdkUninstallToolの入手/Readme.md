# 「DotNetSdk_UninstallTool導入.ps1 - ショートカット」でエラーとなる場合

**その場合、手動インストールするしかない**

🔄 代替手段：GitHubからMSIを取得して手動インストール
以下の手順で導入できます：

`dotNetSdkUninstallTool`フォルダに`dotnet-core-uninstall.msi`が入っています。それを管**理者権限**でインストールしても良いです。

ダウンロードするなら

GitHub公式ページへアクセス
👉 [https://github.com/dotnet/cli-lab/releases](https://github.com/dotnet/cli-lab/releases)


最新の .msi ファイル（例：dotnet-core-uninstall-1.7.521001.msi）をダウンロード

ダウンロードした .msi を**管理者権限**で実行してインストール

インストール後、以下のコマンドで確認：

```PowerShell
dotnet-core-uninstall list
```


