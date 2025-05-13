# ===================================
# 起動オプション
#  -DecryptionKey   鍵ファイル指定
#  -EnvYaml         YAMLファイル指定
# ===================================

param(
    # [Parameter(Mandatory = $true)]
    [string]$DecryptionKey = "Encryption.Key" , # オプション無しのデフォルト値
    [string]$EnvYaml = "Env.yaml"               # オプション無しのデフォルト値
)
begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = $scriptPath | Split-Path -Parent                       # スクリプトの親パスを取得
    $PowerShellDir = $UpperPath | Split-Path -Parent                    # スクリプトの親パスの親パスを取得
    $YamlPath = Join-Path -Path $UpperPath"\YAML" -ChildPath $EnvYaml   # YAMLファイルのフルパスを取得
    $KeyPath = Join-Path -Path $PowerShellDir"\Common" -ChildPath $DecryptionKey    # 鍵ファイルのフルパスを取得 

    # ユーザの特定
    $global:gblUser = $env:USERNAME
    $global:glbHostName = $env:COMPUTERNAME
    # $global:gblUser = $global:gblUser.ToLower()     # ユーザ名を小文字に変換
    # $global:HostName = $global:HostName.ToLower()   # ホスト名を小文字に変換

    # .ps1ファイルの読み込み
    try{
        . $PowerShellDir"\Common\FindModule.ps1"
        . $PowerShellDir"\Common\NoDoubleActivation.ps1"
        . $scriptPath"\CopyItemCustom.ps1"
    }catch{
        # スクリプトファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        # $obj.Popup("PowerShell ファイルを読み込めませんでした。処理を終了します。`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        $obj.Popup("I couldn't read the PowerShell file. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        exit # 終了
    }

    # PowerShell-Yamlモジュールがインストールされていなければ、終了
    try {
        if (-not (Find-Module -ModuleName "PowerShell-Yaml")) {
            $obj = New-Object -ComObject WScript.Shell
            # $obj.Popup("モジュール 'PowerShell-Yaml' がインストールされていません。処理を終了します。", 0, "Module Check", 0x30) | Out-Null
            $obj.Popup("Module 'PowerShell-Yaml' is not installed. I'm ending the process.", 0, "Module Check", 0x30) | Out-Null
            exit # 終了
        }
    }
    catch {
        # Find-Moduleを実行できない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        # $obj.Popup("'Find-Module'を実行できませんでした。処理を終了します。`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null 
        $obj.Popup("I couldn't execute 'Find-Module'. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
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
    # # PowerShellオブジェクトに変換
    # try{
    #     $yamlObj = ConvertFrom-Yaml -Ordered $Yaml -ErrorAction Stop # -Ordered: YAMLの順序を保持するオプション
    # }catch{ 
    #     # 変換できない場合は警告を表示し終了
    #     $obj = New-Object PSObject WScript.Shell
    #     $obj.Popup("I couldn't convert the YAML file to PowerShell object. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
    #     exit # 終了
    # }

    # # YAML指定モジュールがインストール済みか確認
    # foreach ($module in $yaml.Module.Keys) {
    #     if (-not (Find-Module -ModuleName $module)) {
    #         $obj = New-Object PSObject WScript.Shell
    #         $obj.Popup("Module '$module' is not installed.", 0, "Module Check", 0x30) | Out-Null
    #         exit # 終了
    #     }
    # }

    # ログの定義
    $global:glbLogPath = Join-Path -Path $yaml.LOG.PATH -ChildPath ($yaml.LOG.FILENAME+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+$yaml.LOG.EXTENSION) # ログの保存先
    # $glbLogPath = $logPath -replace "\\", "/" # パスの区切り文字を変換

    # ログの出力関数
    function Write-Log {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message
            # [string]$LogPath = $logPath
        )
        # $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss" # タイムスタンプの取得
        # $logMessage = "$timestamp - $Message" # ログメッセージの作成
        # Add-Content -Path $LogPath -Value $logMessage # ログファイルに追記
        Write-Output $Message | Tee-Object -FilePath $glbLogPath -Append | Out-Default # メッセージを出力し、ログファイルに追記
    }
}
process{

    # 二重起動の禁止
    Check-NoDoubleActivation -Thread "relMain" # スレッド名は拡張子無しのスクリプトファイル名

    # PowerShellのバージョンチェック
    $PwsVerChk = ($PSVersionTable.PSVersion).ToString()
    if(!($Yaml.PowerShell.Version -eq $PwsVerChk)){
        $obj = New-Object -ComObject WScript.Shell
        # $obj.Popup("PowerShell version is not matched. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30)
        # [int]$Button = $obj.Popup("実行中のPowerShellは"+$PwsVerChk+"です。`r`n`r`nこのスクリプトはバージョン"+$Yaml.PowerShell.Version+"でのみ動作確認しています。処理を続行しますか？", 0, "警告", 4)
        [int]$Button = $obj.Popup("The running PowerShell version is "+$PwsVerChk+".`r`n`r`nThis script has only been tested with version "+$Yaml.PowerShell.Version+". Do you want to continue?", 0, "WARNING", 4)
        switch($Button){
            6 { break } # OK(Continue)
            7 { exit }  # Cancel(End)
            # default { Write-Log "不明なボタンが押されました。" } # Unknown
            default { Write-Log "An unknown button was pressed." ; exit } # Unknown
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
            Write-Log "An unknown button was pressed."
            # $obj.Popup("不明なボタンが押されました。", 0, "Unknown", 0x30) | Out-Null
            $obj.Popup("An unknown button was pressed.", 0, "Unknown", 0x30) | Out-Null
            exit
        } # Unknown
    }

    # タイトル表示
    $ProjectLength = (("Project name: "+$yaml.Project).ToString()).Length   # プロジェクト名の長さを取得
    $ProjectLine = "=" * $ProjectLength                         # プロジェクト名の長さと同じ長さの=を作成
    Write-Log $ProjectLine                                      # プロジェクト名の長さと同じ長さの=をログに出力
    Write-Log ("Project name: "+$yaml.Project).ToString()       # プロジェクト名をログに出力
    Write-Log ("Project version: "+$yaml.Version).ToString()    # バージョンをログに出力
    Write-Log $ProjectLine                  # プロジェクト名の長さと同じ長さの=をログに出力
    # Write-Log ("`r`n").ToString()           # 改行をログに出力
    
    # モジュールのインポート
    foreach($ModuleType in $yaml.Module.Keys){
        # if ($yaml.Module.ContainsKey($ModuleType)) {
        $ModuleName = $yaml.Module.$ModuleType.Name # モジュール名
        $ModuleVersion = $yaml.Module.$ModuleType.VERSION   # モジュールのバージョン
        
        # もし、モジュール名かバージョンが空であれば、スキップ
        if ($ModuleName -eq "" -or $ModuleVersion -eq "") {
            # Write-Log ("モジュール名かバージョンが空でした。 処理をスキップします。").ToString() # ログにエラーメッセージを出力
            Write-Log "Module name or version is empty. Skipping module import." # ログにエラーメッセージを出力
            continue # スキップ
        }
        # モジュールがインストールされているか確認
        if (-not (Find-Module -ModuleName $ModuleName)) {
            # モジュールがインストールされていない場合は、インストールを促す
            $obj = New-Object -ComObject WScript.Shell
            # [int]$Button = $obj.Popup("Module '$ModuleName' がインストールされていません. インストールを実施してください。", 0, "Module Check", 4)
            [int]$Button = $obj.Popup("Module '$ModuleName' is not installed. Do you want to install it?", 0, "Module Check", 4)
            switch($Button){
                6 { break } # OK(Continue)
                7 { Exit }  # Cancel(End)
                # default { Write-Log "不明なボタンが押されました。" } # Unknown
                default { 
                    Write-Log "An unknown button was pressed."
                    # $obj.Popup("不明なボタンが押されました。", 0, "Unknown", 0x30) | Out-Null
                    $obj.Popup("An unknown button was pressed.", 0, "Unknown", 0x30) | Out-Null
                    exit
                } # Unknown
            }
        }
        
        try{
            # モジュールのインポート
            Import-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -ErrorAction Stop # モジュールのインポート
            Write-Log "The import of module '$ModuleName($ModuleVersion)' was successful." # モジュールのインポート成功メッセージ    
        }catch{
            # モジュールのインポートに失敗した場合は警告を表示し終了
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup("Module '$ModuleName($ModuleVersion)' import failed. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
            exit # 終了
        }
    }

    # リリースの実行
    Write-Log ("`r").ToString() # 改行をログに出力
    Write-Log ("HOST: "+$glbHostName).ToString()    # ホスト名をログに出力
    Write-Log ("USER: "+$gblUser).ToString()        # ユーザ名をログに出力
    Write-Log ("Running PowerShell version: "+$PwsVerChk).ToString() # PowerShellのバージョンをログに出力
    Write-Log ("`r").ToString() # 改行をログに出力
    Write-Log ("Release start time: "+(Get-Date -Format "yyyy/MM/dd HH:mm:ss")).ToString() # リリース開始時間をログに出力

    # ここから時間計測
    $TimeLap = Measure-Command{ # 開始時間を取得

    # リリース処理
    $AllTypeObj = $yaml.RELEASE.Keys # リリースタイプの取得
    foreach($ReleaseType in $AllTypeObj){
        # リリースタイプの取得
        # $ReleaseType = $yaml.RELEASE.$ReleaseType.Type # リリースタイプの取得
        # # リリース元フォルダの取得
        # $ReleaseSource = $yaml.RELEASE.$ReleaseType.FolderBy # リリース元フォルダの取得
        # # リリース先フォルダの取得
        # $ReleaseDestination = $yaml.RELEASE.$ReleaseType.FolderTo # リリース先フォルダの取得
        
        # リリース処理を実行
        Copy-ItemCustom -ReleaseType $ReleaseType
    }
    
    } # ここまで時間計測

}
end{
    # Measure-Commandの結果をログに出力
    # Write-Log ("Elapsed time for release: "+$TimeLap.TotalSeconds+" seconds").ToString() # リリース処理の経過時間をログに出力
    Write-Log ("Elapsed time for release: "+$TimeLap.Minutes.ToString("00")+":Min "+$TimeLap.Seconds.ToString("00")+":Sec") # リリース処理の経過時間をログに出力
    Write-Log ("Release end time: "+(Get-Date -Format "yyyy/MM/dd HH:mm:ss")).ToString() # リリース終了時間をログに出力
    Invoke-Item -Path $glbLogPath # ログファイルを開く
}

