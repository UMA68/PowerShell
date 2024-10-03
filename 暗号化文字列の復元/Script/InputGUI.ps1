Add-Type -AssemblyName System.Windows.Forms

# フォームの作成
$form = New-Object System.Windows.Forms.Form
$form.Text = "復号化する文字列を入力してください"
$form.Size = New-Object System.Drawing.Size(400,150)
$form.StartPosition = "CenterScreen"

# テキストボックスの作成
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Size = New-Object System.Drawing.Size(360,20)
$textBox.Location = New-Object System.Drawing.Point(10,20)
$form.Controls.Add($textBox)

# ボタンの作成
$button = New-Object System.Windows.Forms.Button
$button.Text = "OK"
$button.Location = New-Object System.Drawing.Point(150,60)
$form.Controls.Add($button)

# ボタンがクリックされたときのイベントハンドラー
$button.Add_Click({
    "復号する文字列: "+$textBox.Text | Out-Host
    $form.Close()
})
