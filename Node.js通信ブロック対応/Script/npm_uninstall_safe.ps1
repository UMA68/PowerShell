# =======================================================================================
# 一時的に送信通信をブロック解除し、npm uninstall を実行後、送信通信を再度ブロックするスクリプト
# 必ず管理者権限で実行してください。
# =======================================================================================

# Node.js の送信通信ブロックを一時的に解除
Write-Host "Node.js の送信通信を一時的に許可します..."
Set-NetFirewallRule -DisplayName "Block Node.js Outbound" -Enabled False

# npm uninstall 実行
Write-Host "npm uninstall を実行中..."
# ここに、必要な npm uninstall コマンドを記述します。
# npm -v とは、Node.js のバージョンを確認するためのコマンドです。
# 実際は、npm uninstall <package-name> のように、必要なパッケージを記述して実行します。
# 例: npm uninstall <package-name>
npm -v

# 通信ブロックを再度有効化
Write-Host "Node.js の送信通信を再度ブロックします..."
Set-NetFirewallRule -DisplayName "Block Node.js Outbound" -Enabled True

Write-Host "完了しました。"
