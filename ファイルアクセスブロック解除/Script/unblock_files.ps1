begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = $scriptPath | Split-Path -Parent                       # スクリプトの親パスを取得
    $PowerShellDir = $UpperPath | Split-Path -Parent                    # スクリプトの親パスの親パスを取得
    $folderPath = $UpperPath + "\FileAccessBlock"                       # アクセスブロックされたファイルの格納パスを指定
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"       # 共通スクリプトのパス

    # 共通スクリプトのインポート
    try{
        . $comPath"\Write-CommonLog.ps1" -ErrorAction Stop  
    }catch{
        # スクリプトファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("PowerShell ファイルを読み込めませんでした。処理を終了します。`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        exit # 終了
    }
    # ログの保存先を指定
    $logFilePath = Join-Path -Path $UpperPath -ChildPath ("unblock_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")
}
process{
    # Start logging
    Write-CommonLog -Message "Script started." -LogPath $logFilePath -Level "INFO"

    # Unblock-Fileコマンドレットが存在しなければ終了
    if (-not (Get-Command -Name Unblock-File -ErrorAction SilentlyContinue)) {
        Write-CommonLog -Message "Unblock-File command not found. Please ensure you are running this script in a PowerShell environment that supports it." -LogPath $logFilePath -Level "ERROR"
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
                    Write-CommonLog -Message "Zone.Identifier found for file: $filePath. Unblocking file." -LogPath $logFilePath -Level "WARN"
                    Unblock-File -Path $filePath -ErrorAction Stop
                    Write-CommonLog -Message "File unblocked: $filePath" -LogPath $logFilePath -Level "WARN"
                } catch {
                    # Unblockに失敗しました
                    Write-CommonLog -Message "Failed to unblock file: $filePath" -LogPath $logFilePath -Level "ERROR"
                    Write-CommonLog -Message "Error: $_" -LogPath $logFilePath -Level "ERROR"
                }

            } else {
                Write-CommonLog -Message "No Zone.Identifier found for file: $filePath" -LogPath $logFilePath -Level "INFO"
            }
       }
}
end{
    # End logging
    Write-CommonLog -Message "Script ended." -LogPath $logFilePath -Level "INFO"
    Invoke-Item -Path $logFilePath
}