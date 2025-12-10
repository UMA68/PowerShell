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
        $obj.Popup("I couldn't read the PowerShell file. I'm ending the process.`r`n`r`n"+$_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        exit # 終了
    }

    # PowerShell-Yamlモジュールがインストールされていなければ、終了
    try {
        if (-not (Test-ModuleInstalled -ModuleName "PowerShell-Yaml")) {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup("Module 'PowerShell-Yaml' is not installed. I'm ending the process.", 0, "Module Check", 0x30) | Out-Null
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            exit # 終了
        }
    }
    catch {
        # Test-ModuleInstalledを実行できない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("I couldn't execute 'Test-ModuleInstalled'. I'm ending the process.`r`n`r`n"+$_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        exit # 終了
    }

    # YAMLファイルの読み込み
    try{
        $script:yaml = Get-Content $YamlPath -Delimiter "`0" | ConvertFrom-Yaml -Ordered -ErrorAction Stop
    }catch{
        # YAMLファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("I couldn't read the YAML file. I'm ending the process.`r`n`r`n"+$_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        exit # 終了
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
}
process{

    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "relMain" # スレッド名は拡張子無しのスクリプトファイル名

    # PowerShellのバージョンチェック
    $PwsVerChk = ($PSVersionTable.PSVersion).ToString()
    if($script:yaml.PowerShell.Version -ne $PwsVerChk){
        $obj = New-Object -ComObject WScript.Shell
        [int]$Button = $obj.Popup((& $script:GetMessage "VERSION_WARNING" $PwsVerChk $script:yaml.PowerShell.Version), 0, "WARNING", 4)
        switch($Button){
            6 { try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}; break } # OK(Continue)
            7 { try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}; exit }  # Cancel(End)
            default { 
                Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                $obj.Popup((& $script:GetMessage "UNKNOWN_BUTTON"), 0, "Unknown", 0x30) | Out-Null
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                exit
            }
        }
    }

    # 実行するかどうかの確認
    $obj = New-Object -ComObject WScript.Shell
    [int]$Button = $obj.Popup((& $script:GetMessage "EXECUTE_CONFIRM"), 0, "INQUIRY", 4)
    switch($Button){
        6 { try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}; break } # OK(Continue)
        7 { try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}; exit }  # Cancel(End)
        default { 
            Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
            $obj.Popup((& $script:GetMessage "UNKNOWN_BUTTON"), 0, "Unknown", 0x30) | Out-Null
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
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
            $obj = New-Object -ComObject WScript.Shell
            [int]$Button = $obj.Popup((& $script:GetMessage "MODULE_INSTALL_PROMPT" $ModuleName), 0, "Module Check", 4)
            switch($Button){
                6 { try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}; break } # OK(Continue)
                7 { try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}; exit }  # Cancel(End)
                default { 
                    Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                    $obj.Popup((& $script:GetMessage "UNKNOWN_BUTTON"), 0, "Unknown", 0x30) | Out-Null
                    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
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
            $obj = New-Object -ComObject WScript.Shell
            $msg = & $script:GetMessage "MODULE_IMPORT_ERROR" $ModuleName $ModuleVersion
            $obj.Popup($msg + "`r`n`r`n" + $_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
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
        Copy-ItemCustom -ReleaseType $ReleaseType -Yaml $yaml -LogPath $script:LogPath
    }    } # ここまで時間計測

}
end{
    # Measure-Commandの結果をログに出力
    Write-CommonLog -Message "Elapsed time for release: $($TimeLap.TotalSeconds) seconds" -LogPath $script:LogPath -Level 'INFO'    # リリース処理の経過時間をログに出力
    Write-CommonLog -Message ("Elapsed time for release: {0:D2}:Min {1:D2}:Sec" -f $TimeLap.Minutes, $TimeLap.Seconds) -LogPath $script:LogPath -Level 'INFO' # リリース処理の経過時間をログに出力
    Write-CommonLog -Message "Release end time: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')" -LogPath $script:LogPath -Level 'INFO'   # リリース終了時間をログに出力
    
    Invoke-Item -Path $script:LogPath   # ログファイルを開く
}

