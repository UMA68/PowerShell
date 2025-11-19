function Import-YamlConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$YamlPath
    )
    
    if (-not (Test-Path -Path $YamlPath)) {
        throw "YAMLファイルが存在しません: $YamlPath"
    }
    
    try {
        return Get-Content $YamlPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    } catch {
        throw "YAMLファイルの読み込みに失敗: $_"
    }


    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if (Get-Variable -Name NoDoubleActivation_Mutex -Scope Global -ErrorAction SilentlyContinue) {
            $global:NoDoubleActivation_Mutex.ReleaseMutex()
            $global:NoDoubleActivation_Mutex.Close()
        }
    } -SupportEvent -MessageData "NoDoubleActivation_Event"
}