# アンインストールしたい SDK のバージョンを指定
$targetVersion = "8.0.100"

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
}
