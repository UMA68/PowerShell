function Get-ScriptPaths {
    return @{
        # Script = Split-Path -Parent $MyInvocation.MyCommand.Path
        # Upper = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
        # PowerShell = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
        # Common = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))) "Common"
        $scriptDir = Split-Path $MyInvocation.MyCommand.Path    # スクリプト実行ディレクトリ取得
        $UpperDir = Split-Path $scriptDir -Parent               # スクリプト実行ディレクトリの親ディレクトリ取得
        $PowerShellDir = Split-Path $UpperDir -Parent           # PowerShellディレクトリ
        $yamlDir = $UpperDir+"\YAML"                            # Yamlファイル格納ディレクトリ
        $LogDir = $UpperDir+"\Log"                              # Logファイル格納ディレクトリ
        $envPath = $yamlDir+"\"+$envFileName                    # yamlファイルのパス
        $comPath = $PowerShellDir+"\Common"                     # 共通スクリプト格納ディレクトリ
    }

    $null = Register-EngineEvent PowerShell.Exiting -Action {
        if (Get-Variable -Name NoDoubleActivation_Mutex -Scope Global -ErrorAction SilentlyContinue) {
            $global:NoDoubleActivation_Mutex.ReleaseMutex()
            $global:NoDoubleActivation_Mutex.Close()
        }
    } -SourceIdentifier NoDoubleActivation_Event

    # グローバル変数としてイベント登録オブジェクトを保持
    Set-Variable -Name "NoDoubleActivation_Event" -Value $true -Scope Global -Force
}

