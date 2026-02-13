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
    - CSV/JSON形式でのエクスポート（TopFiles/TopDirectories含む）
    - 処理進捗のリアルタイム表示（件数＋パーセント）
    - エラー耐性のある処理（個別ファイルエラーをスキップ）
    - 非対話運用オプション（キー待機の無効化）

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
    PricingProfileパラメータで価格プリセットを指定すると、このパラメータは上書きされます。
    参考: GPT-4o = 2.50、GPT-4o-mini = 0.15、GPT-3.5-turbo = 0.50

.PARAMETER ShowTopFiles
    最もサイズが大きいファイルを表示する数。デフォルトは 10 です。
    容量の大きいファイルを特定してコスト削減に役立てることができます。

.PARAMETER ShowModelComparison
    複数のGPTモデル（GPT-4o、GPT-4o-mini、GPT-3.5-turbo）のコスト比較を表示します。
    入力・出力トークンの両方を考慮した正確なコスト比較を提供します。

.PARAMETER ExportToFile
    結果をファイルに出力します。CSVまたはJSON形式を指定できます（例: "result.csv" または "result.json"）。
    タイムスタンプ、トークン数、コスト、Top 5ディレクトリ、Top Nファイルなどの詳細情報を含みます。
    拡張子は .csv または .json のみサポートします。

.PARAMETER OutputTokenRatio
    出力トークン数の入力トークン数に対する比率。デフォルトは 0（出力コストを計算しない）です。
    例: 0.5 は入力の半分の出力トークンを想定します。
    出力トークンコストは入力の3倍で計算されます（GPT標準価格モデル）。

.PARAMETER ExcludeFolders
    除外するフォルダ名の配列。デフォルトは @(".obsidian", ".git", ".trash") です。
    メタデータや一時ファイルを含むフォルダを除外することで、より正確な見積もりが可能です。
    ディレクトリ境界を考慮した安全な判定を行います（正規表現）。

.PARAMETER ShowProgress
    ファイル処理中に進捗を表示します（100ファイルごと）。
    進捗は件数とパーセンテージで表示され、最後に必ず総括が表示されます。
    大規模なVaultで処理状況を把握したい場合に有効です。

.PARAMETER NoKeyWait
    終了時のキー入力待機を無効化します（非対話・スケジューラ運用向け）。
    既定では終了時に「Press any key to exit...」で待機します。

.PARAMETER PricingProfile
    価格プリセットを指定します。入力トークン単価（CostPerMillionTokens）を上書きします。
    指定可能な値: `gpt-4o` (入力 $2.50/1M), `4o-mini` (入力 $0.15/1M), `gpt-3.5` (入力 $0.50/1M)
    このパラメータが指定されるとCostPerMillionTokensは無視されます。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1
    デフォルト設定でコストを見積もります。
    - Vault: $HOME\GitHub\obsidian
    - 入力トークンコスト: GPT-4o ($2.50/1M)
    - 出力トークン: 計算なし

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -VaultPath "C:\MyVault" -PricingProfile 4o-mini
    カスタムパスとGPT-4o-miniの価格プリセットで見積もります。
    入力コストは $0.15/1M tokenで計算されます。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ShowModelComparison
    GPT-4o、GPT-4o-mini、GPT-3.5-turboの3モデルのコスト比較を表示します。
    各モデルの入力コストのみ表示されます。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -OutputTokenRatio 0.5 -ShowModelComparison
    入力トークンの50%の出力トークンを想定し、3モデルの入力+出力の合計コストを比較します。
    出力トークンコストは入力の3倍で計算されます。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ExportToFile "result.csv" -ShowTopFiles 15
    結果をCSVファイルに出力し、Top 15の大容量ファイルを表示します。
    Top 5ディレクトリとTop 15ファイル情報がエクスポートに含まれます。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ShowProgress -ExcludeFolders @(".obsidian", ".git", "drafts")
    進捗表示を有効にし、カスタム除外フォルダを指定して実行します。
    処理状況が100ファイルごと、またはパーセンテージで表示されます。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -ShowModelComparison -ExportToFile "result.json" -ShowTopFiles 20 -OutputTokenRatio 0.3
    すべての機能を使用した詳細分析：
    - 3モデル比較（入力+出力、出力比率30%）
    - JSON形式でエクスポート
    - Top 20の大容量ファイル表示
    - 出力トークンコストも計算

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -NoKeyWait
    タスクスケジューラなどの非対話実行時に、終了時のキー待機を無効化します。
    スケジューラから呼び出す場合はこのオプションを推奨します。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -InformationAction Continue
    情報ストリーム（Write-Informationの出力）を必ず表示します。
    `$InformationPreference` が SilentlyContinue などに変わっている環境向け。

.EXAMPLE
    .\count_md_files_and_estimate_cost.ps1 -PricingProfile gpt-4o -OutputTokenRatio 0.5 -ShowModelComparison
    GPT-4o価格プリセット($2.50/1M)を適用し、出力トークン比率50%でモデル比較を実行します。

.NOTES
    File Name      : count_md_files_and_estimate_cost.ps1
    Author         : UMA
    Prerequisite   : PowerShell 5.0以上
    Cost Reference : https://openai.com/api/pricing/
    Version        : v1.1.0
    
    主要機能:
    - ディレクトリ別統計表示（サイズ順にソート）
    - 複数モデルのコスト比較（GPT-4o、GPT-4o-mini、GPT-3.5-turbo）
    - 入力・出力トークンの個別・合計コスト計算
    - CSV/JSON形式でのエクスポート（TopFiles/TopDirectoriesを含む詳細統計）
    - 最大ファイルサイズTop N表示（デフォルト10件、最大1000件）
    - 不要フォルダの自動除外（.obsidian、.git、.trash）
    - 進捗表示機能（100ファイルごと／パーセンテージ付き）
    - エラー耐性処理（個別ファイルエラーをスキップして続行）
    - 実行終了時の一時停止機能（-NoKeyWaitで無効化可能）
    - ホワイトスペース標準化対応（PSScriptAnalyzer準拠）
    
    価格情報（2024年時点）:
    GPT-4o        : 入力 $2.50/1M tokens, 出力 $10.00/1M tokens
    GPT-4o-mini   : 入力 $0.15/1M tokens, 出力 $0.60/1M tokens
    GPT-3.5-turbo : 入力 $0.50/1M tokens, 出力 $1.50/1M tokens
    
    トークン推定方法:
    ファイルサイズ(bytes) ÷ 2 (UTF-8推定) ÷ CharsPerToken = トークン数
    
    除外フォルダの判定:
    ディレクトリ境界を考慮した正規表現で判定されます。
    例: ".obsidian" は "/path/.obsidian/file.md" に一致しますが
        "/path/obsidian/file.md" には一致しません。
    
    出力トークンコスト計算:
    出力トークンのコスト単価は入力の3倍で計算されます（GPT標準価格モデル）。
    例: -OutputTokenRatio 0.5 で入力100Kトークンの場合
        → 出力50Kトークンを想定
        → 出力コスト = (50K / 1M) × (単価 × 3)

    変更履歴:
    - v1.1.0 (2026-01-19)
      * ホワイトスペース標準化（PSScriptAnalyzer準拠、37個の警告を解消）
      * パラメータセクションの代入演算子前後にスペース追加
      * ValidateSet値の後にスペース追加
      * ハッシュテーブルと配列初期化のスペース修正
      * スクリプトブロック括弧のスペース修正
      * ヘルプドキュメント更新（例を詳細化）
      
    - v1.1.0 (2025-12-12)
      * exitを廃止し安全な終了フローへ移行（endブロックの後処理を保証）
      * 正確な除外フォルダ判定（ディレクトリ境界を考慮した正規表現）
      * 例外型のログ出力を追加（原因調査の精度向上）
      * 進捗表示を強化（パーセンテージ追加と最終サマリの常時表示）
      * 非対話運用オプション -NoKeyWait を追加
      * エクスポートの拡張子検証とTopFilesの出力を追加
#>
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]                      # Vaultのパスが空でないことを検証
    [string]$VaultPath = "$HOME\GitHub\obsidian",   # Obsidian Vaultのパス指定
    [Parameter(Mandatory = $false)]
    [ValidateRange(0.1, [double]::MaxValue)]        # 1トークンあたりの文字数
    [double]$CharsPerToken = 2.5,                   # 日本語の場合は約2-3文字/トークン
    [Parameter(Mandatory = $false)]
    [ValidateRange(0.0001, [double]::MaxValue)]
    [double]$CostPerMillionTokens = 2.50,   # GPT-4o入力価格(100万トークンあたり）（2024年時点）
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]                # 最大表示する大容量ファイル数の範囲
    [int]$ShowTopFiles = 10,                # 最大表示する大容量ファイル数
    [Parameter(Mandatory = $false)]
    [switch]$ShowModelComparison = $false,  # 複数モデル比較表示フラグ
    [Parameter(Mandatory = $false)]
    [string]$ExportToFile = "",     # 結果をエクスポートするファイル名（CSVまたはJSON）
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 10)]          # 出力トークン数の入力トークン数に対する比率の範囲
    [double]$OutputTokenRatio = 0,  # 出力トークン数の入力トークン数に対する比率
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeFolders = @(".obsidian", ".git", ".trash"),   # 除外フォルダ
    [Parameter(Mandatory = $false)]
    [switch]$ShowProgress = $false,  # 進捗表示フラグ
    [Parameter(Mandatory = $false)]
    [switch]$NoKeyWait = $false      # 非対話環境でキー待機を無効化
    ,
    [Parameter(Mandatory = $false)]
    [ValidateSet('gpt-4o', '4o-mini', 'gpt-3.5')]
    [string]$PricingProfile          # 価格プリセット（入力トークン単価を上書き）
)

begin {
    $script:CanExecuteProcess = $true
    # Vaultパスの存在確認
    if (-not (Test-Path -Path $VaultPath)) { # パスが存在しない場合
        Write-Error "Error: Vault path does not exist: $VaultPath"
        $script:CanExecuteProcess = $false
        return
    }
    
    Write-Information "Analyzing Obsidian Vault..."
    Write-Information "Vault Path: $VaultPath"
    Write-Information ""

    # 価格プリセットの適用（入力トークン単価を上書き）
    if ($PSBoundParameters.ContainsKey('PricingProfile') -and -not [string]::IsNullOrEmpty($PricingProfile)) { # 価格プリセットが指定されている場合
        switch ($PricingProfile) {
            'gpt-4o' { $CostPerMillionTokens = 2.50 }
            '4o-mini' { $CostPerMillionTokens = 0.15 }
            'gpt-3.5' { $CostPerMillionTokens = 0.50 }
        }
        Write-Information "Pricing profile applied: $PricingProfile (Input: `$$CostPerMillionTokens per 1M tokens)"
    }
    
    # 統計情報の初期化
    $script:totalSize = 0   # 合計ファイルサイズ（バイト）
    $script:fileCount = 0   # 合計ファイル数
    $script:fileSizes = @() # 各ファイルのサイズ情報オブジェクト配列
    $script:dirStats = @{}  # ディレクトリ別統計
    $script:errorCount = 0  # 処理エラー数
    $script:skippedFolders = @() # 除外フォルダ記録
    
    # 除外フォルダのパターン作成
    if ($ExcludeFolders.Count -gt 0) { # 除外フォルダが指定されている場合
        Write-Information "Excluding folders: $($ExcludeFolders -join ', ')"
        Write-Information ""
    }
}

process {
    # .mdファイルを再帰的に検索
    try {
        $allMdFiles = Get-ChildItem -Path $VaultPath -Recurse -Filter *.md -File -ErrorAction SilentlyContinue
        
        # 除外フォルダのフィルタリング
        $mdFiles = $allMdFiles | Where-Object { # 各ファイルに対して除外フォルダチェック
            $filePath = $_.FullName # ファイルのフルパス
            $shouldInclude = $true  # 初期状態は含む
            foreach ($excludeFolder in $ExcludeFolders) { # 除外フォルダチェック
                $pattern = "(^|[\\/])" + [regex]::Escape($excludeFolder) + "([\\/]|$)"  # ディレクトリ境界を考慮した正規表現
                if ($filePath -match $pattern) { # 除外フォルダに一致
                    $shouldInclude = $false
                    if ($script:skippedFolders -notcontains $excludeFolder) { $script:skippedFolders += $excludeFolder }    # 除外フォルダ記録
                    break
                }
            }
            $shouldInclude  # フィルタ結果を返す
        }
        
        $script:fileCount = $mdFiles.Count  # 合計ファイル数
        
        # ファイルが見つからない場合の警告
        if ($script:fileCount -eq 0) { # ファイルがない場合の終了処理
            Write-Warning "Warning: No Markdown files found in the specified path."
            return
        }
        
        # 進捗表示
        Write-Information "Processing $script:fileCount files..."
        if ($ShowProgress) { Write-Information "" }    # 進捗表示用の空行
        
        # 各ファイルのサイズを取得
        $processedCount = 0
        foreach ($file in $mdFiles) { # 各ファイル処理
            try {
                $script:totalSize += $file.Length       # 合計サイズ加算
                $script:fileSizes += [PSCustomObject]@{ # ファイルサイズ情報オブジェクト
                    Name = $file.FullName
                    SizeKB = [math]::Round($file.Length / 1KB, 2)   # サイズをKB単位で保存
                }
                
                # ディレクトリ別統計
                $relativePath = $file.DirectoryName.Replace($VaultPath, "").TrimStart('\', '/') # Vaultからの相対パス
                if ([string]::IsNullOrEmpty($relativePath)) { # ルート直下の場合
                    $relativePath = "(ルート)"
                }
                
                # 最上位ディレクトリ名を取得
                $dirName = $relativePath.Split([IO.Path]::DirectorySeparatorChar)[0]    # 最上位ディレクトリ
                if ([string]::IsNullOrEmpty($dirName)) { # ルート直下の場合
                    $dirName = "(ルート)"
                }
                
                # ディレクトリ統計の初期化と更新
                if (-not $script:dirStats.ContainsKey($dirName)) { # 初期化
                    $script:dirStats[$dirName] = @{ # ハッシュテーブルで管理
                        FileCount = 0
                        TotalSize = 0
                    }
                }
                $script:dirStats[$dirName].FileCount++  # ファイル数カウント
                $script:dirStats[$dirName].TotalSize += $file.Length    # サイズ合計
                
                # 進捗表示
                $processedCount++
                if ($ShowProgress -and ($processedCount % 100 -eq 0)) { # 100ファイルごとに表示
                    $percent = [math]::Floor(($processedCount / [double]$script:fileCount) * 100)           # パーセント計算
                    Write-Information "Processed: $processedCount / $script:fileCount files ($percent%)..." # 進捗表示
                }
                
            } catch {
                $script:errorCount++
                Write-Warning "Warning: Could not process file: $($file.FullName)"
            }
        }
        
        # 最終進捗表示（小規模でも表示）
        if ($ShowProgress) { # 最終サマリ表示
            $percent = if ($script:fileCount -gt 0) { [math]::Floor(($processedCount / [double]$script:fileCount) * 100) } else { 0 }   # パーセント計算
            Write-Information "Completed: $processedCount / $script:fileCount files ($percent%)"                        # 最終進捗表示
            Write-Information ""
        }
        
    } catch {
        Write-Error "Error accessing files: $($_.Exception.Message)"
        Write-Information "Exception Type: $($_.Exception.GetType().FullName)"
        $script:CanExecuteProcess = $false
        return
    }
}

end {
    if (-not $script:CanExecuteProcess) { # 初期エラー時の終了処理
        if (-not $NoKeyWait) { # 終了時のキー待機
            Write-Information ""; Write-Warning "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        return
    }
    # ファイルが見つからなかった場合は終了
    if ($script:fileCount -eq 0) { # ファイルがない場合の終了処理
        if (-not $NoKeyWait) { # 終了時のキー待機
            Write-Information ""; Write-Warning "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        return
    }
    
    # トークン数の見積もり（実際のファイルサイズに基づく）
    # ファイルサイズ（バイト）→ 文字数（UTF-8想定で概算）→ トークン数
    $estimatedChars = $script:totalSize / 2  # UTF-8で日本語は平均2-3バイト/文字
    $estimatedInputTokens = [math]::Ceiling($estimatedChars / $CharsPerToken)           # 入力トークン数の見積もり
    $estimatedOutputTokens = [math]::Ceiling($estimatedInputTokens * $OutputTokenRatio) # 出力トークン数の見積もり
    $estimatedTotalTokens = $estimatedInputTokens + $estimatedOutputTokens              # 合計トークン数
    
    # コストの計算（入力トークンのみ、または入力+出力）
    $estimatedInputCost = ($estimatedInputTokens / 1000000) * $CostPerMillionTokens # 入力トークンコスト
    $estimatedOutputCost = 0                                                        # 出力トークンコスト初期化
    
    # 出力トークンがある場合のコスト計算
    if ($OutputTokenRatio -gt 0) { # 入力+出力コスト
        # 出力トークンのコストは通常入力の3倍程度
        $outputCostMultiplier = 3
        $estimatedOutputCost = ($estimatedOutputTokens / 1000000) * $CostPerMillionTokens * $outputCostMultiplier
    }
    
    # 合計コスト
    $estimatedTotalCost = $estimatedInputCost + $estimatedOutputCost
    
    # 結果を表示
    Write-Information "===== Analysis Results ====="
    Write-Information "Markdown files found: $script:fileCount"
    Write-Information "Total size: $([math]::Round($script:totalSize / 1MB, 2)) MB"
    Write-Information "Average file size: $([math]::Round($script:totalSize / $script:fileCount / 1KB, 2)) KB"
    
    # エラー数と除外フォルダの表示
    if ($script:errorCount -gt 0) { # エラーがあった場合の表示
        Write-Warning "Files with errors: $script:errorCount"
    }
    if ($script:skippedFolders.Count -gt 0) { # 除外フォルダがある場合の表示
        Write-Information "Excluded folders found: $($script:skippedFolders -join ', ')"
    }
    
    # トークン数とコストの表示
    Write-Information ""
    Write-Information "Estimated input tokens: $($estimatedInputTokens.ToString('N0'))"
    
    # 出力トークンがある場合の表示
    if ($OutputTokenRatio -gt 0) { # 入力+出力トークンの場合
        Write-Information "Estimated output tokens: $($estimatedOutputTokens.ToString('N0'))"
        Write-Information "Estimated total tokens: $($estimatedTotalTokens.ToString('N0'))"
        Write-Information ""
        Write-Information "Estimated input cost (USD): `$$([math]::Round($estimatedInputCost, 4))"
        Write-Information "Estimated output cost (USD): `$$([math]::Round($estimatedOutputCost, 4))"
        Write-Information "Estimated total cost (USD): `$$([math]::Round($estimatedTotalCost, 4))"
    } else { # 入力トークンのみの場合の表示
        Write-Information ""
        Write-Information "Estimated cost (USD): `$$([math]::Round($estimatedInputCost, 4))"
    }
    
    # 追加情報の表示
    Write-Information ""
    Write-Information "Note: This is a rough estimate based on file size."
    Write-Information "Actual token count may vary depending on content and encoding."
    if ($OutputTokenRatio -gt 0) { # 出力トークンがある場合の注意書き
        Write-Information "Output cost uses 3x multiplier (typical GPT pricing model)."
    }
    Write-Information ""
    
    # 複数モデルの比較表示
    if ($ShowModelComparison) { # モデル比較表示フラグが有効な場合
        Write-Information "===== Model Cost Comparison ====="
        $models = @(
            @{ Name = "GPT-4o"; InputCost = 2.50; OutputCost = 10.00 },
            @{ Name = "GPT-4o-mini"; InputCost = 0.15; OutputCost = 0.60 },
            @{ Name = "GPT-3.5-turbo"; InputCost = 0.50; OutputCost = 1.50 }
        )
        
        # 各モデルのコスト計算と表示
        foreach ($model in $models) { # モデルごとに計算
            $modelInputCost = ($estimatedInputTokens / 1000000) * $model.InputCost
            # 出力トークンがある場合の計算
            if ($OutputTokenRatio -gt 0) { # 入力+出力コスト
                $modelOutputCost = ($estimatedOutputTokens / 1000000) * $model.OutputCost
                $modelTotalCost = $modelInputCost + $modelOutputCost
                Write-Information "$($model.Name): `$$([math]::Round($modelTotalCost, 4)) (Input: `$$([math]::Round($modelInputCost, 4)) + Output: `$$([math]::Round($modelOutputCost, 4)))"
            } else { # 入力コストのみ
                Write-Information "$($model.Name): `$$([math]::Round($modelInputCost, 4))"
            }
        }
        Write-Information ""
    }
    
    # ディレクトリ別統計を表示
    if ($script:dirStats.Count -gt 0) { # ディレクトリ統計が存在する場合
        Write-Information "===== Directory Statistics ====="
        $sortedDirs = $script:dirStats.GetEnumerator() | Sort-Object { $_.Value.TotalSize } -Descending
        # 各ディレクトリの統計を表示
        foreach ($dir in $sortedDirs) { # ディレクトリ名、ファイル数、合計サイズ(MB)
            $sizeMB = [math]::Round($dir.Value.TotalSize / 1MB, 2)
            Write-Information "  $($dir.Key): $($dir.Value.FileCount) files, $sizeMB MB"
        }
        Write-Information ""
    }
    
    # 最も大きいファイルTop N を表示
    Write-Information "Top $ShowTopFiles largest files:"
    # 大容量ファイルのリストをサイズ順にソートして表示
    $script:fileSizes | Sort-Object -Property SizeKB -Descending | Select-Object -First $ShowTopFiles | ForEach-Object {
        Write-Information "  $($_.SizeKB) KB - $($_.Name)"
    }
    
    # ファイルへの出力
    if (-not [string]::IsNullOrEmpty($ExportToFile)) { # ExportToFileが指定されている場合
        Write-Information ""
        Write-Information "Exporting results to file..."
        # 拡張子の事前検証
        $ext = [IO.Path]::GetExtension($ExportToFile)
        if (($ext -ne ".json") -and ($ext -ne ".csv")) { # サポート外の拡張子
            Write-Information ""; Write-Warning "Warning: Unsupported file format. Use .csv or .json extension."
        } else { # エクスポート処理
        try {
            $exportData = [PSCustomObject]@{ # エクスポート用オブジェクトの作成
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  # タイムスタンプ
                VaultPath = $VaultPath  # Vaultパス
                FileCount = $script:fileCount   # ファイル数
                ErrorCount = $script:errorCount # エラー数
                TotalSizeMB = [math]::Round($script:totalSize / 1MB, 2) # 合計サイズ(MB)
                AverageFileSizeKB = [math]::Round($script:totalSize / $script:fileCount / 1KB, 2) # 平均ファイルサイズ(KB)
                EstimatedInputTokens = $estimatedInputTokens    # 推定入力トークン数
                EstimatedOutputTokens = $estimatedOutputTokens  # 推定出力トークン数
                EstimatedTotalTokens = $estimatedTotalTokens    # 推定合計トークン数
                EstimatedInputCostUSD = [math]::Round($estimatedInputCost, 4)   # 推定入力コスト(USD)
                EstimatedOutputCostUSD = [math]::Round($estimatedOutputCost, 4) # 推定出力コスト(USD)
                EstimatedTotalCostUSD = [math]::Round($estimatedTotalCost, 4)   # 推定合計コスト(USD)
                CharsPerToken = $CharsPerToken                  # 1トークンあたりの文字数
                CostPerMillionTokens = $CostPerMillionTokens    # 100万トークンあたりのコスト(USD)
                OutputTokenRatio = $OutputTokenRatio            # 出力トークン比率
                ExcludedFolders = ($ExcludeFolders -join ',')   # 除外フォルダ
                # 追加情報 - Top 5ディレクトリ
                TopDirectories = ($script:dirStats.GetEnumerator() | Sort-Object { $_.Value.TotalSize } -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Key):$($_.Value.FileCount)files" }) -join ','
                # 追加情報 - Top Nファイル
                TopFiles = ($script:fileSizes | Sort-Object -Property SizeKB -Descending | Select-Object -First $ShowTopFiles | ForEach-Object { "$($_.SizeKB)KB:$($_.Name)" }) -join ','
            }
            
            # エクスポート形式に応じた出力
            if ($ext -eq ".json") { # JSON形式
                $exportData | ConvertTo-Json | Out-File -FilePath $ExportToFile -Encoding utf8
                Write-Information ""
                Write-Information "Results exported to: $ExportToFile"
            } elseif ($ext -eq ".csv") { # CSV形式
                $exportData | Export-Csv -Path $ExportToFile -NoTypeInformation -Encoding utf8
                Write-Information ""
                Write-Information "Results exported to: $ExportToFile"
            }
        } catch {
            Write-Information ""
            Write-Error "Error exporting to file: $($_.Exception.Message)"
            Write-Information "Exception Type: $($_.Exception.GetType().FullName)"
        }
        }
    }
    
    # 終了前に一時停止
    if (-not $NoKeyWait) { # 非対話環境でない場合
        Write-Information ""
        Write-Warning "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
