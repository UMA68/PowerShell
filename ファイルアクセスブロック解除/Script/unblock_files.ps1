<#
.SYNOPSIS
    ファイルのアクセスブロックを解除します。

.DESCRIPTION
    指定されたディレクトリ内のファイルから Zone.Identifier ストリームを削除し、
    ダウンロードされたファイルのブロックを解除します。

.PARAMETER TargetFolder
    処理対象のフォルダ名（相対パス）。デフォルトは "FileAccessBlock" です。

.PARAMETER LogPrefix
    ログファイル名のプレフィックス。デフォルトは "unblock_" です。

.PARAMETER ExcludeExtensions
    除外する拡張子の配列。デフォルトは @('.log', '.xlsx') です。

.PARAMETER ExcludeFolderPattern
    除外するフォルダパターン（正規表現）。デフォルトは '\\Script\\' です。

.PARAMETER VerboseLogging
    詳細ログ出力を有効にします。すべてのファイルの処理状況をログに記録します。

.EXAMPLE
    .\unblock_files.ps1
    デフォルト設定でFileAccessBlockフォルダ内のファイルのブロックを解除します。

.EXAMPLE
    .\unblock_files.ps1 -TargetFolder "Downloads" -ExcludeExtensions @('.txt', '.pdf')
    Downloadsフォルダを対象に、.txtと.pdfを除外してブロックを解除します。

.NOTES
    File Name      : unblock_files.ps1
    Author         : UMA
    Prerequisite   : PowerShell
#>
param(
    [Parameter(Mandatory=$false)]
    [string]$TargetFolder = "FileAccessBlock",  # デフォルトはFileAccessBlock
    [Parameter(Mandatory=$false)]
    [string]$LogPrefix = "unblock_",            # ログファイル名のプレフィックス
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeExtensions = @('.log', '.xlsx'),  # 除外する拡張子
    [Parameter(Mandatory=$false)]
    [string]$ExcludeFolderPattern = '\\Script\\',      # 除外するフォルダパターン（正規表現）
    [Parameter(Mandatory=$false)]
    [switch]$VerboseLogging = $false                    # 詳細ログ出力フラグ
)

begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = Split-Path -Parent $scriptPath                         # スクリプトの親パスを取得
    $PowerShellDir = Split-Path -Parent $UpperPath                      # スクリプトの親パスの親パスを取得
    $folderPath = Join-Path -Path $UpperPath -ChildPath $TargetFolder   # アクセスブロックされたファイルの格納パスを指定
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"       # 共通スクリプトのパス

    # 共通スクリプトのインポート
    try{
        . (Join-Path -Path $comPath -ChildPath "NoDoubleActivation.ps1") -ErrorAction Stop
        . (Join-Path -Path $comPath -ChildPath "Write-CommonLog.ps1") -ErrorAction Stop  
    }catch{
        # スクリプトファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("PowerShell ファイルを読み込めませんでした。処理を終了します。`r`n`r`n"+$_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        exit # 終了
    }
    
    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "unblock_files"
    
    # 正規表現パターンの検証
    try {
        [void]($ExcludeFolderPattern -match $ExcludeFolderPattern)
    } catch {
        Write-Host "Invalid regular expression pattern in ExcludeFolderPattern: $ExcludeFolderPattern" -ForegroundColor Red
        exit
    }
    
    # ユーザーとホスト名の取得
    $script:UserName = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME
    
    # ログの保存先を指定
    $logFilePath = Join-Path -Path $UpperPath -ChildPath ($LogPrefix+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")
    
    # ログディレクトリが存在しなければ作成
    $logDir = Split-Path -Parent $logFilePath
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    
    # 処理結果カウンタの初期化
    $script:totalFiles = 0
    $script:unblockedFiles = 0
    $script:failedFiles = 0
    $script:alreadyUnblockedFiles = 0
    $script:skippedFiles = 0  # アクセスエラーなどでスキップされたファイル
    $script:earlyExit = $false  # 早期終了フラグ
    $script:startTime = Get-Date  # 処理開始時刻
}
process{
    # ログ記録開始
    Write-CommonLog -Message "Script started." -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "HOST: $script:HostName" -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "USER: $script:UserName" -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "Target directory: $folderPath" -LogPath $logFilePath -Level "INFO"

    # 対象ディレクトリの存在確認
    if (-not (Test-Path -Path $folderPath)) {
        Write-CommonLog -Message "Target directory does not exist: $folderPath" -LogPath $logFilePath -Level "ERROR"
        $script:earlyExit = $true
        return
    }

    # Unblock-Fileコマンドレットが存在しなければ終了
    if (-not (Get-Command -Name Unblock-File -ErrorAction SilentlyContinue)) {
        Write-CommonLog -Message "Unblock-File command not found. Please ensure you are running this script in a PowerShell environment that supports it." -LogPath $logFilePath -Level "ERROR"
        $script:earlyExit = $true
        return
    }
    # 対象となるファイルの取得と処理
    Get-ChildItem -Path $folderPath -Recurse -File |
        Where-Object {
            $_.FullName -notmatch $ExcludeFolderPattern -and
            $_.Extension -notin $ExcludeExtensions
        } |  # 除外パターンに一致するフォルダとファイルを除外
        ForEach-Object {
            $script:totalFiles++
            
            # 100ファイルごとに進捗を表示
            if ($script:totalFiles % 100 -eq 0) {
                Write-CommonLog -Message "Progress: $script:totalFiles files processed..." -LogPath $logFilePath -Level "INFO"
            }
            
            $filePath = $_.FullName
            # Zone.Identifierストリームの存在確認（エラーハンドリング付き）
            try {
                $hasZoneId = Get-Item -Path $filePath -Stream "Zone.Identifier" -ErrorAction Stop
            } catch [System.Management.Automation.ItemNotFoundException] {
                # Zone.Identifierが存在しない（正常）
                $hasZoneId = $null
            } catch {
                # アクセスエラーなど
                Write-CommonLog -Message "Cannot access file stream: $filePath" -LogPath $logFilePath -Level "WARN"
                Write-CommonLog -Message "Error Type: $($_.Exception.GetType().FullName)" -LogPath $logFilePath -Level "WARN"
                Write-CommonLog -Message "Error: $($_.Exception.Message)" -LogPath $logFilePath -Level "WARN"
                $script:skippedFiles++
                return
            }
            # Zone.Identifierストリームが存在する場合、Unblock-Fileを実行
            if ($hasZoneId) {
                try{
                    # Unblock-Fileコマンドレット実行
                    Write-CommonLog -Message "Zone.Identifier found for file: $filePath. Unblocking file." -LogPath $logFilePath -Level "WARN"
                    Unblock-File -Path $filePath -ErrorAction Stop
                    Write-CommonLog -Message "File unblocked: $filePath" -LogPath $logFilePath -Level "WARN"
                    $script:unblockedFiles++
                } catch {
                    # ブロック解除に失敗しました
                    Write-CommonLog -Message "Failed to unblock file: $filePath" -LogPath $logFilePath -Level "ERROR"
                    Write-CommonLog -Message "Error Type: $($_.Exception.GetType().FullName)" -LogPath $logFilePath -Level "ERROR"
                    Write-CommonLog -Message "Error: $($_.Exception.Message)" -LogPath $logFilePath -Level "ERROR"
                    $script:failedFiles++
                }
            # Zone.Identifierストリームが存在しない場合
            } else {
                if ($VerboseLogging) {
                    Write-CommonLog -Message "No Zone.Identifier found for file: $filePath" -LogPath $logFilePath -Level "INFO"
                }
                $script:alreadyUnblockedFiles++
            }
       }
    
    # 処理対象ファイルが0件の場合の通知
    if ($script:totalFiles -eq 0) {
        Write-CommonLog -Message "No files found in the target directory." -LogPath $logFilePath -Level "WARN"
    }
}
end{
    # 処理終了時刻と処理時間の計算
    $script:endTime = Get-Date
    $script:elapsedTime = $script:endTime - $script:startTime
    
    # 早期終了の場合はその旨を出力
    if ($script:earlyExit) {
        Write-CommonLog -Message "Script terminated early due to error." -LogPath $logFilePath -Level "ERROR"
    }
    
    # 処理結果のサマリーを出力
    Write-CommonLog -Message "===== Processing Summary =====" -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "Total files processed: $script:totalFiles" -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "Files unblocked: $script:unblockedFiles" -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "Files already unblocked: $script:alreadyUnblockedFiles" -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "Files skipped (access error): $script:skippedFiles" -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "Files failed to unblock: $script:failedFiles" -LogPath $logFilePath -Level "INFO"
    
    # 成功率の計算と出力
    if ($script:totalFiles -gt 0) {
        $successCount = $script:unblockedFiles + $script:alreadyUnblockedFiles
        $successRate = [math]::Round(($successCount / $script:totalFiles) * 100, 2)
        Write-CommonLog -Message "Success rate: $successRate%" -LogPath $logFilePath -Level "INFO"
    }
    
    Write-CommonLog -Message ("Processing time: {0:D2}:Min {1:D2}:Sec" -f $script:elapsedTime.Minutes, $script:elapsedTime.Seconds) -LogPath $logFilePath -Level "INFO"
    Write-CommonLog -Message "==============================" -LogPath $logFilePath -Level "INFO"
    
    # ログ記録終了
    Write-CommonLog -Message "Script ended." -LogPath $logFilePath -Level "INFO"
    
    # ログファイルを開く
    Invoke-Item -Path $logFilePath
}