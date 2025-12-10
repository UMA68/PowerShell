
# 暗号化鍵の作成スクリプト

このスクリプトは、暗号化・復号化に使用する鍵ファイル（Encryption.Key）を生成します。PowerShellの標準的な暗号化（DPAPI）は実行した端末でしか復号できませんが、共通鍵（AES）を使うことで、鍵ファイルを持つ誰もが暗号化・復号できるようになります。

---

## 使い方

1. PowerShellで本スクリプトを実行します。

 ```powershell
 ./Script/MakeEncrypted.ps1
 ```

 または、用意されているショートカット`鍵ファイル作成.ps1 - ショートカット.lnk`をダブルクリックして実行することもできます。
2. 既存の鍵ファイルがある場合は上書き確認ダイアログが表示されます。
3. 鍵が生成され、CommonフォルダーにEncryption.Keyとして保存されます。

### 鍵のビット長を指定する場合

デフォルトは192ビットですが、128または256ビットも選択可能です。

```powershell
./Script/MakeEncrypted.ps1 -KeySize 256
```

### サンプル実行例

```powershell
./Script/MakeEncrypted.ps1 -KeySize 192
```

```text
鍵生成中（192bit）…
鍵ファイル「Encryption.Key」を生成しました。
機密情報をメモリから削除しました。
```

---

## 注意事項

- 生成される鍵ファイルは、指定したビット長のランダムなバイト配列です（例：192bit = 24バイト）。
- 鍵ファイルはCommonフォルダーに保存されます。
- 既存の鍵ファイルを上書きすると、それまでの暗号化データは復号できなくなります。
- 鍵ファイルは厳重に管理し、第三者に漏洩しないようご注意ください。
- 作成後は読み取り専用に設定することをオススメします（うっかり上書き防止）。
- 暗号化には [`暗号化文字列の作成/Script/MakeEncryptedString.ps1`](../暗号化文字列の作成/Script/MakeEncryptedString.ps1) を利用してください。
- 復号には [`暗号化文字列の復元/Script/StringDecryption.ps1`](../暗号化文字列の復元/Script/StringDecryption.ps1) を利用してください。

---

Author: UMA68  
Version: 1.1.0  
最終更新: 2025-12-10
