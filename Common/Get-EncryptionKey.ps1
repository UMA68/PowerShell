function Get-EncryptionKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyPath
    )
    
    if (-not (Test-Path -Path $KeyPath)) {
        throw "鍵ファイル「$KeyPath」が見つかりません。"
    }
    
    return [System.IO.File]::ReadAllBytes($KeyPath)

    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if (Get-Variable -Name NoDoubleActivation_Mutex -Scope Global -ErrorAction SilentlyContinue) {
            $global:NoDoubleActivation_Mutex.ReleaseMutex()
            $global:NoDoubleActivation_Mutex.Close()
        }
    } -SupportEvent -MessageData "NoDoubleActivation_Event"
}