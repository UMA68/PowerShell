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

    Get-ChildItem -Path $folderPath -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '\\Script\\' -and
            $_.Extension -notin @('.log', '.xlsx')
        } |  # Scriptフォルダ配下と.log,.xlsxファイルを除外
        ForEach-Object {
            $filePath = $_.FullName
            if (Get-Item -Path $filePath -Stream "Zone.Identifier" -ErrorAction SilentlyContinue) {
                Log-Message "Zone.Identifier found for file: $filePath. Unblocking file."
                Unblock-File -Path $filePath
                Log-Message "File unblocked: $filePath"
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