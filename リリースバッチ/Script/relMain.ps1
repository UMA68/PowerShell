# ===================================
# 起動オプション
#  -DecryptionKey   鍵ファイル指定
#  -EnvYaml         YAMLファイル指定
# ===================================

param(
    [string]$DecryptionKey = "Encryption.Key" , # オプション無しのデフォルト値
    [string]$EnvYaml = "EnvDEV.yaml"            # DEV環境用:EnvDEV.yaml, STG環境用:EnvSTG.yaml, 本番環境用:EnvPRD.yaml
)
begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = $scriptPath | Split-Path -Parent                       # スクリプトの親パスを取得
    $PowerShellDir = $UpperPath | Split-Path -Parent                    # スクリプトの親パスの親パスを取得
    $YamlPath = Join-Path -Path $UpperPath"\YAML" -ChildPath $EnvYaml   # YAMLファイルのフルパスを取得
    $KeyPath = Join-Path -Path $PowerShellDir"\Common" -ChildPath $DecryptionKey    # 鍵ファイルのフルパスを取得 
    
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"       # 共通スクリプトのパス

    # ユーザの特定
    $global:gblUser = $env:USERNAME
    $global:glbHostName = $env:COMPUTERNAME

    # .ps1ファイルの読み込み
    try{
        . $PowerShellDir"\Common\FindModule.ps1" -ErrorAction Stop
        . $PowerShellDir"\Common\NoDoubleActivation.ps1" -ErrorAction Stop
        . $comPath"\Write-CommonLog.ps1" -ErrorAction Stop
        . $scriptPath"\CopyItemCustom.ps1" -ErrorAction Stop
    }catch{
        # スクリプトファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        # $obj.Popup("PowerShell ファイルを読み込めませんでした。処理を終了します。`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        $obj.Popup("I couldn't read the PowerShell file. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        exit # 終了
    }

    # PowerShell-Yamlモジュールがインストールされていなければ、終了
    try {
        if (-not (Test-ModuleInstalled -ModuleName "PowerShell-Yaml")) {
            $obj = New-Object -ComObject WScript.Shell
            # $obj.Popup("モジュール 'PowerShell-Yaml' がインストールされていません。処理を終了します。", 0, "Module Check", 0x30) | Out-Null
            $obj.Popup("Module 'PowerShell-Yaml' is not installed. I'm ending the process.", 0, "Module Check", 0x30) | Out-Null
            exit # 終了
        }
    }
    catch {
        # Test-ModuleInstalledを実行できない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("I couldn't execute 'Test-ModuleInstalled'. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        exit # 終了
    }

    # YAMLファイルの読み込み
    try{
        $yaml = Get-Content $YamlPath -Delimiter "`0" | ConvertFrom-Yaml -Ordered -ErrorAction Stop
    }catch{
        # YAMLファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        # $obj.Popup("YAMLファイルを読み込めませんでした。処理を終了します。`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        $obj.Popup("I couldn't read the YAML file. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        exit # 終了
    }

    # ログの定義
    $global:glbLogPath = Join-Path -Path $yaml.LOG.PATH -ChildPath ($yaml.LOG.FILENAME+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+$yaml.LOG.EXTENSION) # ログの保存先
    # ログファイルのディレクトリが存在しなければ作成
    $logDir = Split-Path -Parent $global:glbLogPath
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
}
process{

    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "relMain" # スレッド名は拡張子無しのスクリプトファイル名

    # PowerShellのバージョンチェック
    $PwsVerChk = ($PSVersionTable.PSVersion).ToString()
    if($Yaml.PowerShell.Version -ne $PwsVerChk){
        $obj = New-Object -ComObject WScript.Shell
        # [int]$Button = $obj.Popup("実行中のPowerShellは"+$PwsVerChk+"です。`r`n`r`nこのスクリプトはバージョン"+$Yaml.PowerShell.Version+"でのみ動作確認しています。処理を続行しますか？", 0, "警告", 4)
        [int]$Button = $obj.Popup("The running PowerShell version is "+$PwsVerChk+".`r`n`r`nThis script has only been tested with version "+$Yaml.PowerShell.Version+". Do you want to continue?", 0, "WARNING", 4)
        switch($Button){
            6 { break } # OK(Continue)
            7 { exit }  # Cancel(End)
            # default { Write-Log "不明なボタンが押されました。" } # Unknown
            default { Write-CommonLog -Message "An unknown button was pressed." -LogPath $global:glbLogPath -Level 'ERROR' ; exit } # Unknown
        }
    }

    # 実行するかどうかの確認
    $obj = New-Object -ComObject WScript.Shell
    # [int]$Button = $obj.Popup("リリースを実行しますか？", 0, "問い合わせ", 4) | Out-Null
    [int]$Button = $obj.Popup("Do you want to execute the release?", 0, "INQUIRY", 4)
    switch($Button){
        6 { break } # OK(Continue)
        7 { exit }  # Cancel(End)
        default { 
            # Write-Log "An unknown button was pressed."
            Write-CommonLog -Message "An unknown button was pressed." -LogPath $global:glbLogPath -Level 'ERROR'
            # $obj.Popup("不明なボタンが押されました。", 0, "Unknown", 0x30) | Out-Null
            $obj.Popup("An unknown button was pressed.", 0, "Unknown", 0x30) | Out-Null
            exit
        } # Unknown
    }

    # タイトル表示
    $ProjectLength = (("Project name: "+$yaml.Project).ToString()).Length   # プロジェクト名の長さを取得
    $ProjectLine = "=" * $ProjectLength                         # プロジェクト名の長さと同じ長さの=を作成
    Write-CommonLog -Message $ProjectLine -LogPath $global:glbLogPath -Level 'INFO'                                      # プロジェクト名の長さと同じ長さの=をログに出力
    Write-CommonLog -Message ("Project name: "+$yaml.Project).ToString() -LogPath $global:glbLogPath -Level 'INFO'       # プロジェクト名をログに出力
    Write-CommonLog -Message ("Project version: "+$yaml.Version).ToString() -LogPath $global:glbLogPath -Level 'INFO'    # バージョンをログに出力
    Write-CommonLog -Message $ProjectLine -LogPath $global:glbLogPath -Level 'INFO'                  # プロジェクト名の長さと同じ長さの=をログに出力
    # Write-CommonLog -Message ("`r").ToString() -LogPath $global:glbLogPath -Level 'INFO'           # 改行をログに出力
    
    # モジュールのインポート
    foreach($ModuleType in $yaml.Module.Keys){
        $ModuleName = $yaml.Module.$ModuleType.Name # モジュール名
        $ModuleVersion = $yaml.Module.$ModuleType.VERSION   # モジュールのバージョン
        
        # もし、モジュール名かバージョンが空であれば、スキップ
        if ($ModuleName -eq "" -or $ModuleVersion -eq "") {
            # Write-Log ("モジュール名かバージョンが空でした。 処理をスキップします。").ToString() # ログにエラーメッセージを出力
            Write-CommonLog -Message "Module name or version is empty. Skipping module import." -LogPath $global:glbLogPath -Level 'WARN' # ログにエラーメッセージを出力
            continue # スキップ
        }
        # モジュールがインストールされているか確認
        if (-not (Test-ModuleInstalled -ModuleName $ModuleName)) {
            # モジュールがインストールされていない場合は、インストールを促す
            $obj = New-Object -ComObject WScript.Shell
            # [int]$Button = $obj.Popup("Module '$ModuleName' がインストールされていません. インストールを実施してください。", 0, "Module Check", 4)
            [int]$Button = $obj.Popup("Module '$ModuleName' is not installed. Do you want to install it?", 0, "Module Check", 4)
            switch($Button){
                6 { break } # OK(Continue)
                7 { exit }  # Cancel(End)
                default { 
                    # Write-Log "An unknown button was pressed."
                    Write-CommonLog -Message "An unknown button was pressed." -LogPath $global:glbLogPath -Level 'ERROR'
                    # $obj.Popup("不明なボタンが押されました。", 0, "Unknown", 0x30) | Out-Null
                    $obj.Popup("An unknown button was pressed.", 0, "Unknown", 0x30) | Out-Null
                    exit
                } # Unknown
            }
        }
        
        try{
            # モジュールのインポート
            Import-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -ErrorAction Stop # モジュールのインポート
            Write-CommonLog -Message "The import of module '$ModuleName($ModuleVersion)' was successful." -LogPath $global:glbLogPath -Level 'INFO' # モジュールのインポート成功メッセージ
        }catch{
            # モジュールのインポートに失敗した場合は警告を表示し終了
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup("Module '$ModuleName($ModuleVersion)' import failed. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
            exit # 終了
        }
    }

    # リリースの実行
    Write-CommonLog -Message ("`r").ToString() -LogPath $global:glbLogPath -Level 'INFO' # 改行をログに出力
    Write-CommonLog -Message ("HOST: "+$glbHostName).ToString() -LogPath $global:glbLogPath -Level 'INFO'    # ホスト名をログに出力
    Write-CommonLog -Message ("USER: "+$gblUser).ToString() -LogPath $global:glbLogPath -Level 'INFO'        # ユーザ名をログに出力
    Write-CommonLog -Message ("Running PowerShell version: "+$PwsVerChk).ToString() -LogPath $global:glbLogPath -Level 'INFO' # PowerShellのバージョンをログに出力
    Write-CommonLog -Message ("`r").ToString() -LogPath $global:glbLogPath -Level 'INFO' # 改行をログに出力
    Write-CommonLog -Message ("Release start time: "+(Get-Date -Format "yyyy/MM/dd HH:mm:ss")).ToString() -LogPath $global:glbLogPath -Level 'INFO' # リリース開始時間をログに出力  

    # ここから時間計測
    $TimeLap = Measure-Command{ # 開始時間を取得

    # リリース処理
    $AllTypeObj = $yaml.RELEASE.Keys # リリースタイプの取得
    foreach($ReleaseType in $AllTypeObj){        
        # リリース処理を実行
        Copy-ItemCustom -ReleaseType $ReleaseType
    }
    
    } # ここまで時間計測

}
end{
    # Measure-Commandの結果をログに出力
    Write-CommonLog -Message ("Elapsed time for release: "+$TimeLap.TotalSeconds+" seconds").ToString() -LogPath $global:glbLogPath -Level 'INFO' # リリース処理の経過時間をログに出力
    Write-CommonLog -Message ("Elapsed time for release: "+$TimeLap.Minutes.ToString("00")+":Min "+$TimeLap.Seconds.ToString("00")+":Sec") -LogPath $global:glbLogPath -Level 'INFO' # リリース処理の経過時間をログに出力
    Write-CommonLog -Message ("Release end time: "+(Get-Date -Format "yyyy/MM/dd HH:mm:ss")).ToString() -LogPath $global:glbLogPath -Level 'INFO' # リリース終了時間をログに出力
    
    Invoke-Item -Path $glbLogPath # ログファイルを開く
}

