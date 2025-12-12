# PowerShell

PowerShellのサンプルコード

このリポジトリで公開しているPowerShellのサンプルは、
MIT LICENSEにて公開します。

私用、商用利用について制限はしません。遠慮無く
コードを変更や拡張を行って、私的な作業やお仕事などに利用してください。

## 主なスクリプト

- [.NET Uninstall Tool 管理](dotNetSdkUninstallToolの入手/Readme.md)
  - [English](dotNetSdkUninstallToolの入手/Readme.en.md)
- [暗号化文字列の作成](暗号化文字列の作成/Script/MakeEncryptedString.ps1)
  - Common\Encryption.keyを使って文字列を暗号化し、コンソール表示とファイル保存を行います。
  - 使い方: PowerShellで`./暗号化文字列の作成/Script/MakeEncryptedString.ps1`を実行し、プロンプトにしたがって文字列と出力ファイル名を入力してください。
  - 鍵ファイルを変えたい場合は`-keyFileName MyKey.bin`のように指定し、Commonフォルダーに配置してください。
