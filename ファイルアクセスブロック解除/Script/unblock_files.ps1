begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = $scriptPath | Split-Path -Parent                       # スクリプトの親パスを取得
    $PowerShellDir = $UpperPath | Split-Path -Parent                    # スクリプトの親パスの親パスを取得
    $folderPath = $UpperPath + "\FileAccessBlock"                       # アクセスブロックされたファイルの格納パスを指定

    # ログの保存先を指定
    $logFilePath = Join-Path -Path $UpperPath -ChildPath ("unblock_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")
    
    # Function to log messages with timestamp
    function Log-Message {
        param (
            [string]$message
        )
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "$timestamp - $message"
        Write-Host $logMessage
        Add-Content -Path $logFilePath -Value $logMessage
    }
}

process{
    # Start logging
    Log-Message "Script started."

    # Unblock-Fileコマンドレットが存在しなければ終了
    if (-not (Get-Command -Name Unblock-File -ErrorAction SilentlyContinue)) {
        Log-Message "Unblock-File command not found. Please ensure you are running this script in a PowerShell environment that supports it."
        Invoke-Item -Path $logFilePath
        exit # Exit if Unblock-File is not available
    }

    Get-ChildItem -Path $folderPath -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '\\Script\\' -and
            $_.Extension -notin @('.log', '.xlsx')
        } |  # Scriptフォルダ配下と.log,.xlsxファイルを除外
        ForEach-Object {
            $filePath = $_.FullName
            if (Get-Item -Path $filePath -Stream "Zone.Identifier" -ErrorAction SilentlyContinue) {
                try{
                    # Unblock-Fileコマンドレット実行
                    Log-Message "Zone.Identifier found for file: $filePath. Unblocking file."
                    Unblock-File -Path $filePath -ErrorAction Stop
                    Log-Message "File unblocked: $filePath"
                } catch {
                    # Unblockに失敗しました
                    Log-Message "Failed to unblock file: $filePath"
                    Log-Message "Error: $_"
                }

            } else {
                Log-Message "No Zone.Identifier found for file: $filePath"
            }
       }
}

end{
    # End logging
    Log-Message "Script ended."
    Invoke-Item -Path $logFilePath
}