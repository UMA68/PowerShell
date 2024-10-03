# ===================================
# 192bitの暗号化・復号化用の鍵ファイル
# Encryption.Keyを作成する
# ===================================
# スクリプトのディレクトリ取得
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UpperDir = $ScriptDir | Split-Path -Parent

"鍵生成中…" | Out-Host

$EncryptionKey = New-Object Byte[] 24 # 192bit(24byte)の鍵を生成
# 乱数を生成して鍵を埋める
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptionKey)

# 鍵をファイルに書き出す
# $EncryptionKey | Set-Content "$UpperDir\Encryption.Key" -Encoding utf8      # テキストで書き出す場合
[System.IO.File]::WriteAllBytes("$UpperDir\Encryption.Key", $EncryptionKey) # バイナリで書き出す場合

$obj = New-Object -ComObject WScript.Shell
$obj.popup("鍵生成完了" ,0, "鍵生成", 0x40) # OKボタンのみ表示(0x40)

# 変数の削除
Remove-Variable -Name EncryptionKey, ScriptDir, UpperDir
