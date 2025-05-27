
# Obsidian Vault のパスを指定してください
$vaultPath = "C:\Users\徳永光浩\GitHub\obsidian"

# .mdファイルを再帰的に検索してカウント
$mdFiles = Get-ChildItem -Path $vaultPath -Recurse -Filter *.md -File
$fileCount = $mdFiles.Count

# トークン数を見積もる（平均800トークン/ファイル）
#$averageTokensPerFile = 800
# 1ファイル10KBと仮定し、おおよその平均トークン数を2600と見積もる
$averageTokensPerFile = 2600
# トークン数を計算
$totalTokens = $fileCount * $averageTokensPerFile

# コストを計算（$0.0001 / 1,000トークン）
$costPerThousandTokens = 0.0001
$estimatedCost = ($totalTokens / 1000) * $costPerThousandTokens

# 結果を表示
Write-Host "Markdownファイルの総数: $fileCount"
Write-Host "推定トークン数: $totalTokens"
Write-Host "推定コスト:＄ $estimatedCost"
