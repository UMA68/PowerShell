
# 暗号化文字列の作成スクリプト ReadMe

このスクリプトは、入力した文字列を指定した鍵ファイル（既定：Common\Encryption.key）で暗号化し、暗号化文字列をファイルとして出力します。パスワードなど平文で保存したくない情報の管理に便利です。

---

## 使い方

1. PowerShellで本スクリプトを実行します。

```powershell
./Script/MakeEncryptedString.ps1
```

2. プロンプトにしたがって暗号化したい文字列を入力します。
3. 出力するファイル名を入力します（このReadMeと同じディレクトリに保存されます）。
4. 暗号化文字列がコンソールに表示され、指定ファイルに保存されます。

### サンプル入出力例

```powershell
./Script/MakeEncryptedString.ps1
```

```text
暗号化する文字列を入力してください: mySecretPassword
出力するファイル名を入力してください: secret.txt
暗号化した文字列: <暗号化済み文字列>
暗号化した文字列をファイル「secret.txt」に出力しました。
```

### 鍵ファイルの指定

デフォルトは`Common/Encryption.key`です。別の鍵ファイルを使いたい場合は、
`-keyFileName`パラメーターでファイル名を指定し、Commonフォルダーに配置してください。

```powershell
./Script/MakeEncryptedString.ps1 -keyFileName MyKey.bin
```

---

## 注意事項

- ファイル名や鍵ファイル名にパス区切り文字（/、\、:）は使えません。
- 鍵ファイルが存在しない場合はエラーとなります（「Common」フォルダーに配置してください）。
- 暗号化文字列の復号には [`暗号化文字列の復元/Script/StringDecryption.ps1`](../暗号化文字列の復元/Script/StringDecryption.ps1) を利用してください。
- 鍵ファイルの作成は [`暗号化鍵の作成/Script/MakeEncrypted.ps1`](../暗号化鍵の作成/Script/MakeEncrypted.ps1) で行えます。
- 鍵ファイルや暗号化ファイルは厳重に管理し、第三者に漏洩しないようご注意ください。

---
Author: UMA68  
Version: 1.1.0  
最終更新: 2025-12-09
