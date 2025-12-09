<#
.SYNOPSIS
    暗号化された文字列を復号して表示するスクリプト

.DESCRIPTION
    指定された鍵ファイル（Encryption.key）を使用して、暗号化された文字列を復号し、
    元の平文を表示します。GUIフォームから暗号文字列を入力する形式です。
    
    復号結果は以下の2つの方法で表示されます：
    1. ターミナル画面（コピー＆ペースト用）
    2. ポップアップダイアログ
    
    主な機能：
    - 鍵ファイルを使用した安全な復号処理
    - GUIフォームによる入力（Enter/Escapeキー対応）
    - ターミナルへの復号結果表示（コピペ用）
    - 二重起動防止機構
    - 処理後の機密情報自動削除

.PARAMETER keyFileName
    復号に使用する鍵ファイル名。Commonフォルダー内に配置する必要があります。
    デフォルト値: "Encryption.key"
    
    パス区切り文字（\ / :）を含むことはできません。ファイル名のみを指定してください。

.EXAMPLE
    .\StringDecryption.ps1
    
    デフォルトの鍵ファイル（Encryption.key）を使用して復号処理を実行します。
    GUIフォームが表示され、暗号化文字列の入力を求められます。
    復号結果はターミナルとポップアップダイアログで表示されます。

.EXAMPLE
    .\StringDecryption.ps1 -keyFileName "MyCustom.key"
    
    カスタム鍵ファイル（MyCustom.key）を使用して復号処理を実行します。

.INPUTS
    なし。パイプライン入力は受け付けません。

.OUTPUTS
    なし。復号結果はターミナルとポップアップダイアログで表示されます。
    ターミナル表示により、復号結果を簡単にコピー＆ペーストできます。

.NOTES
    FileName:      StringDecryption.ps1
    Author:        UMA68
    Version:       1.1.0
    LastModified:  2025-12-09
    Prerequisites: - PowerShell 5.1以上
                   - 鍵ファイル（Encryption.key）がCommonフォルダーに存在すること
                   - InputGUI.ps1 が同じScriptフォルダーに存在すること
                   - NoDoubleActivation.ps1 がCommonフォルダーに存在すること
    
    セキュリティに関する注意:
    - 復号結果はターミナルとダイアログに表示されるため、作業時は周囲に注意してください
    - 復号後、機密情報は速やかにメモリから削除されます
    - 鍵ファイルは厳重に管理してください
    
    操作方法:
    - GUIフォームでEnterキーを押すと復号を実行します
    - Escapeキーまたはキャンセルボタンで処理を中止できます
    - ターミナルに表示された復号結果を選択してコピーできます

.LINK
    関連スクリプト: MakeEncryptedString.ps1 (文字列の暗号化)
    関連スクリプト: MakeEncrypted.ps1 (鍵ファイルの作成)
    関連スクリプト: InputGUI.ps1 (GUI入力フォーム)
    関連スクリプト: MakeEncrypted.ps1 (鍵ファイルの作成)
#>

param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if ($_ -match '[\\/:]') { # 鍵ファイル名にパス区切り文字が含まれているかチェック
            throw "鍵ファイル名にパス区切り文字を含めることはできません。ファイル名のみを指定してください。"
        }
        $true
    })]
    [string]$keyFileName = "Encryption.key" # オプションなしの場合は「Encryption.key」を使用する
)

# ====================================
# ディレクトリパスの初期化
# ====================================
# スクリプトのディレクトリ取得
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ
$UpperDir = Split-Path -Parent $ScriptDir                       # スクリプトの親ディレクトリ
$PowerShellDir = Split-Path -Parent $UpperDir                   # PowerShellディレクトリ
$comPath = Join-Path $PowerShellDir "Common"                    # 共通スクリプト格納ディレクトリ
$keyPath = Join-Path $comPath $keyFileName                      # 鍵ファイルのパス

# ====================================
# 必要なスクリプトの読み込み
# ====================================
# .ps1ファイルの読み込み
$inputGuiPath = Join-Path $ScriptDir "InputGUI.ps1"
$noDoubleActivationPath = Join-Path $comPath "NoDoubleActivation.ps1"

try {
    if (-not (Test-Path $inputGuiPath)) { # InputGUI.ps1の存在確認
        throw "InputGUI.ps1 が見つかりません: $inputGuiPath"
    }
    . $inputGuiPath -ErrorAction Stop
    
    if (-not (Test-Path $noDoubleActivationPath)) { # NoDoubleActivation.ps1の存在確認
        throw "NoDoubleActivation.ps1 が見つかりません: $noDoubleActivationPath"
    }
    . $noDoubleActivationPath -ErrorAction Stop
} catch {
    # エラーメッセージを表示して終了
    Write-Host $_.Exception.Message -ForegroundColor Red
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup($_.Exception.Message, 0, "エラー", 0x10)  # 0x10:エラーアイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# ====================================
# 二重起動防止
# ====================================
# 二重起動の禁止
Test-NoDoubleActivation -Thread "StringDecryption" # スレッド名は拡張子無しのスクリプトファイル名を指定

# ====================================
# 鍵ファイルの読み込み
# ====================================
# 暗号化の際に使用する鍵ファイルを読み込む
try {
    if (Test-Path -Path $keyPath) { # 鍵ファイルが存在する場合
        # 鍵ファイルを読み込む
        [byte[]]$EncryptedKey = [System.IO.File]::ReadAllBytes($keyPath)
        Write-Host "鍵ファイル「$keyFileName」を読み込みました。" -ForegroundColor Green
    } else { # 鍵ファイルが存在しない場合
        throw "鍵ファイル「$keyFileName」が見つかりません: $keyPath"
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup($_.Exception.Message + "`r`n`r`n作成した鍵ファイルを「$comPath」へ配置してください。", 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    exit
}

# ====================================
# ユーザー入力の取得
# ====================================
# フォームを表示
$dialogResult = $form.ShowDialog()

# ダイアログの結果を確認
if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Cancel) { # ユーザーがキャンセルした場合
    Write-Host "操作がユーザーによってキャンセルされました。処理を終了します。" -ForegroundColor Yellow
    # フォームを破棄
    if ($null -ne $form) { $form.Dispose() }
    exit
}

$InputString = $textBox.Text    # 入力された文字列取得

# 入力検証
if ([string]::IsNullOrWhiteSpace($InputString)) { # 入力が空の場合
    Write-Host "空文字列が入力されました。処理を終了します。" -ForegroundColor Yellow
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("入力が空です。処理を終了します。", 0, "情報", 0x40)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    # フォームを破棄
    if ($null -ne $form) { $form.Dispose() }
    exit
}

# ====================================
# 復号処理
# ====================================
# 復号処理
try {
    # 暗号化した文字列を復号
    $SecureDecryptedString = $InputString | ConvertTo-SecureString -Key $EncryptedKey -ErrorAction Stop
    # 復号した文字列を平文に変換（より安全な方法）
    $DecryptedString = [System.Net.NetworkCredential]::new('', $SecureDecryptedString).Password
    
    Write-Host "復号に成功しました。" -ForegroundColor Green
    Write-Host ""
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "復号結果: " -NoNewline -ForegroundColor Yellow
    Write-Host "$DecryptedString" -ForegroundColor White
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "※ 上記の復号結果をコピーしてご利用ください" -ForegroundColor Gray
} catch {
    Write-Host "文字列の復号に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("文字列の復号に失敗しました。`r`n`r`n原因: $($_.Exception.Message)`r`n`r`n処理を終了します。", 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    
    # エラー時もフォームを破棄
    if ($null -ne $form) { $form.Dispose() }
    if ($null -ne $textBox) { $textBox.Dispose() }
    if ($null -ne $button) { $button.Dispose() }
    
    exit
}

# ====================================
# 結果表示とクリーンアップ
# ====================================
# 復号化した文字列を表示（セキュリティ上、コンソールログには出力しない）
# ポップアップダイアログでのみ表示
$obj = New-Object -ComObject WScript.Shell
$obj.popup("復号に成功しました。`r`n`r`n結果: $DecryptedString`r`n`r`n※この情報は画面キャプチャにご注意ください", 0, "復号成功", 0x40)  # 0x40:情報アイコン

Write-Host "復号処理が完了しました。機密情報をメモリから削除しています..." -ForegroundColor Cyan

# ====================================
# セキュリティクリーンアップ
# ====================================
# セキュリティのため機密情報をメモリから確実に削除
try {
    # 鍵情報の削除
    if ($null -ne $EncryptedKey) { # 鍵情報が存在する場合
        [Array]::Clear($EncryptedKey, 0, $EncryptedKey.Length)
        Clear-Variable -Name EncryptedKey -ErrorAction SilentlyContinue 
    }
    
    # SecureString の破棄
    if ($null -ne $SecureDecryptedString) { #  SecureString が存在する場合
        $SecureDecryptedString.Dispose()
        Clear-Variable -Name SecureDecryptedString -ErrorAction SilentlyContinue 
    }
    
    # 平文パスワードの削除
    if ($null -ne $DecryptedString) { # 平文が存在する場合
        Clear-Variable -Name DecryptedString -ErrorAction SilentlyContinue 
    }
    
    # 入力文字列の削除
    if ($null -ne $InputString) { # 入力文字列が存在する場合
        Clear-Variable -Name InputString -ErrorAction SilentlyContinue 
    }
    
    # COMオブジェクトの解放
    if ($null -ne $obj) { # COMオブジェクトが存在する場合
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
        Clear-Variable -Name obj -ErrorAction SilentlyContinue 
    }
    
    # フォームとコントロールの破棄
    if ($null -ne $textBox) { # テキストボックスが存在する場合
        $textBox.Dispose()
        Clear-Variable -Name textBox -ErrorAction SilentlyContinue 
    }
    
    if ($null -ne $button) {  # ボタンが存在する場合
        $button.Dispose()
        Clear-Variable -Name button -ErrorAction SilentlyContinue 
    }
    
    if ($null -ne $form) { # フォームが存在する場合
        $form.Dispose()
        Clear-Variable -Name form -ErrorAction SilentlyContinue 
    }
    
    # パス情報もクリーンアップ
    Clear-Variable -Name keyPath, comPath, PowerShellDir, UpperDir, ScriptDir -ErrorAction SilentlyContinue
    Clear-Variable -Name inputGuiPath, noDoubleActivationPath -ErrorAction SilentlyContinue
    
    # ガベージコレクション強制実行（オプション）
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-Host "✓ 機密情報をメモリから削除しました。" -ForegroundColor Green
    Write-Host "✓ 処理が正常に完了しました。" -ForegroundColor Green
    
    # 何かキーが押されるまで待機
    Write-Host "終了するには何かキーを押してください..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} catch {
    Write-Host "警告: クリーンアップ中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Yellow
}