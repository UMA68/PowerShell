<#
.SYNOPSIS
    鍵ファイルを使用して文字列を暗号化し、ファイルへ出力します。

.DESCRIPTION
    指定された鍵ファイル（既定: Encryption.key）を使用して、入力された文字列を
    ConvertFrom-SecureString で暗号化し、ターミナル表示とファイル出力を行います。
    二重起動防止・入力バリデーション・機密情報のクリーンアップを行います。
    出力ファイルは本スクリプトの1階層上に、指定したファイル名で保存します。

.PARAMETER keyFileName
    使用する鍵ファイル名（Common フォルダー配下）。デフォルトは Encryption.key。
    パス区切り文字（\ / :）を含めることはできません。

.INPUTS
    None

.OUTPUTS
    暗号化文字列（標準出力および指定ファイル）

.EXAMPLE
    .\MakeEncryptedString.ps1
    既定の鍵ファイルで暗号化し、指定したファイル名で保存します。

.EXAMPLE
    .\MakeEncryptedString.ps1 -keyFileName "MyKey.bin"
    MyKey.bin を用いて暗号化します。

.EXAMPLE
    .\MakeEncryptedString.ps1
    プロンプトに従って暗号化する文字列と出力ファイル名を入力し、PowerShell ディレクトリ直下に保存します。

.NOTES
    FileName:     MakeEncryptedString.ps1
    Author:       UMA68
    Version:      1.1.0
    LastModified: 2025-12-09
    Prerequisites:
      - PowerShell 5.1 以上
      - Common\<鍵ファイル> が存在すること
      - Common\NoDoubleActivation.ps1 が存在すること

.LINK
    関連スクリプト: MakeEncrypted.ps1（鍵ファイル作成）
    関連スクリプト: StringDecryption.ps1（復号）
#>

# ====================================
# パラメーター定義
# ====================================
param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]  # 鍵ファイル名の必須チェック
    [ValidateScript({           # パス区切り文字のチェック
        if ($_ -match "[\\/:]") { # パス区切り文字のチェック
            throw "鍵ファイル名にパス区切り文字を含めることはできません。ファイル名のみを指定してください。"
        }
        $true
    })]
    [string]$keyFileName = "Encryption.key" # オプションなしの場合は「Encryption.key」を使用する
)

# ====================================
# パス初期化・共通スクリプト読込
# ====================================
# スクリプトのディレクトリ取得
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ
$UpperDir = Split-Path -Parent $ScriptDir                       # スクリプトの親ディレクトリ
$PowerShellDir = Split-Path -Parent $UpperDir                   # PowerShellディレクトリ
$comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"   # 共通スクリプト格納ディレクトリ
$keyPath = Join-Path -Path $comPath -ChildPath $keyFileName     # 鍵ファイルのパス
$noDoubleActivationPath = Join-Path -Path $comPath -ChildPath "NoDoubleActivation.ps1"

try {
    if (-not (Test-Path $noDoubleActivationPath)) { # NoDoubleActivation.ps1の存在確認
        throw "NoDoubleActivation.ps1 が見つかりません: $noDoubleActivationPath"
    }
    . $noDoubleActivationPath -ErrorAction Stop
} catch {
    $obj = New-Object -ComObject WScript.Shell
    $obj.Popup("共通スクリプトの読み込みに失敗しました。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# 二重起動の禁止
Test-NoDoubleActivation -Thread "MakeEncryptedString" # スレッド名は拡張子無しのスクリプトファイル名を指定

# ====================================
# 鍵ファイルの読み込み
# ====================================
try {
    if (Test-Path -Path $keyPath) { # 鍵ファイルが存在する場合
        [byte[]]$EncryptionKey = [System.IO.File]::ReadAllBytes($keyPath)
        Write-Host "鍵ファイル「$keyFileName」を読み込みました。" -ForegroundColor Green
    } else { # 鍵ファイルが存在しない場合
        throw "鍵ファイル「$keyFileName」が見つかりません: $keyPath"
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup($_.Exception.Message + "`r`n`r`n作成した鍵ファイルを「$comPath」に配置してください。", 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# ====================================
# 入力受付とバリデーション
# ====================================
$InputString = Read-Host -Prompt "暗号化する文字列を入力してください"   # 暗号化する文字列を入力

if ([string]::IsNullOrWhiteSpace($InputString)) { # 入力が空の場合
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("暗号化する文字列が入力されていません。処理を終了します。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# 暗号化する文字列を表示（セキュリティのためコメントアウト）
# Write-Host "暗号化する文字列: $InputString"

# プレーンテキストをSecureStringに変換
$SecureString = ConvertTo-SecureString -String $InputString -AsPlainText -Force

# SecureStringを暗号化
$EncryptedString = ConvertFrom-SecureString -SecureString $SecureString -Key $EncryptionKey

# 暗号化した文字列を表示
Write-Host "暗号化した文字列: $EncryptedString" -ForegroundColor Cyan

# ====================================
# 出力ファイル名入力とバリデーション
# ====================================
$FileName = Read-Host -Prompt "出力するファイル名を入力してください"   # ファイル名を入力する

if ([string]::IsNullOrWhiteSpace($FileName)) { # ファイル名が空の場合
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("ファイル名が入力されていません。処理を終了します。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# 無効文字とパス区切りのチェック
$invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
if ($FileName.IndexOfAny($invalidChars) -ge 0 -or $FileName -match "[\\/:]") { # 無効文字またはパス区切り文字が含まれている場合
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("ファイル名に使用できない文字が含まれています。別の名前を指定してください。", 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# 出力パス決定（同名ファイルの上書き確認は行わない設計）
$OutputPath = Join-Path -Path $UpperDir -ChildPath $FileName

# ====================================
# ファイル出力
# ====================================
try {
    $EncryptedString | Out-File -FilePath $OutputPath -Encoding utf8 -ErrorAction Stop
    
    Write-Host "暗号化した文字列をファイルに出力しました: $OutputPath" -ForegroundColor Green
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("暗号化した文字列をファイル「$FileName」に出力しました。", 0, "文字列暗号化", 0x40)  # 0x40:情報アイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    $obj = $null
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("ファイルへの書き込みに失敗しました。`r`n`r`n"+$_.Exception.Message, 0, "エラー", 0x10)  # 0x10:エラーアイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# ====================================
# セキュリティクリーンアップ
# ====================================
try {
    if ($null -ne $EncryptionKey) { [Array]::Clear($EncryptionKey, 0, $EncryptionKey.Length) }
    if ($null -ne $SecureString) { $SecureString.Dispose() }
    Clear-Variable -Name EncryptionKey, InputString, SecureString, EncryptedString, FileName, OutputPath -ErrorAction SilentlyContinue
    if ($null -ne $obj) { # COMオブジェクトが存在する場合
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        $obj = $null
        Clear-Variable -Name obj -ErrorAction SilentlyContinue
    }
    [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers()
    Write-Host "機密情報をメモリから削除しました。" -ForegroundColor Cyan
} catch {
    Write-Host "クリーンアップ中に警告: $($_.Exception.Message)" -ForegroundColor Yellow
}
#  何かキーが押されるまで待機
Write-Host "終了するには何かキーを押してください..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
