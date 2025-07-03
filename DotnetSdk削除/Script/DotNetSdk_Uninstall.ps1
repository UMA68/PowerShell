# ================================
# Uninstall .NET SDK 9.0.301
# 必ず管理者権限で実行してください。
# ================================

# # 削除対象のSDKバージョンを指定
# $dotnetSdkVersion = "9.0.301"

# .NET SDKがインストールされているか確認
$installedSdks = dotnet --list-sdks
if (-not $installedSdks) {
    Write-Host "インストールされているSDKが見つかりません。"
    Read-Host "Enterキーを押して終了します..."
    exit
}
# どのバージョンを削除しますか？
Write-Host "インストールされているSDKバージョン:"
$installedSdks | ForEach-Object { Write-Host $_ }
# バージョンを指定
$dotnetSdkVersion = Read-Host "削除したいSDKのバージョンを入力してください (例: 9.0.301): "
# 入力されたか確認
if (-not $dotnetSdkVersion) {
    Write-Host "入力されていません。スクリプトを終了します。"
    Read-Host "Enterキーを押して終了します..."
    exit
}

# 指定バージョンを削除します。よろしいですか？
$confirmation = Read-Host "指定バージョン $dotnetSdkVersion を削除します。よろしいですか？ (Y/N)"
if ($confirmation -ne "Y" -and $confirmation -ne "y") {
    Read-Host "削除をキャンセルしました。`r`nEnterキーを押して終了します..."
    exit
}

if ($installedSdks -notcontains $dotnetSdkVersion) {
    Write-Host "指定されたSDKバージョン $dotnetSdkVersion はインストールされていません。"
    $installedSdks
    Read-Host "Enterキーを押して終了します..."
    exit
}
try{
    
    dotnet-core-uninstall remove --sdk --version $dotnetSdkVersion -ErrorAction Stop
    Write-Host "✅ Microsoft .NET SDK $dotnetSdkVersion のアンインストールが完了しました。"
}catch{
    Write-Host "❌ アンインストールに失敗しました。`r`nエラーメッセージ: $($_.Exception.Message)"
    Read-Host "Enterキーを押して終了します..."
    exit
}
# Enerキーを押して終了
Read-Host "Enterキーを押して終了します..."
