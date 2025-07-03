# ==========================================================
# PowerShell スクリプト: .NET Uninstall Tool のインストール
# 必ず管理者権限で実行してください。
# ==========================================================

# Microsoft.DotNet.UninstallToolがすでにインストールされているか確認
if (Get-Command dotnet-core-uninstall -ErrorAction SilentlyContinue) {
    Write-Host "Microsoft.DotNet.UninstallTool はすでにインストールされています。"
    Read-Host "Enterキーを押して終了します..."
    exit
}

# .NET Uninstall Tool のインストールします。よろしいですか？
$confirmation = Read-Host "Microsoft.DotNet.UninstallTool をインストールします。よろしいですか？ (Y/N): "
if ($confirmation -ne "Y" -and $confirmation -ne "y") {
    Write-Host "インストールをキャンセルしました。`r`nEnterキーを押して終了します..."
    exit
}

# .NET CLI ツールをインストール
try{
    dotnet tool install -g Microsoft.DotNet.UninstallTool -ErrorAction Stop
    Write-Host "✅ Microsoft.DotNet.UninstallTool のインストールが完了しました。"
}catch{
    Write-Host "❌ Microsoft.DotNet.UninstallTool のインストールに失敗しました。`r`nエラーメッセージ: $($_.Exception.Message)"
    Read-Host "Enterキーを押して終了します..."
    exit
}

# インストール確認
dotnet-core-uninstall --help
# Enterキーを押して終了
Read-Host "Enterキーを押して終了します..."

