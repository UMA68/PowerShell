<#
.SYNOPSIS
    鍵ファイルを使用して文字列を暗号化し、ファイルへ出力します。

.DESCRIPTION
    指定された鍵ファイル（既定: Encryption.key）を使用して、入力された文字列を
    ConvertFrom-SecureString で暗号化し、ターミナル表示とファイル出力を行います。
    
    主な機能：
    - 鍵ファイルを使用した安全な暗号化処理
    - 入力文字列とファイル名のバリデーション
    - 二重起動防止機構
    - 処理後の変数クリーンアップ
    
    出力ファイルは本スクリプトの1階層上に、指定したファイル名で保存します。

.PARAMETER keyFileName
    使用する鍵ファイル名（Common フォルダー配下）。デフォルトは Encryption.key。

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    暗号化文字列（標準出力および指定ファイル）

.EXAMPLE
    .\MakeEncryptedString.ps1
    
    既定の鍵ファイル（Encryption.key）で暗号化し、指定したファイル名で保存します。
    1. 鍵ファイルを読み込みます
    2. 暗号化する文字列の入力を求められます
    3. 入力文字列を SecureString に変換し暗号化します
    4. 暗号化文字列をターミナルに表示します
    5. 出力ファイル名の入力を求められます
    6. 指定ファイル名でスクリプト親ディレクトリに保存します
    7. 変数をクリーンアップします

.EXAMPLE
    .\MakeEncryptedString.ps1 -keyFileName "MyKey.bin"
    
    カスタム鍵ファイル（MyKey.bin）を用いて暗号化します。

.NOTES
    FileName:     MakeEncryptedString.ps1
    Author:       UMA68
    Version:      1.0.0
    LastModified: 2026-01-20
    Prerequisites:
      - PowerShell 5.1 以上
      - Common\<鍵ファイル> が存在すること
      - Common\NoDoubleActivation.ps1 が存在すること
    
    セキュリティに関する注意:
    - 入力文字列は SecureString として処理されます
    - 処理後、変数は Remove-Variable で削除されます
    - 鍵ファイルは厳重に管理してください
    - 暗号化文字列はターミナルに表示されるため、作業時は周囲に注意してください
    
    使い方:
    1. 鍵ファイル「Encryption.key」を「Common」フォルダに置く
    2. 「暗号化文字列の作成.ps1 - ショートカット」をダブルクリックする
    3. 暗号化する文字列を入力する
    4. 出力するファイル名を入力する
    5. ファイルはスクリプトの1階層上のディレクトリに保存されます

.LINK
    関連スクリプト: 鍵ファイル作成.ps1（鍵ファイル作成）
    関連スクリプト: StringDecryption.ps1（復号）
    関連スクリプト: NoDoubleActivation.ps1（二重起動防止）
#>

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
        Exit    # おわり
    }

# 二重起動の禁止
Check-NoDoubleActivation -Thread "MakeEncryptedString" # スレッド名は拡張子無しのスクリプトファイル名を指定

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
