#Requires -Version 5.1
# PSScriptAnalyzer Warning Suppression for ConvertTo-SecureString
# User input must be converted from plaintext to SecureString for encryption processing
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

<#
.SYNOPSIS
    鍵ファイルを使用して文字列を暗号化し、ファイルへ出力します。

.DESCRIPTION
    指定された鍵ファイル（既定: Encryption.key）を使用して、入力された文字列を
    ConvertFrom-SecureString で暗号化し、ターミナル表示とファイル出力を行います。
    
    主な機能：
    - 鍵ファイルを使用した安全な暗号化処理
    - 入力文字列とファイル名のバリデーション
    - 二重起動防止機構（早期チェック）
    - 処理後の機密情報自動削除（SecureString、鍵情報、入力文字列）
    - エラー時・二重起動時の適切なクリーンアップ処理
    
    出力ファイルは本スクリプトの1階層上に、指定したファイル名で保存します。

.PARAMETER keyFileName
    使用する鍵ファイル名（Common フォルダー配下）。デフォルトは Encryption.key。
    パス区切り文字（\ / :）を含めることはできません。ファイル名のみを指定してください。

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    暗号化文字列（標準出力および指定ファイル）

.EXAMPLE
    .\MakeEncryptedString.ps1
    
    既定の鍵ファイル（Encryption.key）で暗号化し、指定したファイル名で保存します。
    1. 二重起動チェックが実行されます
    2. 鍵ファイルを読み込みます
    3. 暗号化する文字列の入力を求められます
    4. 入力文字列を SecureString に変換し暗号化します
    5. 暗号化文字列をターミナルに表示します
    6. 出力ファイル名の入力を求められます
    7. 指定ファイル名でスクリプト親ディレクトリに保存します
    8. 機密情報をメモリから自動削除します
    9. キー入力待ち後、スクリプトが終了します

.EXAMPLE
    .\MakeEncryptedString.ps1 -keyFileName "MyKey.bin"
    
    カスタム鍵ファイル（MyKey.bin）を用いて暗号化します。

.NOTES
    FileName:     MakeEncryptedString.ps1
    Author:       UMA68
    Version:      1.2.0
    LastModified: 2025-12-11
    Prerequisites:
      - PowerShell 5.1 以上
      - Common\<鍵ファイル> が存在すること
      - Common\NoDoubleActivation.ps1 が存在すること
    
    変更履歴:
    v1.2.0 (2025-12-11)
        - クリーンアップ処理を関数化（Invoke-Cleanup）
        - 二重起動チェックを最優先で実行（早期判定）
        - 二重起動時・エラー時も適切なクリーンアップを実行
        - 制御フローフラグ（$script:CanExecuteProcess）を導入
        - スクリプトスコープ変数の適切な管理
        - COM オブジェクトのリソース解放を強化
    
    v1.1.0 (2025-12-09)
        - 二重起動防止機構を追加
        - セキュリティクリーンアップ処理を追加
        - パラメーター検証を強化
    
    v1.0.0 (初版)
        - 基本的な暗号化機能を実装
    
    セキュリティに関する注意:
    - 入力文字列は SecureString として処理されます
    - 処理後、機密情報（鍵、SecureString、入力文字列）は速やかにメモリから削除されます
    - 鍵ファイルは厳重に管理してください
    - 暗号化文字列はターミナルに表示されるため、作業時は周囲に注意してください
    
    操作方法:
    - スクリプト起動時に二重起動チェックが自動実行されます
    - プロンプトに従って暗号化する文字列を入力します
    - 暗号化文字列がターミナルに表示されます（コピー可能）
    - 出力ファイル名を入力します（パス区切り文字不可）
    - ファイルはスクリプトの1階層上のディレクトリに保存されます
    - 処理完了後、キーを押すとスクリプトが終了します
    
    クリーンアップ処理:
    - 正常終了時: 機密情報完全削除 → キー入力待ち → 終了
    - 二重起動時: キー入力待ち → 終了（機密情報は未生成のためスキップ）
    - エラー時: エラーダイアログ表示 → 適切なクリーンアップ → 終了
    
    エラーハンドリング:
    - スクリプト読み込みエラー: エラーダイアログ → 最小クリーンアップ → 終了
    - 鍵ファイル読み込みエラー: エラーダイアログ → 最小クリーンアップ → 終了
    - 入力検証エラー: エラーダイアログ → クリーンアップ → 終了
    - ファイル書き込みエラー: エラーダイアログ → 完全クリーンアップ → 終了
    - 二重起動検出: 警告ダイアログ → 最小クリーンアップ → 終了

.LINK
    関連スクリプト: MakeEncrypted.ps1（鍵ファイル作成）
    関連スクリプト: StringDecryption.ps1（復号）
    関連スクリプト: NoDoubleActivation.ps1（二重起動防止）
#>

# ====================================
# パラメーター定義
# ====================================
param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]  # 鍵ファイル名の必須チェック
    [ValidateScript( {
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

# ====================================
# 制御フローフラグの初期化
# ====================================
$script:CanExecuteProcess = $true  # メイン処理を実行するかどうかのフラグ

# ====================================
# クリーンアップ関数の定義
# ====================================
function Invoke-Cleanup {
    <#
    .SYNOPSIS
        機密情報をメモリから削除し、スクリプトのクリーンアップを実行します。
    .DESCRIPTION
        暗号化鍵、SecureString、入力文字列などの機密情報をメモリから完全に削除します。
    .PARAMETER FullCleanup
        $trueの場合は機密情報を完全削除します。$falseの場合は最小限のクリーンアップを行います。
    #>
    param(
        [bool]$FullCleanup = $true  # 完全なクリーンアップを実行するか
    )
    
    try {
        if ($FullCleanup) { # 完全なクリーンアップを実行する場合
            # 暗号化鍵の削除
            if ($null -ne $script:EncryptionKey) { # 鍵情報が存在する場合
                [Array]::Clear($script:EncryptionKey, 0, $script:EncryptionKey.Length)
                Clear-Variable -Name EncryptionKey -Scope Script -ErrorAction SilentlyContinue
            }
            
            # SecureString の破棄
            if ($null -ne $script:SecureString) { # SecureString が存在する場合
                $script:SecureString.Dispose()
                Clear-Variable -Name SecureString -Scope Script -ErrorAction SilentlyContinue
            }
            
            # 入力文字列と暗号化文字列の削除
            Clear-Variable -Name InputString, EncryptedString, FileName, OutputPath -Scope Script -ErrorAction SilentlyContinue
            
            # COMオブジェクトの解放
            if ($null -ne $script:obj) { # COMオブジェクトが存在する場合
                try {
                    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
                } catch {
                    Write-Error "COMオブジェクト解放エラー: $($_.Exception.Message)"
                }
                Clear-Variable -Name obj -Scope Script -ErrorAction SilentlyContinue
            }
            
            # パス情報もクリーンアップ
            Clear-Variable -Name keyPath, comPath, PowerShellDir, UpperDir, ScriptDir -Scope Script -ErrorAction SilentlyContinue
            Clear-Variable -Name noDoubleActivationPath -Scope Script -ErrorAction SilentlyContinue
            
            # ガベージコレクション強制実行
            [System.GC]::Collect()                  # ガベージコレクションの実行
            [System.GC]::WaitForPendingFinalizers() # ファイナライザの完了待機
            
            Write-Information "✓ 機密情報をメモリから削除しました。"
        }
        
        # 何かキーが押されるまで待機
        Write-Information "終了するには何かキーを押してください..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Write-Error "クリーンアップ中にエラーが発生しました: $($_.Exception.Message)"
        throw $_
    }
}

# ====================================
# 共通スクリプトの読み込み
# ====================================
try {
    if (-not (Test-Path $noDoubleActivationPath)) { # NoDoubleActivation.ps1の存在確認
        throw "NoDoubleActivation.ps1 が見つかりません: $noDoubleActivationPath"
    }
    . $noDoubleActivationPath -ErrorAction Stop
} catch {
    $script:CanExecuteProcess = $false
    $obj = New-Object -ComObject WScript.Shell
    $obj.Popup("共通スクリプトの読み込みに失敗しました。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
    Invoke-Cleanup -FullCleanup $false
    exit
}

# ====================================
# 二重起動の防止（最優先チェック）
# ====================================
# 同じスクリプトが複数同時実行されないようチェック
if (-not (Test-NoDoubleActivation -Thread "MakeEncryptedString" -ShowDialog)) { # 二重起動が検出された場合
    # 既に起動中のため処理を終了
    Write-Warning "既に起動中のため処理を終了します"
    $script:CanExecuteProcess = $false
    Invoke-Cleanup -FullCleanup $false
    exit
}

# ====================================
# 鍵ファイルの読み込み
# ====================================
try {
    if (Test-Path -Path $keyPath) { # 鍵ファイルが存在する場合
        [byte[]]$script:EncryptionKey = [System.IO.File]::ReadAllBytes($keyPath)
        Write-Information "鍵ファイル「$keyFileName」を読み込みました。"
    } else { # 鍵ファイルが存在しない場合
        throw "鍵ファイル「$keyFileName」が見つかりません: $keyPath"
    }
} catch {
    Write-Error $_.Exception.Message
    $script:obj = New-Object -ComObject WScript.Shell
    $script:obj.popup($_.Exception.Message + "`r`n`r`n作成した鍵ファイルを「$comPath」に配置してください。", 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
    Invoke-Cleanup -FullCleanup $false
    exit
}

# ====================================
# 入力受付とバリデーション
# ====================================
$script:InputString = Read-Host -Prompt "暗号化する文字列を入力してください"   # 暗号化する文字列を入力

if ([string]::IsNullOrWhiteSpace($script:InputString)) { # 入力が空の場合
    $script:obj = New-Object -ComObject WScript.Shell
    $script:obj.popup("暗号化する文字列が入力されていません。処理を終了します。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
    Invoke-Cleanup -FullCleanup $false
    exit
}

# 暗号化する文字列を表示（セキュリティのためコメントアウト）
# Write-Host "暗号化する文字列: $script:InputString"

# プレーンテキストをSecureStringに変換
$script:SecureString = ConvertTo-SecureString -String $script:InputString -AsPlainText -Force

# SecureStringを暗号化
$script:EncryptedString = ConvertFrom-SecureString -SecureString $script:SecureString -Key $script:EncryptionKey

# 暗号化した文字列を表示
Write-Information "暗号化した文字列: $script:EncryptedString"

# ====================================
# 出力ファイル名入力とバリデーション
# ====================================
$script:FileName = Read-Host -Prompt "出力するファイル名を入力してください"   # ファイル名を入力する

if ([string]::IsNullOrWhiteSpace($script:FileName)) { # ファイル名が空の場合
    $script:obj = New-Object -ComObject WScript.Shell
    $script:obj.popup("ファイル名が入力されていません。処理を終了します。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
    Invoke-Cleanup -FullCleanup $true
    exit
}

# 無効文字とパス区切りのチェック
$invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
if (($script:FileName.IndexOfAny($invalidChars) -ge 0) -or ($script:FileName -match "[\\/:]")) { # 無効文字またはパス区切り文字が含まれている場合
    $script:obj = New-Object -ComObject WScript.Shell
    $script:obj.popup("ファイル名に使用できない文字が含まれています。別の名前を指定してください。", 0, "エラー", 0x10)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
    Invoke-Cleanup -FullCleanup $true
    exit
}

# 出力パス決定（同名ファイルの上書き確認は行わない設計）
$script:OutputPath = Join-Path -Path $UpperDir -ChildPath $script:FileName

# ====================================
# ファイル出力
# ====================================
try {
    $script:EncryptedString | Out-File -FilePath $script:OutputPath -Encoding utf8 -ErrorAction Stop
    
    Write-Information "暗号化した文字列をファイルに出力しました: $script:OutputPath"
    $script:obj = New-Object -ComObject WScript.Shell
    $script:obj.popup("暗号化した文字列をファイル「$script:FileName」に出力しました。", 0, "文字列暗号化", 0x40)  # 0x40:情報アイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
    $script:obj = $null
} catch {
    Write-Error $_.Exception.Message
    $script:obj = New-Object -ComObject WScript.Shell
    $script:obj.popup("ファイルへの書き込みに失敗しました。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x10)  # 0x10:エラーアイコン
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
    Invoke-Cleanup -FullCleanup $true
    exit
}

# ====================================
# セキュリティクリーンアップ
# ====================================
Write-Information "処理が完了しました。機密情報をメモリから削除しています..."
Invoke-Cleanup -FullCleanup $true
