# ================================================
# ログの書き込み関数
# Log-Output -Message "String" -LogPath "LogFullPath"
# ================================================
function Log-Output {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$LogPath
    )

    echo $Message | Tee-Object -FilePath $LogPath -Append | Out-Default
}

