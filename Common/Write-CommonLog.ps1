function Write-CommonLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$LogPath,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] - $Message"
    Write-Output $logMessage | Tee-Object -FilePath $LogPath -Append | Out-Default

    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if (Get-Variable -Name NoDoubleActivation_Mutex -Scope Global -ErrorAction SilentlyContinue) {
            $global:NoDoubleActivation_Mutex.ReleaseMutex()
            $global:NoDoubleActivation_Mutex.Close()
        }
    } -SupportEvent -MessageData "NoDoubleActivation_Event"
}
    
