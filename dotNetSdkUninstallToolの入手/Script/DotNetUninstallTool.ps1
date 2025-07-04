
# ==========================================================
# PowerShell スクリプト: .NET Uninstall Tool の統合管理メニュー
# 必ず管理者権限で実行してください。
# ==========================================================

# スクリプトの実行環境を取得
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
$UpperPath = $scriptPath | Split-Path -Parent                       # スクリプトの親パスを取得
$PowerShellDir = $UpperPath | Split-Path -Parent                    # スクリプトの親パスの親パスを取得
$dotNetSdkUninstallToolPath = Join-Path -Path $UpperPath -ChildPath "dotNetSdkUninstallTool" # dotNetSdkUninstallToolのパスを取得

function Show-Menu {
    Write-Host ""
    Write-Host "=== .NET Uninstall Tool 管理メニュー ==="
    Write-Host "1. インストール"
    Write-Host "2. アンインストール"
    Write-Host "Q. 終了"
    Write-Host ""
}

function Install-UninstallTool {
    # $msiPath = "dotNetSdkUninstallTool\\dotnet-core-uninstall-1.7.521001.msi"
    $msiPath = Join-Path -Path $dotNetSdkUninstallToolPath -ChildPath "dotnet-core-uninstall.msi"
    if (-Not (Test-Path $msiPath)) {
        Write-Host "❌ MSIファイルが見つかりません: $msiPath"
        return
    }
    Unblock-File -Path $msiPath
    Write-Host "🛠 インストールを開始します..."
    Start-Process "msiexec.exe" -ArgumentList "/i `"$msiPath`" /passive /norestart" -Wait -Verb RunAs
    Start-Sleep -Seconds 5
    if (Get-Command dotnet-core-uninstall -ErrorAction SilentlyContinue) {
        Write-Host "✅ インストールが完了しました。"
        dotnet-core-uninstall --help
    } else {
        Write-Host "⚠️ インストール後にコマンドが認識されていません。PowerShell を再起動して確認してください。"
    }
}

function Uninstall-UninstallTool {
    $uninstallKey = "HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    $uninstallKeyWow = "HKLM:\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    $keys = Get-ChildItem $uninstallKey, $uninstallKeyWow | Where-Object {
        (Get-ItemProperty $_.PSPath).DisplayName -like "*Uninstall Tool*"
    }
    if (-not $keys) {
        Write-Host "✅ Microsoft.DotNet.UninstallTool はインストールされていません。"
        return
    }
    $productCode = $keys[0].PSChildName
    Write-Host "🧾 製品コード: $productCode"
    Write-Host "🛠 アンインストールを開始します..."
    Start-Process "msiexec.exe" -ArgumentList "/x $productCode /passive /norestart" -Wait -Verb RunAs
    Start-Sleep -Seconds 5
    $toolPath = "C:\Program Files (x86)\dotnet-core-uninstall"
    if (Test-Path $toolPath) {
        Remove-Item $toolPath -Recurse -Force
        Write-Host "🧹 残存フォルダを削除しました: $toolPath"
    }
    if (Get-Command dotnet-core-uninstall -ErrorAction SilentlyContinue) {
        Write-Host "⚠️ アンインストール後もコマンドが残っています。PowerShell を再起動して確認してください。"
    } else {
        Write-Host "✅ アンインストールが完了しました。"
    }
}

# ループ制御フラグ
$exitFlag = $false

do {
    Show-Menu
    $choice = Read-Host "操作を選択してください (1/2/Q)"
    switch ($choice) {
        "1" { Install-UninstallTool }
        "2" { Uninstall-UninstallTool }
        "Q" { $exitFlag = $true }
        "q" { $exitFlag = $true }
        default { Write-Host "⚠️ 無効な選択です。もう一度入力してください。" }
    }
} while (-not $exitFlag)

Write-Host "`n終了しました。"
