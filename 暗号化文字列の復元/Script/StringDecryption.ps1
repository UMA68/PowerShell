# ================================
# 鍵ファイルEncryption.keyを使って
# 暗号化した文字列を復号する
# ================================
# 使い方
# ----------------
# 1. 鍵ファイル「Encryption.key」を「Common」フォルダに置く
# 2. 「暗号文字列の復号.ps1 - ショートカット」をダブルクリックする
# 3. 復号する文字列を入力する
# ----------------
param (
    [string]$keyFileName = "Encryption.key" # オプションなしの場合は「Encryption.key」を使用する
)

# スクリプトのディレクトリ取得
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ
$UpperDir = $ScriptDir | Split-Path -Parent                     # スクリプトの親ディレクトリ
$PowerShellDir = $UpperDir | Split-Path -Parent                 # PowerShellディレクトリ
$comPath = "$PowerShellDir\Common"                              # 共通スクリプト格納ディレクトリ
$keyPath = "$comPath\$keyFileName"                              # 鍵ファイルのパス

# .ps1ファイルの読み込み
try{
    . "$ScriptDir\InputGUI.ps1" -ErrorAction Stop
    . "$comPath\NoDoubleActivation.ps1" -ErrorAction Stop
}catch{
    # エラーメッセージを表示して終了
    Write-Host $_.Exception.Message -ForegroundColor Red
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup($_.Exception.Message + "「"+$ScriptDir+"」に「InputGUI.ps1」が見つかりません。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
    exit
}

# 二重起動の禁止
Test-NoDoubleActivation -Thread "StringDecryption" # スレッド名は拡張子無しのスクリプトファイル名を指定

# 暗号化の際に使用する鍵ファイルを読み込む
# Encryption.keyの存在確認
try {
    if (Test-Path -Path $keyPath) {
        # 鍵ファイルを読み込む
        [byte[]]$EncryptedKey =[System.IO.File]::ReadAllBytes($keyPath)
        Write-Host "鍵ファイル「Encryption.key」を読み込みました。"
    } else {
        throw "鍵ファイル「Encryption.key」が見つかりません。"  # 例外を発生させる
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup($_.Exception.Message + "作成したEncryption.keyを 「"+$UpperDir+"」 へ置いてください。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
    exit
}

# フォームを表示
[void]$form.ShowDialog()
$InputString = $textBox.Text    # 入力された文字列取得

# 復号処理
try{
    # 暗号化した文字列を復号
    $SecureDecryptedString = $InputString | ConvertTo-SecureString -Key $EncryptedKey -ErrorAction Stop
    # 復号した文字列を平文に変換（より安全な方法）
    $DecryptedString = [System.Net.NetworkCredential]::new('', $SecureDecryptedString).Password
}catch{
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup($_.Exception.Message + "`r`n`r`n文字列の復号に失敗しました。処理を終了します。", 0, "エラー", 0x10)  # 0x10:エラーアイコン    
    exit
}

# 復号化した文字列を表示
Write-Host "復号結果文字列: $DecryptedString"
$obj = New-Object -ComObject WScript.Shell
$obj.popup("復号に成功しました。 `r`n「"+$DecryptedString+"`」`r`n です。", 0, "情報", 0x40)  # 0x40:情報アイコン

# 変数の削除
Remove-Variable -Name EncryptedKey, InputString, obj, DecryptedString, UpperDir