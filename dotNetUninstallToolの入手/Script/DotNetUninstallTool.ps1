# ==========================================================
# PowerShell スクリプト: .NET Uninstall Tool のインストール
# 必ず管理者権限で実行してください。
# ==========================================================

# .NET CLI ツールとしてインストール
dotnet tool install -g Microsoft.DotNet.UninstallTool

# インストール確認
dotnet-core-uninstall --help
# Enterキーを押して終了
Read-Host "Enterキーを押して終了します..."

