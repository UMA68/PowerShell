<#
.SYNOPSIS
    ファイルのアクセスブロックを解除します。

.DESCRIPTION
    指定されたディレクトリ内のファイルから Zone.Identifier ストリームを削除し、
    ダウンロードされたファイルのブロックを解除します。
    
    主な機能:
    - Zone.Identifier代替データストリームの自動検出と削除
    - 複数ファイルの一括処理（再帰的スキャン）
    - 拡張子・フォルダパターンによる除外設定
    - 詳細な処理結果サマリ（解除/既存/エラー/失敗件数）
    - 二重起動防止機能
    - COM オブジェクトの安全な管理
    - エラーハンドリングと詳細ログ出力
    
    スクリプトは以下の順序で実行されます:
    1. パラメータ検証（ValidateScript属性）
    2. 二重起動チェック（ミューテックスベース）
    3. 共通スクリプトのインポート（NoDoubleActivation.ps1, Write-CommonLog.ps1）
    4. ログディレクトリの作成
    5. 対象ディレクトリの存在確認
    6. Unblock-Fileコマンドレットの可用性確認
    7. ファイルの再帰的スキャンと処理
       - Zone.Identifierストリーム存在確認
       - Unblock-File実行（存在する場合）
       - エラーハンドリング（FileNotFoundException/アクセスエラー）
    8. 処理結果サマリの出力
    9. ログファイルの自動表示

.PARAMETER TargetFolder
    処理対象のフォルダ名（相対パス）。デフォルトは "FileAccessBlock" です。
    
    パラメータ検証:
    - 空白文字のみの入力を拒否
    - ファイル名に使用できない文字（\ / : * ? " < > |）を検証
    - 最大255文字の長さ制限

.PARAMETER LogPrefix
    ログファイル名のプレフィックス。デフォルトは "unblock_" です。
    ログファイル名は "{LogPrefix}yyyyMMdd-HHmmss.log" 形式で生成されます。
    
    パラメータ検証:
    - 空白文字のみの入力を拒否
    - ファイル名に使用できない文字を検証
    - 最大255文字の長さ制限

.PARAMETER ExcludeExtensions
    除外する拡張子の配列。デフォルトは @('.log', '.xlsx') です。
    指定された拡張子を持つファイルは処理対象から除外されます。

.PARAMETER ExcludeFolderPattern
    除外するフォルダパターン（正規表現）。デフォルトは '\\Script\\' です。
    パターンに一致するパスを持つファイルは処理対象から除外されます。
    
    パラメータ検証:
    - 正規表現として妥当かどうかを検証

.PARAMETER VerboseLogging
    詳細ログ出力を有効にします。
    有効時は、Zone.Identifierが存在しないファイルも含めて
    すべてのファイルの処理状況をログに記録します。

.EXAMPLE
    .\unblock_files.ps1
    デフォルト設定でFileAccessBlockフォルダ内のファイルのブロックを解除します。

.EXAMPLE
    .\unblock_files.ps1 -TargetFolder "Downloads" -ExcludeExtensions @('.txt', '.pdf')
    Downloadsフォルダを対象に、.txtと.pdfを除外してブロックを解除します。

.EXAMPLE
    .\unblock_files.ps1 -VerboseLogging
    詳細ログモードでFileAccessBlockフォルダを処理します。
    Zone.Identifierが存在しないファイルもログに記録されます。

.EXAMPLE
    .\unblock_files.ps1 -TargetFolder "MyFiles" -ExcludeFolderPattern "\\(Backup|Archive)\\" -LogPrefix "mylog_"
    MyFilesフォルダを対象に、BackupとArchiveフォルダを除外し、
    ログファイル名を "mylog_yyyyMMdd-HHmmss.log" で生成します。

.NOTES
    File Name      : unblock_files.ps1
    Author         : UMA68
    Version        : 2.1.0
    Release Date   : 2025-12-12
    Last Modified  : 2025-12-12
    
    前提条件:
    - PowerShell 7.3.9 以上
    - Windows PowerShell実行ポリシー: RemoteSigned 以上
    - Unblock-Fileコマンドレットの利用可能性
    
    依存ファイル:
    - Common/NoDoubleActivation.ps1 : 二重起動防止機能
    - Common/Write-CommonLog.ps1    : ログ出力関数
    
    ディレクトリ構造:
    PowerShell/
    ├── Common/
    │   ├── NoDoubleActivation.ps1
    │   └── Write-CommonLog.ps1
    └── ファイルアクセスブロック解除/
        ├── Script/
        │   └── unblock_files.ps1  (このファイル)
        ├── FileAccessBlock/        (デフォルト処理対象)
        │   └── TEST_A.txt
        └── LOG/                     (ログ自動作成先)
            └── unblock_YYYYMMDD-HHmmss.log
    
    処理結果サマリ:
    - Total files processed        : 処理対象ファイルの総数
    - Files unblocked              : Zone.Identifierを削除したファイル数
    - Files already unblocked      : 元々Zone.Identifierが無いファイル数
    - Files with access errors     : ストリームアクセス時にエラーが発生したファイル数
    - Files failed to unblock      : Unblock-File実行時にエラーが発生したファイル数
    - Success rate                 : 成功率（%）
    
    変更履歴:
    v2.1.0 (2025-12-12)
        - FileNotFoundException例外ハンドリング追加（Zone.Identifier不在時）
        - accessErrorFilesカウンターの明確化（skippedFilesから変更）
        - ログメッセージの改善（"Files with access errors"）
        - ヘルプドキュメントの拡充（処理フロー、サマリ説明追加）
    
    v2.0.0 (2025-12-12)
        - パラメータ検証の追加（ValidateScript属性）
        - 変数スコープの統一（$script: プレフィックス）
        - exit文をreturnに変更（end ブロック確実実行）
        - COM オブジェクト管理の改善（スクリプトブロック化）
        - ログ出力の改善（設定パラメータ出力、処理時間形式統一）
        - CanExecuteProcessフラグ導入（earlyExit簡素化）
        - 正規表現検証をパラメータレベルに移行
    
    v1.0.0 (初版)
        - 基本的なファイルブロック解除機能実装
        - Zone.Identifierストリーム検出と削除
        - 再帰的ファイルスキャン
        - 拡張子・フォルダパターン除外機能

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    Wiki: https://github.com/UMA68/PowerShell/wiki
#>
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if ([string]::IsNullOrWhiteSpace($_)) { throw "TargetFolder cannot be empty or whitespace." }
        if ($_ -match '[\\/:*?"<>|]') { throw "TargetFolder contains invalid characters." }
        if ($_.Length -gt 255) { throw "TargetFolder exceeds 255 characters." }
        $true
    })]
    [string]$TargetFolder = "FileAccessBlock",
    
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if ([string]::IsNullOrWhiteSpace($_)) { throw "LogPrefix cannot be empty or whitespace." }
        if ($_ -match '[\\/:*?"<>|]') { throw "LogPrefix contains invalid characters." }
        if ($_.Length -gt 255) { throw "LogPrefix exceeds 255 characters." }
        $true
    })]
    [string]$LogPrefix = "unblock_",
    
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeExtensions = @('.log', '.xlsx'),
    
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        try {
            [void]($_ -match $_)
            $true
        } catch {
            throw "ExcludeFolderPattern is not a valid regular expression: $_"
        }
    })]
    [string]$ExcludeFolderPattern = '\\Script\\',
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseLogging = $false
)

begin{
    # COMオブジェクト管理用スクリプトブロック（relMain.ps1と同様のパターン）
    $script:ShowPopup = {
        param([string]$Message, [string]$Title)
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($Message, 0, $Title, 0x30) | Out-Null
        } finally {
            if ($null -ne $obj) {
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
    }
    
    # スクリプトの実行環境を取得
    $script:scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $script:UpperPath = Split-Path -Parent $script:scriptPath
    $script:PowerShellDir = Split-Path -Parent $script:UpperPath
    $script:folderPath = Join-Path -Path $script:UpperPath -ChildPath $TargetFolder
    $script:comPath = Join-Path -Path $script:PowerShellDir -ChildPath "Common"

    # 共通スクリプトのインポート
    try{
        . (Join-Path -Path $script:comPath -ChildPath "NoDoubleActivation.ps1") -ErrorAction Stop
        . (Join-Path -Path $script:comPath -ChildPath "Write-CommonLog.ps1") -ErrorAction Stop  
    }catch{
        & $script:ShowPopup -Message "PowerShell ファイルを読み込めませんでした。処理を終了します。`r`n`r`n$($_.Exception.Message)" -Title "Module Check"
        return
    }
    
    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "unblock_files"
    
    # ユーザーとホスト名の取得
    $script:UserName = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME
    
    # ログの保存先を指定
    $script:logFilePath = Join-Path -Path $script:UpperPath -ChildPath ($LogPrefix+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")
    
    # ログディレクトリが存在しなければ作成
    $logDir = Split-Path -Parent $script:logFilePath
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    
    # 処理結果カウンタの初期化
    $script:totalFiles = 0
    $script:unblockedFiles = 0
    $script:failedFiles = 0
    $script:alreadyUnblockedFiles = 0
    $script:accessErrorFiles = 0  # アクセスエラーでストリームを確認できなかったファイル
    $script:startTime = Get-Date
    $script:CanExecuteProcess = $true  # 処理実行フラグ（relMain.ps1パターン）
}
process{
    # ログ記録開始
    Write-CommonLog -Message "Script started." -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "HOST: $script:HostName" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "USER: $script:UserName" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Target directory: $script:folderPath" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Exclude extensions: $($ExcludeExtensions -join ', ')" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Exclude folder pattern: $ExcludeFolderPattern" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Verbose logging: $VerboseLogging" -LogPath $script:logFilePath -Level "INFO"

    # 対象ディレクトリの存在確認
    if (-not (Test-Path -Path $script:folderPath)) {
        Write-CommonLog -Message "Target directory does not exist: $script:folderPath" -LogPath $script:logFilePath -Level "ERROR"
        $script:CanExecuteProcess = $false
        return
    }

    # Unblock-Fileコマンドレットが存在しなければ終了
    if (-not (Get-Command -Name Unblock-File -ErrorAction SilentlyContinue)) {
        Write-CommonLog -Message "Unblock-File command not found. Please ensure you are running this script in a PowerShell environment that supports it." -LogPath $script:logFilePath -Level "ERROR"
        $script:CanExecuteProcess = $false
        return
    }
    # 対象となるファイルの取得と処理
    Get-ChildItem -Path $script:folderPath -Recurse -File |
        Where-Object {
            $_.FullName -notmatch $ExcludeFolderPattern -and
            $_.Extension -notin $ExcludeExtensions
        } |  # 除外パターンに一致するフォルダとファイルを除外
        ForEach-Object {
            $script:totalFiles++
            
            # 100ファイルごとに進捗を表示
            if ($script:totalFiles % 100 -eq 0) {
                Write-CommonLog -Message "Progress: $script:totalFiles files processed..." -LogPath $script:logFilePath -Level "INFO"
            }
            
            $filePath = $_.FullName
            # Zone.Identifierストリームの存在確認（エラーハンドリング付き）
            try {
                $hasZoneId = Get-Item -Path $filePath -Stream "Zone.Identifier" -ErrorAction Stop
            } catch [System.IO.FileNotFoundException] {
                # Zone.Identifierが存在しない（正常）
                $hasZoneId = $null
            } catch [System.Management.Automation.ItemNotFoundException] {
                # Zone.Identifierが存在しない（正常・代替パターン）
                $hasZoneId = $null
            } catch {
                # アクセスエラーなど
                Write-CommonLog -Message "Cannot access file stream: $filePath" -LogPath $script:logFilePath -Level "WARN"
                Write-CommonLog -Message "Error Type: $($_.Exception.GetType().FullName)" -LogPath $script:logFilePath -Level "WARN"
                Write-CommonLog -Message "Error: $($_.Exception.Message)" -LogPath $script:logFilePath -Level "WARN"
                $script:accessErrorFiles++
                return
            }
            # Zone.Identifierストリームが存在する場合、Unblock-Fileを実行
            if ($hasZoneId) {
                try{
                    # Unblock-Fileコマンドレット実行
                    Write-CommonLog -Message "Zone.Identifier found for file: $filePath. Unblocking file." -LogPath $script:logFilePath -Level "WARN"
                    Unblock-File -Path $filePath -ErrorAction Stop
                    Write-CommonLog -Message "File unblocked: $filePath" -LogPath $script:logFilePath -Level "WARN"
                    $script:unblockedFiles++
                } catch {
                    # ブロック解除に失敗しました
                    Write-CommonLog -Message "Failed to unblock file: $filePath" -LogPath $script:logFilePath -Level "ERROR"
                    Write-CommonLog -Message "Error Type: $($_.Exception.GetType().FullName)" -LogPath $script:logFilePath -Level "ERROR"
                    Write-CommonLog -Message "Error: $($_.Exception.Message)" -LogPath $script:logFilePath -Level "ERROR"
                    $script:failedFiles++
                }
            # Zone.Identifierストリームが存在しない場合
            } else {
                if ($VerboseLogging) {
                    Write-CommonLog -Message "No Zone.Identifier found for file: $filePath" -LogPath $script:logFilePath -Level "INFO"
                }
                $script:alreadyUnblockedFiles++
            }
       }
    
    # 処理対象ファイルが0件の場合の通知
    if ($script:totalFiles -eq 0) {
        Write-CommonLog -Message "No files found in the target directory." -LogPath $script:logFilePath -Level "WARN"
    }
}
end{
    # 処理終了時刻と処理時間の計算
    $script:endTime = Get-Date
    $script:elapsedTime = $script:endTime - $script:startTime
    
    # 早期終了の場合はその旨を出力
    if (-not $script:CanExecuteProcess) {
        Write-CommonLog -Message "Script terminated early due to error." -LogPath $script:logFilePath -Level "ERROR"
    }
    
    # 処理結果のサマリーを出力
    Write-CommonLog -Message "===== Processing Summary =====" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Total files processed: $script:totalFiles" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Files unblocked: $script:unblockedFiles" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Files already unblocked: $script:alreadyUnblockedFiles" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Files with access errors: $script:accessErrorFiles" -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "Files failed to unblock: $script:failedFiles" -LogPath $script:logFilePath -Level "INFO"
    
    # 成功率の計算と出力
    if ($script:totalFiles -gt 0) { # 成功率計算の分母が0になるのを防止
        $successCount = $script:unblockedFiles + $script:alreadyUnblockedFiles
        $successRate = [math]::Round(($successCount / $script:totalFiles) * 100, 2)
        Write-CommonLog -Message "Success rate: $successRate%" -LogPath $script:logFilePath -Level "INFO"
    }
    
    Write-CommonLog -Message ("Processing time: {0:D2}:Min {1:D2}:Sec" -f $script:elapsedTime.Minutes, $script:elapsedTime.Seconds) -LogPath $script:logFilePath -Level "INFO"
    Write-CommonLog -Message "==============================" -LogPath $script:logFilePath -Level "INFO"
    
    # ログ記録終了
    Write-CommonLog -Message "Script ended." -LogPath $script:logFilePath -Level "INFO"
    
    # ログファイルを開く
    Invoke-Item -Path $script:logFilePath
}