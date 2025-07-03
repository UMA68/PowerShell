# ==========================================================
# PowerShell スクリプト: Microsoft .NET SDK のアンインストール
# 必ず管理者権限で実行してください。
# ==========================================================

# アンインストールしたい SDK のバージョンを指定
$targetVersion = "8.0.411"

# インストール済みの .NET SDK 一覧を取得
$installedSdks = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE 'Microsoft .NET SDK%'"

# 該当バージョンを検索してアンインストール
$matchedSdk = $installedSdks | Where-Object { $_.Name -like "*$targetVersion*" }

if ($matchedSdk) {
    Write-Host "✅ Microsoft .NET SDK $targetVersion をアンインストールします..."
    $matchedSdk.Uninstall()
    Write-Host "✅ アンインストール完了しました。"
} else {
    Write-Host "⚠️ Microsoft .NET SDK $targetVersion は見つかりませんでした。"
    Write-Host $installedSdks.Name
    # Enterキーを押して終了
    Read-Host "Enterキーを押して終了します..."
    exit
}
