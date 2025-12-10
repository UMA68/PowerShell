# ===================================
# 起動オプション
#  -DecryptionKey   鍵ファイル指定
#  -EnvYaml         YAMLファイル指定
# ===================================

param(
    [Parameter(Mandatory=$false)]
    [string]$DecryptionKey = "Encryption.Key" , # オプション無しのデフォルト値
    [Parameter(Mandatory=$false)]
    [string]$EnvYaml = "EnvDEV.yaml"            # DEV環境用:EnvDEV.yaml, STG環境用:EnvSTG.yaml, 本番環境用:EnvPRD.yaml
)
begin{
    # エラーメッセージ定数（YAML読み込み前）
    $ErrorMessages = @{
        ScriptReadError = "I couldn't read the PowerShell file. I'm ending the process."
        ModuleNotInstalled = "Module 'PowerShell-Yaml' is not installed. I'm ending the process."
        ModuleCheckError = "I couldn't execute 'Test-ModuleInstalled'. I'm ending the process."
        YamlReadError = "I couldn't read the YAML file. I'm ending the process."
    }
    
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = Split-Path -Parent $scriptPath                         # スクリプトの親パスを取得
    $PowerShellDir = Split-Path -Parent $UpperPath                      # スクリプトの親パスの親パスを取得
    $YamlPath = Join-Path -Path $UpperPath -ChildPath "YAML" | Join-Path -ChildPath $EnvYaml   # YAMLファイルのフルパスを取得
    # $KeyPath = Join-Path -Path $PowerShellDir -ChildPath "Common" | Join-Path -ChildPath $DecryptionKey    # 鍵ファイルのフルパスを取得（将来使用予定）
    
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"       # 共通スクリプトのパス

    # ユーザの特定
    $script:User = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME

    # .ps1ファイルの読み込み
    try{
        . (Join-Path -Path $PowerShellDir -ChildPath "Common" | Join-Path -ChildPath "FindModule.ps1") -ErrorAction Stop
        . (Join-Path -Path $PowerShellDir -ChildPath "Common" | Join-Path -ChildPath "NoDoubleActivation.ps1") -ErrorAction Stop
        . (Join-Path -Path $comPath -ChildPath "Write-CommonLog.ps1") -ErrorAction Stop
        . (Join-Path -Path $scriptPath -ChildPath "CopyItemCustom.ps1") -ErrorAction Stop
    }catch{
        # スクリプトファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($ErrorMessages.ScriptReadError + "`r`n`r`n" + $_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        $obj = $null
        exit # 終了
    }

    # PowerShell-Yamlモジュールがインストールされていなければ、終了
    try {
        if (-not (Test-ModuleInstalled -ModuleName "PowerShell-Yaml")) {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($ErrorMessages.ModuleNotInstalled, 0, "Module Check", 0x30) | Out-Null
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
            exit # 終了
        }
    }
    catch {
        # Test-ModuleInstalledを実行できない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($ErrorMessages.ModuleCheckError + "`r`n`r`n" + $_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        $obj = $null
        exit # 終了
    }

    # YAMLファイルの読み込み
    try{
        $script:yaml = Get-Content $YamlPath -Delimiter "`0" | ConvertFrom-Yaml -Ordered -ErrorAction Stop
    }catch{
        # YAMLファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($ErrorMessages.YamlReadError + "`r`n`r`n" + $_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        $obj = $null
        exit # 終了
    }
    
    # 機密情報パターンを読み込む
    $script:SensitivePatterns = @()
    if ($script:yaml.SECURITY.SensitivePatterns) {
        $script:SensitivePatterns = $script:yaml.SECURITY.SensitivePatterns
    }
    
    # COM オブジェクト（WScript.Shell）を安全に管理するヘルパー関数
    $script:ShowPopup = {
        param(
            [string]$Message,
            [int]$Buttons = 0,
            [string]$Title = "Information"
        )
        $obj = New-Object -ComObject WScript.Shell
        try {
            return [int]$obj.Popup($Message, 0, $Title, $Buttons)
        } finally {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
    }

    # メッセージ取得関数（YAMLから言語に応じたメッセージを取得）
    $script:GetMessage = {
        param(
            [string]$Key
        )
        # スクリプトブロックの可変長引数は$argsに入る
        $Arguments = $args
        $lang = $script:yaml.MESSAGES.LANGUAGE
        $message = $script:yaml.MESSAGES.$lang.$Key
        
        # メッセージがない場合はキーをそのまま返す
        if ([string]::IsNullOrEmpty($message)) {
            return $Key
        }
        
        # YAMLのエスケープシーケンスを実際の改行に変換
        $message = $message.Replace('\r\n', "`r`n").Replace('\n', "`n")
        
        # 引数があれば、文字列をフォーマット
        if ($Arguments -and $Arguments.Count -gt 0) {
            try {
                return ($message -f $Arguments)
            } catch {
                return $message
            }
        }
        
        return $message
    }

    # ログの定義
    $script:LogPath = Join-Path -Path $yaml.LOG.PATH -ChildPath ($yaml.LOG.FILENAME+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+$yaml.LOG.EXTENSION) # ログの保存先
    # ログファイルのディレクトリが存在しなければ作成
    $logDir = Split-Path -Parent $script:LogPath
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    
    # ログディレクトリのパーミッション設定（現在のユーザーのみアクセス可能）
    try {
        $logDirAcl = Get-Acl -Path $logDir
        # 既存の継承権を無効化
        $logDirAcl.SetAccessRuleProtection($true, $false)
        # すべての権限を削除
        $logDirAcl.Access | ForEach-Object { $logDirAcl.RemoveAccessRule($_) } | Out-Null
        # 現在のユーザーにフルアクセス権を付与
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity.User, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $logDirAcl.AddAccessRule($rule)
        Set-Acl -Path $logDir -AclObject $logDirAcl
    } catch {
        # パーミッション設定に失敗した場合は警告を表示するが、処理を続行
        Write-Host "[WARNING] Could not set permissions on log directory: $_" -ForegroundColor Yellow
    }
}
process{

    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "relMain" # スレッド名は拡張子無しのスクリプトファイル名

    # PowerShellのバージョンチェック
    $PwsVerChk = ($PSVersionTable.PSVersion).ToString()
    if($script:yaml.PowerShell.Version -ne $PwsVerChk){
        [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "VERSION_WARNING" $PwsVerChk $script:yaml.PowerShell.Version) -Title "WARNING" -Buttons 4
        switch($Button){
            6 { break } # OK(Continue)
            7 { exit }  # Cancel(End)
            default { 
                Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
                exit
            }
        }
    }

    # 実行するかどうかの確認
    [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "EXECUTE_CONFIRM") -Title "INQUIRY" -Buttons 4
    switch($Button){
        6 { break } # OK(Continue)
        7 { exit }  # Cancel(End)
        default { 
            Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
            & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
            exit
        }
    }

    # タイトル表示
    $ProjectLength = "Project name: $($yaml.Project)".Length    # プロジェクト名の長さを取得
    $ProjectLine = "=" * $ProjectLength                         # プロジェクト名の長さと同じ長さの=を作成
    Write-CommonLog -Message $ProjectLine -LogPath $script:LogPath -Level 'INFO'                            # プロジェクト名の長さと同じ長さの=をログに出力
    Write-CommonLog -Message "Project name: $($yaml.Project)" -LogPath $script:LogPath -Level 'INFO'        # プロジェクト名をログに出力
    Write-CommonLog -Message "Project version: $($yaml.Version)" -LogPath $script:LogPath -Level 'INFO'     # バージョンをログに出力
    Write-CommonLog -Message $ProjectLine -LogPath $script:LogPath -Level 'INFO'                  # プロジェクト名の長さと同じ長さの=をログに出力
    
    # モジュールのインポート
    foreach($ModuleType in $yaml.Module.Keys){
        $ModuleName = $yaml.Module.$ModuleType.Name         # モジュール名
        $ModuleVersion = $yaml.Module.$ModuleType.VERSION   # モジュールのバージョン
        
        # もし、モジュール名かバージョンが空であれば、スキップ
        if ([string]::IsNullOrWhiteSpace($ModuleName) -or [string]::IsNullOrWhiteSpace($ModuleVersion)) {
            Write-CommonLog -Message (& $script:GetMessage "MODULE_EMPTY_SKIP") -LogPath $script:LogPath -Level 'WARN'
            continue # スキップ
        }
        # モジュールがインストールされているか確認
        if (-not (Test-ModuleInstalled -ModuleName $ModuleName)) {
            # モジュールがインストールされていない場合は、インストールを促す
            [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "MODULE_INSTALL_PROMPT" $ModuleName) -Title "Module Check" -Buttons 4
            switch($Button){
                6 { break } # OK(Continue)
                7 { exit }  # Cancel(End)
                default { 
                    Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                    & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
                    exit
                }
            }
        }
        
        try{
            # モジュールのインポート
            Import-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -ErrorAction Stop
            $msg = & $script:GetMessage "MODULE_IMPORT_SUCCESS" $ModuleName $ModuleVersion
            Write-CommonLog -Message $msg -LogPath $script:LogPath -Level 'INFO'
        }catch{
            # モジュールのインポートに失敗した場合は警告を表示し終了
            $msg = & $script:GetMessage "MODULE_IMPORT_ERROR" $ModuleName $ModuleVersion
            & $script:ShowPopup -Message ($msg + "`r`n`r`n" + $_.Exception.Message) -Title "Module Check" -Buttons 0x30 | Out-Null
            exit # 終了
        }
    }

    # リリースの実行
    $RunPwsVerLength = ("Running PowerShell version: "+$PwsVerChk).Length   # PowerShellバージョンの長さを取得
    $RunPwsVerLine = "+" * $RunPwsVerLength                                 # PowerShellバージョンの長さと同じ長さの+を作成
    Write-CommonLog -Message $RunPwsVerLine -LogPath $script:LogPath -Level 'INFO'                              # PowerShellバージョンの長さと同じ長さの+をログに出力
    Write-CommonLog -Message ("HOST: "+$script:HostName) -LogPath $script:LogPath -Level 'INFO'                 # ホスト名をログに出力
    Write-CommonLog -Message ("USER: "+$script:User) -LogPath $script:LogPath -Level 'INFO'                     # ユーザ名をログに出力
    Write-CommonLog -Message ("Running PowerShell version: "+$PwsVerChk) -LogPath $script:LogPath -Level 'INFO' # PowerShellのバージョンをログに出力
    Write-CommonLog -Message $RunPwsVerLine -LogPath $script:LogPath -Level 'INFO'                              # PowerShellバージョンの長さと同じ長さの+をログに出力
    Write-CommonLog -Message ("Release start time: "+(Get-Date -Format "yyyy/MM/dd HH:mm:ss")) -LogPath $script:LogPath -Level 'INFO' # リリース開始時間をログに出力  

    # ここから時間計測
    $TimeLap = Measure-Command{ # 開始時間を取得

    # リリース処理
    $AllTypeObj = $yaml.RELEASE.Keys # リリースタイプの取得
    foreach($ReleaseType in $AllTypeObj){
        # リリース処理を実行
        Copy-ItemCustom -ReleaseType $ReleaseType -Yaml $yaml -LogPath $script:LogPath -SensitivePatterns $script:SensitivePatterns
    }    } # ここまで時間計測

}
end{
    # ログファイルのパーミッション設定（現在のユーザーのみ読み取り可能）
    try {
        if (Test-Path -Path $script:LogPath) {
            $logFileAcl = Get-Acl -Path $script:LogPath
            # 既存の継承権を無効化
            $logFileAcl.SetAccessRuleProtection($true, $false)
            # すべての権限を削除
            $logFileAcl.Access | ForEach-Object { $logFileAcl.RemoveAccessRule($_) } | Out-Null
            # 現在のユーザーにフルアクセス権を付与
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity.User, "FullControl", "None", "None", "Allow")
            $logFileAcl.AddAccessRule($rule)
            Set-Acl -Path $script:LogPath -AclObject $logFileAcl
        }
    } catch {
        Write-CommonLog -Message "[WARNING] Could not set permissions on log file: $_" -LogPath $script:LogPath -Level 'WARN'
    }
    
    # Measure-Commandの結果をログに出力
    Write-CommonLog -Message "Elapsed time for release: $($TimeLap.TotalSeconds) seconds" -LogPath $script:LogPath -Level 'INFO'    # リリース処理の経過時間をログに出力
    Write-CommonLog -Message ("Elapsed time for release: {0:D2}:Min {1:D2}:Sec" -f $TimeLap.Minutes, $TimeLap.Seconds) -LogPath $script:LogPath -Level 'INFO' # リリース処理の経過時間をログに出力
    Write-CommonLog -Message "Release end time: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')" -LogPath $script:LogPath -Level 'INFO'   # リリース終了時間をログに出力
    
    Invoke-Item -Path $script:LogPath   # ログファイルを開く
}

