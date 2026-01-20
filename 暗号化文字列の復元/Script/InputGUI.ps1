<#
.SYNOPSIS
    暗号化文字列入力用のGUIフォームを提供します

.DESCRIPTION
    文字列復号スクリプト用のGUI入力フォームを生成します。
    ユーザーが暗号化された文字列を入力するためのテキストボックスとOKボタンを含みます。
    
    このスクリプトは StringDecryption.ps1 からドットソースで読み込まれます。

.INPUTS
    なし。パイプライン入力は受け付けません。

.OUTPUTS
    System.Windows.Forms.Form - フォームオブジェクト
    System.Windows.Forms.TextBox - テキストボックスオブジェクト
    
    これらのオブジェクトは呼び出し元スクリプトで使用されます。

.NOTES
    FileName:      InputGUI.ps1
    Author:        UMA68
    Prerequisites: - PowerShell 5.1以上
                   - Windows環境（System.Windows.Forms が必要）
    
    使用方法:
    このスクリプトは直接実行せず、ドットソースで読み込んで使用します。
    例: . .\InputGUI.ps1

.LINK
    関連スクリプト: StringDecryption.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ====================================
# フォームの作成
# ====================================
$script:form = New-Object System.Windows.Forms.Form
$script:form.Text = "復号化する文字列を入力してください"
$script:form.Size = New-Object System.Drawing.Size(500, 180)
$script:form.StartPosition = "CenterScreen"
$script:form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$script:form.MaximizeBox = $false
$script:form.MinimizeBox = $false

# ====================================
# ラベルの作成
# ====================================
$label = New-Object System.Windows.Forms.Label
$label.Text = "暗号化された文字列を入力してください："
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Size = New-Object System.Drawing.Size(460, 20)
$script:form.Controls.Add($label)

# ====================================
# テキストボックスの作成
# ====================================
$script:textBox = New-Object System.Windows.Forms.TextBox
$script:textBox.Size = New-Object System.Drawing.Size(460, 20)
$script:textBox.Location = New-Object System.Drawing.Point(10, 35)
$script:textBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$script:form.Controls.Add($script:textBox)

# ====================================
# ボタンの作成
# ====================================
# OKボタン
$script:button = New-Object System.Windows.Forms.Button
$script:button.Text = "復号実行"
$script:button.Location = New-Object System.Drawing.Point(150, 75)
$script:button.Size = New-Object System.Drawing.Size(90, 30)
$script:button.DialogResult = [System.Windows.Forms.DialogResult]::OK
$script:form.Controls.Add($script:button)

# キャンセルボタン
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "キャンセル"
$cancelButton.Location = New-Object System.Drawing.Point(250, 75)
$cancelButton.Size = New-Object System.Drawing.Size(90, 30)
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$script:form.Controls.Add($cancelButton)

# ====================================
# フォーム設定
# ====================================
# デフォルトボタンとキャンセルボタンの設定
$script:form.AcceptButton = $script:button
$script:form.CancelButton = $cancelButton

# ====================================
# イベントハンドラー
# ====================================
# OKボタンがクリックされたときのイベントハンドラー
$script:button.Add_Click({ # 復号実行処理
    if (-not [string]::IsNullOrWhiteSpace($script:textBox.Text)) {
        Write-Host "復号する文字列を受け取りました（長さ: $($script:textBox.Text.Length) 文字）" -ForegroundColor Cyan
        $script:form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $script:form.Close()
    } else { # 入力が空の場合
        [System.Windows.Forms.MessageBox]::Show( # 警告ダイアログ表示
            "文字列を入力してください。",
            "入力エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
})

# キャンセルボタンのイベントハンドラー
$cancelButton.Add_Click({ # キャンセル処理
    Write-Host "操作がキャンセルされました。" -ForegroundColor Yellow
    $script:form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $script:form.Close()
})

# Enter キーで OK、Escape キーでキャンセル
$script:textBox.Add_KeyDown({ # キー押下イベントハンドラー
    param($eventSender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { # Enter キー
        $script:button.PerformClick()
        $e.SuppressKeyPress = $true
    } elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { # Escape キー
        $cancelButton.PerformClick()
        $e.SuppressKeyPress = $true
    }
})
