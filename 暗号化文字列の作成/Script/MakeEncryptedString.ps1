# ================================
# 鍵ファイルEncryption.keyを使って
# 暗号化した文字列を生成する
# ================================
# 使い方
# ----------------
# 1. 鍵ファイル「Encryption.key」を「Common」フォルダに置く
# 2. 「鍵ファイル作成.ps1 - ショートカット」をダブルクリックする
# 3. 暗号化する文字列を入力する
# 4. 出力するファイルファイル名を入力する
# ----------------
param (
    [string]$keyFileName = "Encryption.key" # オプションなしの場合は「Encryption.key」を使用する
)

# スクリプトのディレクトリ取得
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ
$UpperDir = $ScriptDir | Split-Path -Parent                     # スクリプトの親ディレクトリ
$PowerShellDir = $UpperDir | Split-Path -Parent                 # PowerShellディレクトリ
$comPath = $PowerShellDir+"\Common"                             # 共通スクリプト格納ディレクトリ
$keyPath = "$comPath\$keyFileName"                              # 鍵ファイルのパス

# .ps1ファイル読み込み
    try {
        . $comPath"\NoDoubleActivation.ps1" -ErrorAction Stop
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $scriptName = $_.InvocationInfo.MyCommand.Name
        $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        exit    # おわり
    }

# 二重起動の禁止
Test-NoDoubleActivation -Thread "MakeEncryptedString" # スレッド名は拡張子無しのスクリプトファイル名を指定

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
    $obj.popup($_.Exception.Message + "作成したEncryption.keyを 「"+$comPath+"」 へ置いてください。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
    exit
}

# 暗号化する文字列を入力
$InputString = Read-Host -Prompt "暗号化する文字列を入力してください"   # 暗号化する文字列を入力

# 暗号化する文字列を表示
Write-Host "暗号化する文字列: $InputString"

# プレーンテキストをSecureStringに変換
$SecureString = ConvertTo-SecureString -String $InputString -AsPlainText -Force

# SecureStringを暗号化
$EncryptedString = ConvertFrom-SecureString -SecureString $SecureString -Key $EncryptedKey

# 暗号化した文字列を表示
Write-Host "暗号化した文字列: $EncryptedString"

# 暗号化した文字列をファイルに出力
# ファイル名を入力する
$FileName = Read-Host -Prompt "出力するファイル名を入力してください"   # ファイル名を入力する

# ファイルに出力
$EncryptedString | Out-File -FilePath "$UpperDir\$FileName" -Encoding utf8

# 暗号化した文字列をファイルに出力した旨を表示
$obj = New-Object -ComObject WScript.Shell
$obj.popup("暗号化した文字列をファイル「"+$FileName+"」に出力しました。", 0, "文字列暗号化", 0x40)  # 0x40:情報アイコン

# 変数の削除
Remove-Variable -Name EncryptedKey, InputString, SecureString, EncryptedString, FileName, obj
