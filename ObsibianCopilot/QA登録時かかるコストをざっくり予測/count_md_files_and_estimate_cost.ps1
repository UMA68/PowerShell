<#
.SYNOPSIS
    Obsidian Vault内のMarkdownファイルから、ChatGPT API使用時のコストを見積もります。

.DESCRIPTION
    指定されたObsidian Vaultディレクトリ内の.mdファイルを検索し、
    実際のファイルサイズに基づいてトークン数とAPIコストを見積もります。
    
    主な機能:
    - 実ファイルサイズベースの正確なトークン推定
    - 入力・出力トークンの個別コスト計算
    - 複数GPTモデルのコスト比較（GPT-4o、GPT-4o-mini、GPT-3.5-turbo）
    - ディレクトリ別統計表示
    - 不要フォルダの自動除外
    - CSV/JSON形式でのエクスポート
    - 処理進捗のリアルタイム表示
    - エラー耐性のある処理（個別ファイルエラーをスキップ）

.PARAMETER VaultPath
    Obsidian Vaultのパス。デフォルトは "$HOME\GitHub\obsidian" です。
    存在しないパスを指定するとエラーで終了します。

.PARAMETER CharsPerToken
    1トークンあたりの文字数。デフォルトは 2.5（日本語想定）です。
    英語の場合は 4 を推奨します。
    この値を調整することで、言語特性に応じた精度の高い見積もりが可能です。

.PARAMETER CostPerMillionTokens
    100万トークンあたりの入力コスト（USD）。デフォルトは 2.50 (GPT-4o入力価格) です。
    使用するモデルに応じて変更してください。
    参考: GPT-4o=2.50、GPT-4o-mini=0.15、GPT-3.5-turbo=0.50

.PARAMETER ShowTopFiles
    最もサイズが大きいファイルを表示する数。デフォルトは 10 です。
    容量の大きいファイルを特定してコスト削減に役立てることができます。

.PARAMETER ShowModelComparison
    複数のGPTモデル（GPT-4o、GPT-4o-mini、GPT-3.5-turbo）のコスト比較を表示します。
    入力・出力トークンの両方を考慮した正確なコスト比較を提供します。

.PARAMETER ExportToFile
    結果をファイルに出力します。CSVまたはJSON形式を指定できます（例: "result.csv" または "result.json"）。
    タイムスタンプ、トークン数、コスト、Top 5ディレクトリなどの詳細情報を含みます。

.PARAMETER OutputTokenRatio
    出力トークン数の入力トークン数に対する比率。デフォルトは 0（出力コストを計算しない）です。
    例: 0.5 は入力の半分の出力トークンを想定します。
    出力トークンコストは入力の3倍で計算されます（GPT標準価格モデル）。

.PARAMETER ExcludeFolders
    除外するフォルダ名の配列。デフォルトは @(".obsidian", ".git", ".trash") です。
    メタデータや一時ファイルを含むフォルダを除外することで、より正確な見積もりが可能です。

.PARAMETER ShowProgress
    ファイル処理中に進捗を表示します（100ファイルごと）。
    大規模なVaultで処理状況を把握したい場合に有効です。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1
    デフォルト設定でコストを見積もります（入力トークンのみ、GPT-4o価格）。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -VaultPath "C:\MyVault" -CostPerMillionTokens 0.15
    カスタムパスとGPT-4o-miniのコスト単価で見積もります。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ShowModelComparison
    GPT-4o、GPT-4o-mini、GPT-3.5-turboの3モデルのコスト比較を表示します。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -OutputTokenRatio 0.5 -ShowModelComparison
    入力トークンの50%の出力を想定し、入力+出力の合計コストを複数モデルで比較します。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ExportToFile "result.csv"
    結果をCSVファイルに出力します（タイムスタンプ、トークン数、コスト、Top 5ディレクトリなど）。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ShowProgress -ExcludeFolders @(".obsidian", ".git", "drafts")
    進捗表示を有効にし、カスタム除外フォルダを指定して実行します。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ShowModelComparison -ExportToFile "result.json" -ShowTopFiles 20 -OutputTokenRatio 0.3
    すべての機能を使用して詳細な分析を実行します：
    - 3モデルのコスト比較（入力+出力）
    - JSON形式でエクスポート
    - Top 20の大容量ファイルを表示
    - 出力トークン比率30%を想定

.NOTES
    File Name      : count_md_files_and_estimate_cost.ps1
    Author         : UMA
    Prerequisite   : PowerShell
    Cost Reference : https://openai.com/api/pricing/
    
    主要機能:
    - ディレクトリ別統計表示（サイズ順にソート）
    - 複数モデルのコスト比較（GPT-4o、GPT-4o-mini、GPT-3.5-turbo）
    - 入力・出力トークンの個別・合計コスト計算
    - CSV/JSON形式でのエクスポート（詳細統計含む）
    - 最大ファイルサイズTop N表示（デフォルト10件）
    - 不要フォルダの自動除外（.obsidian、.git、.trash）
    - 進捗表示機能（100ファイルごと）
    - エラー耐性処理（個別ファイルエラーをスキップ）
    - 実行終了時の一時停止機能
    
    価格情報（2024年時点）:
    GPT-4o        : 入力 $2.50/1M tokens, 出力 $10.00/1M tokens
    GPT-4o-mini   : 入力 $0.15/1M tokens, 出力 $0.60/1M tokens
    GPT-3.5-turbo : 入力 $0.50/1M tokens, 出力 $1.50/1M tokens
    
    トークン推定方法:
    ファイルサイズ(bytes) ÷ 2 (UTF-8推定) ÷ CharsPerToken = トークン数
#>
param(
    [Parameter(Mandatory=$false)]
    [string]$VaultPath = "$HOME\GitHub\obsidian",
    [Parameter(Mandatory=$false)]
    [double]$CharsPerToken = 2.5,   # 日本語の場合は約2-3文字/トークン
    [Parameter(Mandatory=$false)]
    [double]$CostPerMillionTokens = 2.50,  # GPT-4o入力価格(100万トークンあたり）（2024年時点）
    [Parameter(Mandatory=$false)]
    [int]$ShowTopFiles = 10,        # 最大表示する大容量ファイル数
    [Parameter(Mandatory=$false)]
    [switch]$ShowModelComparison = $false,  # 複数モデル比較表示フラグ
    [Parameter(Mandatory=$false)]
    [string]$ExportToFile = "",     # 結果をエクスポートするファイル名（CSVまたはJSON）
    [Parameter(Mandatory=$false)]
    [double]$OutputTokenRatio = 0,  # 出力トークン数の入力トークン数に対する比率
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeFolders = @(".obsidian", ".git", ".trash"),   # 除外フォルダ
    [Parameter(Mandatory=$false)]
    [switch]$ShowProgress = $false  # 進捗表示フラグ
)

begin {
    # Vaultパスの存在確認
    if (-not (Test-Path -Path $VaultPath)) {
        Write-Host "Error: Vault path does not exist: $VaultPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Analyzing Obsidian Vault..." -ForegroundColor Cyan
    Write-Host "Vault Path: $VaultPath" -ForegroundColor Gray
    Write-Host ""
    
    # 統計情報の初期化
    $script:totalSize = 0
    $script:fileCount = 0
    $script:fileSizes = @()
    $script:dirStats = @{}  # ディレクトリ別統計
    $script:errorCount = 0
    $script:skippedFolders = @()
    
    # 除外フォルダのパターン作成
    if ($ExcludeFolders.Count -gt 0) {
        Write-Host "Excluding folders: $($ExcludeFolders -join ', ')" -ForegroundColor Gray
        Write-Host ""
    }
}

process {
    # .mdファイルを再帰的に検索
    try {
        $allMdFiles = Get-ChildItem -Path $VaultPath -Recurse -Filter *.md -File -ErrorAction SilentlyContinue
        
        # 除外フォルダのフィルタリング
        $mdFiles = $allMdFiles | Where-Object {
            $filePath = $_.FullName
            $shouldInclude = $true
            # 除外フォルダの判定
            foreach ($excludeFolder in $ExcludeFolders) {
                # フォルダ名がパスに含まれているかチェック
                if ($filePath -like "*\$excludeFolder\*" -or $filePath -like "*/$excludeFolder/*") {
                    $shouldInclude = $false
                    # 除外フォルダリストに追加
                    if ($script:skippedFolders -notcontains $excludeFolder) {
                        $script:skippedFolders += $excludeFolder
                    }
                    break
                }
            }
            $shouldInclude  # trueなら含める
        }
        
        $script:fileCount = $mdFiles.Count  # 合計ファイル数
        
        # ファイルが見つからない場合の警告
        if ($script:fileCount -eq 0) {
            Write-Host "Warning: No Markdown files found in the specified path." -ForegroundColor Yellow
            return
        }
        
        # 進捗表示
        Write-Host "Processing $script:fileCount files..." -ForegroundColor Cyan
        if ($ShowProgress) {
            Write-Host ""
        }
        
        # 各ファイルのサイズを取得
        $processedCount = 0
        foreach ($file in $mdFiles) {
            try {
                $script:totalSize += $file.Length
                $script:fileSizes += [PSCustomObject]@{
                    Name = $file.FullName
                    SizeKB = [math]::Round($file.Length / 1KB, 2)
                }
                
                # ディレクトリ別統計
                $relativePath = $file.DirectoryName.Replace($VaultPath, "").TrimStart('\', '/')
                if ([string]::IsNullOrEmpty($relativePath)) {
                    $relativePath = "(ルート)"
                }
                
                # 最上位ディレクトリ名を取得
                $dirName = $relativePath.Split([IO.Path]::DirectorySeparatorChar)[0]
                if ([string]::IsNullOrEmpty($dirName)) {
                    $dirName = "(ルート)"
                }
                
                # ディレクトリ統計の初期化と更新
                if (-not $script:dirStats.ContainsKey($dirName)) {
                    $script:dirStats[$dirName] = @{
                        FileCount = 0
                        TotalSize = 0
                    }
                }
                $script:dirStats[$dirName].FileCount++  # ファイル数カウント
                $script:dirStats[$dirName].TotalSize += $file.Length    # サイズ合計
                
                # 進捗表示
                $processedCount++
                if ($ShowProgress -and ($processedCount % 100 -eq 0)) { # 100ファイルごとに表示
                    Write-Host "Processed: $processedCount / $script:fileCount files..." -ForegroundColor Gray
                }
                
            } catch {
                $script:errorCount++
                Write-Host "Warning: Could not process file: $($file.FullName)" -ForegroundColor Yellow
            }
        }
        
        # 最終進捗表示
        if ($ShowProgress -and $processedCount -gt 0) {
            Write-Host "Completed: $processedCount files processed." -ForegroundColor Green
            Write-Host ""
        }
        
    } catch {
        Write-Host "Error accessing files: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

end {
    # ファイルが見つからなかった場合は終了
    if ($script:fileCount -eq 0) {
        exit 0
    }
    
    # トークン数の見積もり（実際のファイルサイズに基づく）
    # ファイルサイズ（バイト）→ 文字数（UTF-8想定で概算）→ トークン数
    $estimatedChars = $script:totalSize / 2  # UTF-8で日本語は平均2-3バイト/文字
    $estimatedInputTokens = [math]::Ceiling($estimatedChars / $CharsPerToken)
    $estimatedOutputTokens = [math]::Ceiling($estimatedInputTokens * $OutputTokenRatio)
    $estimatedTotalTokens = $estimatedInputTokens + $estimatedOutputTokens
    
    # コストの計算（入力トークンのみ、または入力+出力）
    $estimatedInputCost = ($estimatedInputTokens / 1000000) * $CostPerMillionTokens
    $estimatedOutputCost = 0
    
    # 出力トークンがある場合のコスト計算
    if ($OutputTokenRatio -gt 0) {
        # 出力トークンのコストは通常入力の3倍程度
        $outputCostMultiplier = 3
        $estimatedOutputCost = ($estimatedOutputTokens / 1000000) * $CostPerMillionTokens * $outputCostMultiplier
    }
    
    # 合計コスト
    $estimatedTotalCost = $estimatedInputCost + $estimatedOutputCost
    
    # 結果を表示
    Write-Host "===== Analysis Results =====" -ForegroundColor Green
    Write-Host "Markdown files found: $script:fileCount"
    Write-Host "Total size: $([math]::Round($script:totalSize / 1MB, 2)) MB"
    Write-Host "Average file size: $([math]::Round($script:totalSize / $script:fileCount / 1KB, 2)) KB"
    
    # エラー数と除外フォルダの表示
    if ($script:errorCount -gt 0) {
        Write-Host "Files with errors: $script:errorCount" -ForegroundColor Yellow
    }
    if ($script:skippedFolders.Count -gt 0) {
        Write-Host "Excluded folders found: $($script:skippedFolders -join ', ')" -ForegroundColor Gray
    }
    
    # トークン数とコストの表示
    Write-Host ""
    Write-Host "Estimated input tokens: $($estimatedInputTokens.ToString('N0'))"
    
    # 出力トークンがある場合の表示
    if ($OutputTokenRatio -gt 0) {
        Write-Host "Estimated output tokens: $($estimatedOutputTokens.ToString('N0'))"
        Write-Host "Estimated total tokens: $($estimatedTotalTokens.ToString('N0'))"
        Write-Host ""
        Write-Host "Estimated input cost (USD): `$$([math]::Round($estimatedInputCost, 4))"
        Write-Host "Estimated output cost (USD): `$$([math]::Round($estimatedOutputCost, 4))"
        Write-Host "Estimated total cost (USD): `$$([math]::Round($estimatedTotalCost, 4))" -ForegroundColor Yellow
    } else {
        Write-Host "Estimated cost (USD): `$$([math]::Round($estimatedInputCost, 4))" -ForegroundColor Yellow
    }
    
    # 追加情報の表示
    Write-Host ""
    Write-Host "Note: This is a rough estimate based on file size." -ForegroundColor Gray
    Write-Host "Actual token count may vary depending on content and encoding." -ForegroundColor Gray
    if ($OutputTokenRatio -gt 0) {
        Write-Host "Output cost uses 3x multiplier (typical GPT pricing model)." -ForegroundColor Gray
    }
    Write-Host ""
    
    # 複数モデルの比較表示
    if ($ShowModelComparison) {
        Write-Host "===== Model Cost Comparison =====" -ForegroundColor Green
        $models = @(
            @{Name="GPT-4o"; InputCost=2.50; OutputCost=10.00},
            @{Name="GPT-4o-mini"; InputCost=0.15; OutputCost=0.60},
            @{Name="GPT-3.5-turbo"; InputCost=0.50; OutputCost=1.50}
        )
        
        # 各モデルのコスト計算と表示
        foreach ($model in $models) {
            $modelInputCost = ($estimatedInputTokens / 1000000) * $model.InputCost
            # 出力トークンがある場合の計算
            if ($OutputTokenRatio -gt 0) {
                $modelOutputCost = ($estimatedOutputTokens / 1000000) * $model.OutputCost
                $modelTotalCost = $modelInputCost + $modelOutputCost
                Write-Host "$($model.Name): `$$([math]::Round($modelTotalCost, 4)) (Input: `$$([math]::Round($modelInputCost, 4)) + Output: `$$([math]::Round($modelOutputCost, 4)))" -ForegroundColor Cyan
            } else {
                Write-Host "$($model.Name): `$$([math]::Round($modelInputCost, 4))" -ForegroundColor Cyan
            }
        }
        Write-Host ""
    }
    
    # ディレクトリ別統計を表示
    if ($script:dirStats.Count -gt 0) {
        Write-Host "===== Directory Statistics =====" -ForegroundColor Green
        $sortedDirs = $script:dirStats.GetEnumerator() | Sort-Object {$_.Value.TotalSize} -Descending
        # 各ディレクトリの統計を表示
        foreach ($dir in $sortedDirs) {
            $sizeMB = [math]::Round($dir.Value.TotalSize / 1MB, 2)
            Write-Host "  $($dir.Key): $($dir.Value.FileCount) files, $sizeMB MB" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # 最も大きいファイルTop N を表示
    Write-Host "Top $ShowTopFiles largest files:" -ForegroundColor Cyan
    $script:fileSizes | Sort-Object -Property SizeKB -Descending | Select-Object -First $ShowTopFiles | ForEach-Object {
        Write-Host "  $($_.SizeKB) KB - $($_.Name)" -ForegroundColor Gray
    }
    
    # ファイルへの出力
    if (-not [string]::IsNullOrEmpty($ExportToFile)) {
        try {
            $exportData = [PSCustomObject]@{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                VaultPath = $VaultPath
                FileCount = $script:fileCount
                ErrorCount = $script:errorCount
                TotalSizeMB = [math]::Round($script:totalSize / 1MB, 2)
                AverageFileSizeKB = [math]::Round($script:totalSize / $script:fileCount / 1KB, 2)
                EstimatedInputTokens = $estimatedInputTokens
                EstimatedOutputTokens = $estimatedOutputTokens
                EstimatedTotalTokens = $estimatedTotalTokens
                EstimatedInputCostUSD = [math]::Round($estimatedInputCost, 4)
                EstimatedOutputCostUSD = [math]::Round($estimatedOutputCost, 4)
                EstimatedTotalCostUSD = [math]::Round($estimatedTotalCost, 4)
                CharsPerToken = $CharsPerToken
                CostPerMillionTokens = $CostPerMillionTokens
                OutputTokenRatio = $OutputTokenRatio
                ExcludedFolders = ($ExcludeFolders -join ',')
                TopDirectories = ($script:dirStats.GetEnumerator() | Sort-Object {$_.Value.TotalSize} -Descending | Select-Object -First 5 | ForEach-Object {"$($_.Key):$($_.Value.FileCount)files"}) -join ','
            }
            
            # エクスポート形式に応じた出力
            if ($ExportToFile -like "*.json") {
                $exportData | ConvertTo-Json | Out-File -FilePath $ExportToFile -Encoding utf8
                Write-Host ""
                Write-Host "Results exported to: $ExportToFile" -ForegroundColor Green
            } elseif ($ExportToFile -like "*.csv") {
                $exportData | Export-Csv -Path $ExportToFile -NoTypeInformation -Encoding utf8
                Write-Host ""
                Write-Host "Results exported to: $ExportToFile" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "Warning: Unsupported file format. Use .csv or .json extension." -ForegroundColor Yellow
            }
        } catch {
            Write-Host ""
            Write-Host "Error exporting to file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # 終了前に一時停止
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
