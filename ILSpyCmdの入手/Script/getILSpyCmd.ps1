# ILSpyCmdのインストールスクリプト
# Version: 1.0.0
param (
    [string]$EnvYaml = "getILSpyCmd.yaml" # オプションなしの場合は「getILSpyCmd.yaml」を使用する
)

begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = $scriptPath | Split-Path -Parent                       # スクリプトの親パスを取得
    $PowerShellDir = $UpperPath | Split-Path -Parent                    # スクリプトの親パスの親パスを取得
    $YamlPath = Join-Path -Path $UpperPath"\YAML" -ChildPath $EnvYaml   # YAMLファイルのフルパスを取得
    # $KeyPath = Join-Path -Path $PowerShellDir"\Common" -ChildPath $DecryptionKey    # 鍵ファイルのフルパスを取得 
    $LogDir = Join-Path -Path $UpperPath -ChildPath "Log"                # ログファイルの格納ディレクトリを取得
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"        # 共通スクリプトのパスを取得

    # 共通スクリプトのインポート
    try{
        . $comPath"\Write-CommonLog.ps1" -ErrorAction Stop
    }catch{
        # スクリプトファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        # $obj.Popup("PowerShell ファイルを読み込めませんでした。処理を終了します。`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        $obj.Popup("I couldn't read the PowerShell file. I'm ending the process.`r`n`r`n"+$_Exception.Message, 0, "Module Check", 0x30) | Out-Null
        exit # 終了
    }

    # YAMLファイルの存在チェック
    if (-not (Test-Path -Path $YamlPath)) {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("YAMLファイルが存在しません。`r`n`r`n"+$YamlPath+"を確認してください。",0,"エラー",0x30)
        exit
    }
    # powershell-yamlのインポート
    try {
        Import-Module -Name "powershell-yaml" -ErrorAction Stop
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("powershell-yamlモジュールのインポートに失敗しました。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        exit
    }
    
    # YAMLファイルの読み込み
    try {
        $yaml = Get-Content -Path $YamlPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("YAMLファイルの読み込みに失敗しました。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        exit
    }
    # PowerShell-Yamlのバージョン取得
    [string]$PowershellYamlVersion = ($yaml.Module.'Powershell-Yaml'.Version).ToString()
    # YAMLファイルにあるpowershell-yamlのバージョンをインポート
    if ($PowershellYamlVersion) {
        try {
            Import-Module -Name $yaml.Module.'Powershell-Yaml'.Name -RequiredVersion $PowershellYamlVersion -ErrorAction Stop
        } catch {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup("Powershell-Yaml($PowershellYamlVersion)モジュールのインポートに失敗しました。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
            exit
        }
    }

    # ユーザの特定
    $global:gblUser = $env:USERNAME
    $global:glbHostName = $env:COMPUTERNAME

    # YAMLファイルから必要な情報を取得
    $LogFileName = $yaml.LOG.FILENAME
    $Logextension = $yaml.LOG.EXTENSION

    # ログの定義
    $Log = Join-Path -Path $LogDir -ChildPath ($LogFileName+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+$Logextension)
    # ログディレクトリが作成されていなければ作成
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory | Out-Null
    }    
}
process{
    # タイトル表示
    Write-CommonLog -Message "HOST: $glbHostName" -LogPath $Log -Level "INFO"   # ホスト名をログに出力
    Write-CommonLog -Message "USER: $gblUser" -LogPath $Log -Level "INFO"       # ユーザ名をログに出力
    Write-CommonLog -Message "Running PowerShell Version: $($PSVersionTable.PSVersion)" -LogPath $Log -Level "INFO"  # PowerShellのバージョンをログに出力
    $ProjectLength = (("Project name: "+$yaml.Project).ToString()).Length       # プロジェクト名の長さを取得
    $ProjectLine = "=" * $ProjectLength                                         # プロジェクト名の長さと同じ長さの=を作成
    Write-CommonLog -Message $ProjectLine -LogPath $Log -Level "INFO"                                    # プロジェクト名の長さと同じ長さの=をログに出力
    Write-CommonLog -Message ("Project name: "+$yaml.Project).ToString() -LogPath $Log -Level "INFO"     # プロジェクト名をログに出力
    Write-CommonLog -Message ("Project version: "+$yaml.Version).ToString() -LogPath $Log -Level "INFO"  # バージョンをログに出力
    Write-CommonLog -Message $ProjectLine -LogPath $Log -Level "INFO"                                    # プロジェクト名の長さと同じ長さの=をログに出力
    
    # 改行をログに出力
    Write-Output ("`r`n").ToString() | Tee-Object -FilePath $Log -Append

    # ダイアログ表示用オブジェクト
    $obj = New-Object -ComObject WScript.Shell

    # ILSpyCmdがインストールされているか確認(あったら終了)
    $ILSpyCmdInstalled = Get-Command "ilspycmd" -ErrorAction SilentlyContinue
    if ($ILSpyCmdInstalled) {
        Write-CommonLog -Message "✅ ilspycmd is already installed." -LogPath $Log -Level "INFO"
        # $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("ILSpyCmdはインストール済みで問題ありません。プログラムを終了します。",0,"情報",0x40) | Out-Null
        Invoke-Item -Path $Log
        exit
    } else {
        Write-CommonLog -Message "ILSpyCmd is not installed." -LogPath $Log -Level "INFO"
        # Invoke-Item -Path $Log
    }

    # SDKの存在確認
    $sdks = & dotnet --list-sdks 2>$null
    # SDKのインストール
    if (-not $sdks) {
        # dotnetがインストールされていない場合の処理
        Write-CommonLog -Message "dotnet(sdk) is not installed. Please install .NET SDK." -LogPath $Log -Level "WARN"
        # $obj = New-Object -ComObject WScript.Shell
        [int]$retButton = $obj.Popup("dotnet(sdk)がインストールされていません。.NET SDK をインストールしますか？",0,"警告",20)   # はい=6 いいえ=7
        switch($retButton){
            # はい(.NET SDKをインストール)
            6 {
                # インストーラ格納先
                $SdkFolderName = $yaml.DotnetSdk.SdkFolder
                $SdkFolderPath = Join-Path -Path $UpperPath -ChildPath $SdkFolderName
                $installerPath = Join-Path -Path $SdkFolderPath -ChildPath ($yaml.DotnetSdk.Installer)
                $verSDK = $yaml.DotnetSdk.Version

                #  dotnet SDKのインストール
                $obj.Popup("dotnet SDK($verSDK)のインストールを開始します。",0,"情報",0x40) | Out-Null
                # ログにメッセージを出力
                Write-CommonLog -Message "Starting the installation of the .NET SDK." -LogPath $Log -Level "INFO"

                Try{
                    # インストール（パッシブモード：進捗見えるが操作不要）
                    Start-Process -FilePath $installerPath -ArgumentList "/install /passive /norestart" -Wait
                    Write-CommonLog -Message "dotnet SDK installation completed." -LogPath $Log -Level "INFO"
                    # インストール確認
                    if (Get-Command "dotnet" -ErrorAction SilentlyContinue) {
                        Write-CommonLog -Message "dotnet SDK installed successfully." -LogPath $Log -Level "INFO"
                    } else {
                        Write-CommonLog -Message "dotnet SDK installation failed." -LogPath $Log -Level "ERROR"
                        # $obj = New-Object -ComObject WScript.Shell
                        # $obj.Popup("dotnet SDKのインストールに失敗しました。`r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
                        $obj.Popup("dotnet SDKのインストールに失敗しました。`r`nプログラムを終了します。",0,"エラー",0x10) | Out-Null
                        Invoke-Item -Path $Log
                        exit
                    }
            
                } catch {
                    Write-CommonLog -Message "Failed to start dotnet SDK installation: $_" -LogPath $Log -Level "ERROR"
                    # $obj = New-Object -ComObject WScript.Shell
                    # $obj.Popup("Failed to start dotnet SDK installation: $_ `r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
                    $obj.Popup("Failed to start dotnet SDK installation: $_ `r`nプログラムを終了します。",0,"エラー",0x10) | Out-Null
                    Invoke-Item -Path $Log
                    exit
                }
            }                
            # いいえ(スクリプト終了)
            7 {
                # $obj = New-Object -ComObject WScript.Shell
                $obj.Popup("プログラムを終了します。",0,"情報",0x40) | Out-Null
                Invoke-Item -Path $Log
                exit 
            }
        }

    }else{
        # dotnetがインストールされていた場合の処理
        Write-CommonLog -Message "✅ .NET SDK はすでにインストールされています。" -LogPath $Log -Level "INFO"
        & dotnet --list-sdks
        $DotnetSdks = & dotnet --list-sdks
        Write-CommonLog -Message "dotnet --list-sdks" -LogPath $Log -Level "INFO"
        Write-CommonLog -Message $DotnetSdks -LogPath $Log -Level "INFO"
    }

    # ILSpyCmdのインストール
    # dotnet tool install --global ilspycmdを実行する前に、ユーザに通知
    $obj = New-Object -ComObject WScript.Shell
    $obj.Popup("ILSpyCmdをインストールします。",0,"情報",0x40) | Out-Null
    #  dotnet tool install --global ilspycmd を実行
    try {
        # dotnet tool install --global ilspycmd
        $cmdCommand = 'dotnet tool install --global ilspycmd && echo ILSpyCmd のインストールが完了しました。Enter キーで終了します && pause'
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmdCommand" -Wait -ErrorAction Stop
        Write-CommonLog -Message "'dotnet tool install --global ilspycmd' executed successfully." -LogPath $Log -Level "INFO"
        Write-CommonLog -Message "ILSpyCmd installation completed." -LogPath $Log -Level "INFO"
    } catch {
        Write-CommonLog -Message "Failed to install ILSpyCmd: $_" -LogPath $Log -Level "ERROR"
        # $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("Failed to install ILSpyCmd: $_ `r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
        Invoke-Item -Path $Log
        exit
    }
}
end{
    # スクリプトの終了メッセージをログに出力
    Write-CommonLog -Message "Script ended." -LogPath $Log -Level "INFO"
    # ログファイルを開く
    Invoke-Item -Path $Log
}
