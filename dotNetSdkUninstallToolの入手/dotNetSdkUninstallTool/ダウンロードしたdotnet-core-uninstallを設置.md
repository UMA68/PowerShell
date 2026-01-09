# .NET Uninstall Tool のセットアップ

## 概要

このフォルダーには、`.NET Uninstall Tool` のインストーラー（MSIファイル）を配置します。`DotNetUninstallTool.ps1` スクリプトは、このインストーラーを使用して .NET Uninstall Toolをインストールします。
別途、ダウンロードしたインストーラー `dotnet-core-uninstall.msi` を配置してください。

## ファイルの配置

1. [.NET Uninstall Tool 公式リリースページ](https://github.com/dotnet/cli-lab/releases)から最新の `dotnet-core-uninstall.msi` をダウンロード
2. ダウンロードしたファイルをこのフォルダー（`dotNetSdkUninstallToolの入手/dotNetSdkUninstallTool/`）に配置
3. `DotNetUninstallTool.ps1` スクリプトを実行すると、配置されたインストーラーを検出して使用します

## 注意事項

- ファイル名は正確に `dotnet-core-uninstall.msi` である必要があります
- このツールは管理者権限が必要です
- Windows 10/11で動作します

## .NET Uninstall Tool について

- Microsoft公式の .NET SDK/Runtimeアンインストールツールです
- 不要な .NETバージョンを安全に削除できます
- GUIで削除対象を選択できるため、誤って必要なバージョンを削除するリスクを軽減できます

**使用が推奨されるケース**:

- 複数の .NET SDK/Runtimeが蓄積してディスク容量を圧迫している場合
- 特定のバージョンで問題が発生し、クリーンインストールが必要な場合
- 開発環境をリセットしたい場合

## 参考資料

- [.NET Uninstall Tool GitHub リポジトリ](https://github.com/dotnet/cli-lab)
- [.NET Uninstall Tool 公式ドキュメント](https://docs.microsoft.com/ja-jp/dotnet/core/additional-tools/uninstall-tool)
- [Microsoft .NET ダウンロードページ](https://dotnet.microsoft.com/download/dotnet)
- [dotNetSdkUninstallTool 入手ガイド](../Readme.md)
- [DotnetSdk削除スクリプト](../../DotnetSdk削除/Readme.md)