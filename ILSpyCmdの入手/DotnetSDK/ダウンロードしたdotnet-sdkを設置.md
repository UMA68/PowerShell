# .NET SDK 8.0.411 のセットアップ

## 概要

このフォルダーには、`.NET SDK 8.0.411` のインストーラーを配置します。`getILSpyCmd.ps1` スクリプトは、このインストーラーを使用して .NET SDKをインストールします。
別途、ダウンロードしたインストーラー `dotnet-sdk-8.0.411-win-x64.exe` を配置してください。

## ファイルの配置

1. [Microsoft .NET ダウンロードページ](https://dotnet.microsoft.com/download/dotnet)から `dotnet-sdk-8.0.411-win-x64.exe` をダウンロード
2. ダウンロードしたファイルをこのフォルダー（`ILSpyCmdの入手/DotnetSDK/`）に配置
3. `getILSpyCmd.ps1` スクリプトを実行すると、配置されたインストーラーを検出して使用します

## 注意事項

- ファイル名は正確に `dotnet-sdk-8.0.411-win-x64.exe` である必要があります
- 他のバージョンのSDKは推奨しませんが、`getILSpyCmd.Yaml` の `DotnetSdk.Version` を変更すれば可能です

  ```yaml
    DotnetSdk:
        Installer: "dotnet-sdk-8.0.411-win-x64.exe"
        Version: "8.0.411"
  ```

## .NET SDK の複数バージョン共存について

- .NET SDKは複数バージョンの同時インストールに対応しています
- 既存の .NET SDKはそのまま残して問題ありません
- `dotnet --list-sdks` コマンドでインストール済みのバージョンを確認できます
- 特定バージョンのSDKが不要な場合のみ、アンインストールを検討してください

**アンインストールが必要なケース**:

- ディスク容量が不足している場合
- 特定のバージョンで問題が発生している場合

## 参考資料

- [Microsoft .NET ダウンロードページ](https://dotnet.microsoft.com/download/dotnet)
- [PowerShell 公式ドキュメント](https://learn.microsoft.com/ja-jp/powershell/)
- [powershell-yaml モジュール](https://github.com/cloudbase/powershell-yaml)
- [ILSpyCmd 公式ドキュメント](https://github.com/icsharpcode/ILSpy)
- [ILSpyCmdの実装レポート](../ILSpyCmdの入手/IMPLEMENTATION_REPORT_v1.3.0.md)
- [ILSpyCmdの改善履歴](../ILSpyCmdの入手/IMPROVEMENTS_v1.4.0.md)
- [dotnet-sdk-uninstall スクリプト](../../DotnetSdk削除/Readme.md)