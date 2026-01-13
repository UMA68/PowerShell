<#
.SYNOPSIS
    暗号化された文字列を復号して表示するスクリプト

.DESCRIPTION
    指定された鍵ファイル（Encryption.key）を使用して、暗号化された文字列を復号し、
    元の平文を表示します。GUIフォームから暗号文字列を入力する形式です。
    
    復号結果はポップアップダイアログで表示されます。
    
    主な機能：
    - 鍵ファイルを使用した安全な復号処理
    - GUIフォームによる入力（Enter/Escapeキー対応）
    - ポップアップダイアログでの結果表示
    - 二重起動防止機構（早期チェック）
    - 処理後の機密情報自動削除（SecureString、鍵情報、フォームコントロール）
    - エラー時・二重起動時の適切なクリーンアップ処理

.PARAMETER keyFileName
    復号に使用する鍵ファイル名。Commonフォルダー内に配置する必要があります。
    デフォルト値: "Encryption.key"
    
    パス区切り文字（\ / :）を含むことはできません。ファイル名のみを指定してください。

.EXAMPLE
    .\StringDecryption.ps1
    
    デフォルトの鍵ファイル（Encryption.key）を使用して復号処理を実行します。
    1. 二重起動チェックが実行されます
    2. GUIフォームが表示され、暗号化文字列の入力を求められます
    3. 復号結果がポップアップダイアログで表示されます
    4. 機密情報がメモリから自動削除されます
    5. キー入力待ち後、スクリプトが終了します

.EXAMPLE
    .\StringDecryption.ps1 -keyFileName "MyCustom.key"
    
    カスタム鍵ファイル（MyCustom.key）を使用して復号処理を実行します。

.INPUTS
    なし。パイプライン入力は受け付けません。

.OUTPUTS
    なし。復号結果はポップアップダイアログで表示されます。
    セキュリティ上、コンソールログには出力されません。

.NOTES
    FileName:      StringDecryption.ps1
    Author:        UMA68
    Version:       1.2.0
    LastModified:  2025-12-11
    Prerequisites: - PowerShell 5.1以上
                   - 鍵ファイル（Encryption.key）がCommonフォルダーに存在すること
                   - InputGUI.ps1 が同じScriptフォルダーに存在すること
                   - NoDoubleActivation.ps1 がCommonフォルダーに存在すること
    
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
        - 基本的な復号機能を実装
    
    セキュリティに関する注意:
    - 復号結果はダイアログに表示されるため、作業時は周囲に注意してください
    - 復号後、機密情報（鍵、SecureString、平文）は速やかにメモリから削除されます
    - 鍵ファイルは厳重に管理してください
    - SecureString を使用した安全な文字列処理を実施
    
    操作方法:
    - スクリプト起動時に二重起動チェックが自動実行されます
    - GUIフォームでEnterキーを押すと復号を実行します
    - Escapeキーまたはキャンセルボタンで処理を中止できます
    - 復号結果はポップアップダイアログでのみ表示されます（画面キャプチャに注意）
    - 処理完了後、キーを押すとスクリプトが終了します
    
    クリーンアップ処理:
    - 正常終了時: 機密情報完全削除 → キー入力待ち → 終了
    - 二重起動時: キー入力待ち → 終了（機密情報は未生成のためスキップ）
    - エラー時: エラーダイアログ表示 → 終了

.LINK
    関連スクリプト: MakeEncryptedString.ps1 (文字列の暗号化)
    関連スクリプト: MakeEncrypted.ps1 (鍵ファイルの作成)
    関連スクリプト: InputGUI.ps1 (GUI入力フォーム)
    関連スクリプト: NoDoubleActivation.ps1 (二重起動防止)
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
# 制御フローフラグの初期化
# ====================================
$script:CanExecuteProcess = $true  # メイン処理を実行するかどうかのフラグ

# ====================================
# クリーンアップ関数の定義
# ====================================
function Invoke-Cleanup {
    param(
        [bool]$FullCleanup = $true  # 完全なクリーンアップを実行するか
    )
    
    try {
        if ($FullCleanup) { # 完全なクリーンアップを実行する場合
            # 復号結果の削除
            if ($null -ne $script:DecryptedString) { # 復号結果が存在する場合
                Clear-Variable -Name DecryptedString -Scope Script -ErrorAction SilentlyContinue 
            }
            
            # 暗号化鍵の削除
            if ($null -ne $script:EncryptedKey) { # 鍵情報が存在する場合
                Clear-Variable -Name EncryptedKey -Scope Script -ErrorAction SilentlyContinue 
            }
            
            # 入力文字列の削除
            if ($null -ne $script:InputString) { # 入力文字列が存在する場合
                Clear-Variable -Name InputString -Scope Script -ErrorAction SilentlyContinue 
            }
            
            # COMオブジェクトの解放
            if ($null -ne $script:obj) { # COMオブジェクトが存在する場合
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
                Clear-Variable -Name obj -Scope Script -ErrorAction SilentlyContinue 
            }
            
            # フォームとコントロールの破棄
            # テキストボックスの破棄
            if ($null -ne $script:textBox) { # テキストボックスが存在する場合
                $script:textBox.Dispose()
                Clear-Variable -Name textBox -Scope Script -ErrorAction SilentlyContinue 
            }
            # ボタンの破棄
            if ($null -ne $script:button) { # ボタンが存在する場合
                $script:button.Dispose()
                Clear-Variable -Name button -Scope Script -ErrorAction SilentlyContinue 
            }
            # フォームの破棄
            if ($null -ne $script:form) { # フォームが存在する場合
                $script:form.Dispose()
                Clear-Variable -Name form -Scope Script -ErrorAction SilentlyContinue 
            }
            
            # パス情報もクリーンアップ
            Clear-Variable -Name keyPath, comPath, PowerShellDir, UpperDir, ScriptDir -Scope Script -ErrorAction SilentlyContinue
            Clear-Variable -Name inputGuiPath, noDoubleActivationPath -Scope Script -ErrorAction SilentlyContinue
            
            # ガベージコレクション強制実行
            [System.GC]::Collect()                  # ガベージコレクションを強制的に実行
            [System.GC]::WaitForPendingFinalizers() # 最終化が完了するまで待機
            
            Write-Information "✓ 機密情報をメモリから削除しました。"
            Write-Information "✓ 処理が正常に完了しました。"
        }
        
        # 何かキーが押されるまで待機
        Write-Information "終了するには何かキーを押してください..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Write-Warning "クリーンアップ中にエラーが発生しました: $($_.Exception.Message)"
    }
}

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
    Write-Error $_.Exception.Message
    $obj = $null
    try {
        $obj = New-Object -ComObject WScript.Shell
        $obj.popup($_.Exception.Message, 0, "エラー", 0x10)  # 0x10:エラーアイコン
    } finally {
        if ($null -ne $obj) { # COMオブジェクトの解放
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
    }
    exit
}

# ====================================
# 二重起動の防止（最優先チェック）
# ====================================
# 同じスクリプトが複数同時実行されないようチェック
if (-not (Test-NoDoubleActivation -Thread "StringDecryption" -ShowDialog)) { # 二重起動が検出された場合
    # 既に起動中のため処理を終了
    Write-Warning "既に起動中のため処理を終了します"
    $script:CanExecuteProcess = $false
    Invoke-Cleanup -FullCleanup $false  # クリーンアップのみ実行
    exit
}

# ====================================
# 鍵ファイルの読み込み
# ====================================
# 暗号化の際に使用する鍵ファイルを読み込む
try {
    if (Test-Path -Path $keyPath) { # 鍵ファイルが存在する場合
        # 鍵ファイルを読み込む
        [byte[]]$EncryptedKey = [System.IO.File]::ReadAllBytes($keyPath)
        Write-Information "鍵ファイル「$keyFileName」を読み込みました。"
    } else { # 鍵ファイルが存在しない場合
        throw "鍵ファイル「$keyFileName」が見つかりません: $keyPath"
    }
} catch {
    Write-Error $_.Exception.Message
    $obj = $null
    try {
        $obj = New-Object -ComObject WScript.Shell
        $obj.popup($_.Exception.Message + "`r`n`r`n作成した鍵ファイルを「$comPath」へ配置してください。", 0, "エラー", 0x10)
    } finally {
        if ($null -ne $obj) { # COMオブジェクトの解放
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
    }
    exit
}

# ====================================
# ユーザー入力の取得
# ====================================
# フォームを表示
$dialogResult = $form.ShowDialog()

# ダイアログの結果を確認
if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Cancel) { # ユーザーがキャンセルした場合
    Write-Warning "操作がユーザーによってキャンセルされました。処理を終了します。"
    # フォームを破棄
    if ($null -ne $form) { $form.Dispose() }
    exit
}

$InputString = $textBox.Text    # 入力された文字列取得

# 入力検証
if ([string]::IsNullOrWhiteSpace($InputString)) { # 入力が空の場合
    Write-Warning "空文字列が入力されました。処理を終了します。"
    $obj = $null
    try {
        $obj = New-Object -ComObject WScript.Shell
        $obj.popup("入力が空です。処理を終了します。", 0, "情報", 0x40)
    } finally {
        if ($null -ne $obj) { # COMオブジェクトの解放
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
        # フォームを破棄
        if ($null -ne $form) { $form.Dispose() }
    }
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
    
    Write-Information "復号に成功しました。"
    Write-Information ""
    Write-Information "============================="
    Write-Information "復号結果: $DecryptedString"
    Write-Information "============================="
    Write-Information ""
    Write-Information "※ 上記の復号結果をコピーしてご利用ください"
} catch {
    Write-Error "文字列の復号に失敗しました: $($_.Exception.Message)"
    $obj = $null
    try {
        $obj = New-Object -ComObject WScript.Shell
        $obj.popup("文字列の復号に失敗しました。`r`n`r`n原因: $($_.Exception.Message)`r`n`r`n処理を終了します。", 0, "エラー", 0x10)
    } finally {
        if ($null -ne $obj) { # COMオブジェクトの解放
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
        # エラー時もフォームを破棄
        if ($null -ne $form) { $form.Dispose() }
        if ($null -ne $textBox) { $textBox.Dispose() }
        if ($null -ne $button) { $button.Dispose() }
    }
    exit
}

# ====================================
# 結果表示とクリーンアップ
# ====================================
# 復号化した文字列を表示（セキュリティ上、コンソールログには出力しない）
# ポップアップダイアログでのみ表示
$script:obj = New-Object -ComObject WScript.Shell
$script:obj.popup("復号に成功しました。`r`n`r`n結果: $DecryptedString`r`n`r`n※この情報は画面キャプチャにご注意ください", 0, "復号成功", 0x40)  # 0x40:情報アイコン

Write-Information "復号処理が完了しました。機密情報をメモリから削除しています..."

# ====================================
# セキュリティクリーンアップ
# ====================================
# セキュリティのため機密情報をメモリから確実に削除

# 鍵情報の削除
if ($null -ne $EncryptedKey) { # 鍵情報が存在する場合
    [Array]::Clear($EncryptedKey, 0, $EncryptedKey.Length)
    $script:EncryptedKey = $EncryptedKey
}

# SecureString の破棄
if ($null -ne $SecureDecryptedString) { # SecureString が存在する場合
    $SecureDecryptedString.Dispose()
}

# 平文パスワードの削除
if ($null -ne $DecryptedString) { # 復号結果が存在する場合
    $script:DecryptedString = $DecryptedString
}

# 入力文字列の削除
if ($null -ne $InputString) { # 入力文字列が存在する場合
    $script:InputString = $InputString
}

# フォームとコントロールをスクリプトスコープに保存
if ($null -ne $textBox) { # テキストボックスが存在する場合
    $script:textBox = $textBox
}
if ($null -ne $button) { # ボタンが存在する場合
    $script:button = $button
}
if ($null -ne $form) { # フォームが存在する場合
    $script:form = $form
}

# クリーンアップ関数を呼び出し
Invoke-Cleanup -FullCleanup $true