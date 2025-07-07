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
    } # else {
    #     try {
    #         Import-Module -Name "powershell-yaml" -ErrorAction Stop
    #     } catch {
    #         $obj = New-Object -ComObject WScript.Shell
    #         $obj.Popup("powershell-yamlモジュールのインポートに失敗しました。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
    #         exit
    #     }

    # ユーザの特定
    $global:gblUser = $env:USERNAME
    $global:glbHostName = $env:COMPUTERNAME

    # YAMLファイルから必要な情報を取得
    $LogFileName = $yaml.LOG.FILENAME
    $Logextension = $yaml.LOG.EXTENSION

    # ログの定義
    $Log = Join-Path -Path $LogDir -ChildPath ($LogFileName+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+$Logextension)

    # ログの表示&書き込み
    function Log-Message {
        param (
            [string]$message
        )
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "$timestamp - $message"
        Write-Output $logMessage | Tee-Object -FilePath $Log -Append
    }

}
process{
    # タイトル表示
    Log-Message "HOST: $glbHostName"    # ホスト名をログに出力
    Log-Message "USER: $gblUser"        # ユーザ名をログに出
    Log-Message "Running PowerShell Version: $($PSVersionTable.PSVersion)"  # PowerShellのバージョンをログに出力
    $ProjectLength = (("Project name: "+$yaml.Project).ToString()).Length   # プロジェクト名の長さを取得
    $ProjectLine = "=" * $ProjectLength                         # プロジェクト名の長さと同じ長さの=を作成
    Log-Message $ProjectLine                                    # プロジェクト名の長さと同じ長さの=をログに出力
    Log-Message ("Project name: "+$yaml.Project).ToString()     # プロジェクト名をログに出力
    Log-Message ("Project version: "+$yaml.Version).ToString()  # バージョンをログに出力
    Log-Message $ProjectLine                                    # プロジェクト名の長さと同じ長さの=をログに出力
    
    # 改行をログに出力
    Write-Output ("`r`n").ToString() | Tee-Object -FilePath $Log -Append

    # ダイアログ表示用オブジェクト
    $obj = New-Object -ComObject WScript.Shell

    # ILSpyCmdがインストールされているか確認(あったら終了)
    $ILSpyCmdInstalled = Get-Command "ilspycmd" -ErrorAction SilentlyContinue
    if ($ILSpyCmdInstalled) {
        Log-Message "ilspycmd is already installed."
        # $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("ILSpyCmdはインストール済みで問題ありません。プログラムを終了します。",0,"情報",0x40) | Out-Null
        Invoke-Item -Path $Log
        exit
    } else {
        Log-Message "ILSpyCmd is not installed."
        # Invoke-Item -Path $Log
    }

    # SDKの存在確認
    $sdks = & dotnet --list-sdks 2>$null
    # SDKのインストール
    if (-not $sdks) {
        # dotnetがインストールされていない場合の処理
        Log-Message "dotnet(sdk) is not installed. Please install .NET SDK."
        # $obj = New-Object -ComObject WScript.Shell
        [int]$retButton = $obj.Popup("dotnet(sdk)がインストールされていません。.NET SDK をインストールしますか？",0,"警告",4)   # はい=6 いいえ=7
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
                Log-Message "Starting the installation of the .NET SDK."

                Try{
                    # インストール（パッシブモード：進捗見えるが操作不要）
                    Start-Process -FilePath $installerPath -ArgumentList "/install /passive /norestart" -Wait
                    Log-Message "dotnet SDK installation completed."
                    # インストール確認
                    if (Get-Command "dotnet" -ErrorAction SilentlyContinue) {
                        Log-Message "dotnet SDK installed successfully."
                    } else {
                        Log-Message "dotnet SDK installation failed."
                        # $obj = New-Object -ComObject WScript.Shell
                        $obj.Popup("dotnet SDKのインストールに失敗しました。`r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
                        Invoke-Item -Path $Log
                        exit
                    }
            
                } catch {
                    Log-Message "Failed to start dotnet SDK installation: $_"
                    # $obj = New-Object -ComObject WScript.Shell
                    $obj.Popup("Failed to start dotnet SDK installation: $_ `r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
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
        Log-Message "✅ .NET SDK はすでにインストールされています。"
        & dotnet --list-sdks
        $DotnetSdks = & dotnet --list-sdks
        Log-Message "dotnet --list-sdks"
        Log-Message $DotnetSdks
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

        Log-Message "'dotnet tool install --global ilspycmd' executed successfully."
        Log-Message "ILSpyCmd installation completed."
    } catch {
        Log-Message "Failed to install ILSpyCmd: $_"
        # $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("Failed to install ILSpyCmd: $_ `r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
        Invoke-Item -Path $Log
        exit
    }


    # # dotnet toolがインストールされているか確認
    # if (-not (Get-Command "dotnet" -ErrorAction SilentlyContinue)) {
    #     # dotnetがインストールされていない場合の処理
    #     Log-Message "dotnet is not installed. Please install .NET SDK."
    #     # $obj = New-Object -ComObject WScript.Shell
    #     [int]$retButton = $obj.Popup("dotnetがインストールされていません。.NET SDK をインストールしますか？",0,"警告",4)   # はい=6 いいえ=7
    #     switch($retButton){
    #         # はい
    #         6 { 
    #             # ダウンロード先とファイル名
    #             # $downloadUrl = "https://download.visualstudio.microsoft.com/download/pr/2f2b7c3e-2e3e-4f2e-9b0e-2e3e2f2b7c3e/dotnet-sdk-8.0.100-win-x64.exe"
    #             # $installerPath = "$env:TEMP\dotnet-sdk-installer.exe"
    #             $downloadUrl = $yaml.DotnetSdk.DownloadUrl
    #             $installerPath = Join-Path -Path $env:TEMP -ChildPath ($yaml.DotnetSdk.Installer)
    #             $verSDK = $yaml.DotnetSdk.Version

    #             #  dotnet SDKのインストール
    #             $obj.Popup("dotnet SDK($verSDK)をインストールします。",0,"情報",0x40) | Out-Null
    #             try {
    #                 # Start-Process "https://dotnet.microsoft.com/download/dotnet" -Wait
                    
    #                 # ログにメッセージを出力
    #                 Log-Message "dotnet SDK installer download started."
    #                 # インストーラーをダウンロード
    #                 Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
    #                 Log-Message "dotnet SDK installer downloaded to $installerPath."

    #                 # ログにメッセージを出力
    #                 Log-Message "dotnet SDK installation started."
    #                 # インストール（サイレントモード）
    #                 Start-Process -FilePath $installerPath -ArgumentList "/install /quiet /norestart" -Wait
    #                 Log-Message "dotnet SDK installation completed."
                    
    #                 # インストール確認
    #                 if (Get-Command "dotnet" -ErrorAction SilentlyContinue) {
    #                     Log-Message "dotnet SDK installed successfully."
    #                 } else {
    #                     Log-Message "dotnet SDK installation failed."
    #                     # $obj = New-Object -ComObject WScript.Shell
    #                     $obj.Popup("dotnet SDKのインストールに失敗しました。`r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
    #                     exit
    #                 }

    #             } catch {
    #                 Log-Message "Failed to start dotnet SDK installation: $_"
    #                 # $obj = New-Object -ComObject WScript.Shell
    #                 $obj.Popup("Failed to start dotnet SDK installation: $_ `r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
    #                 exit
    #             }
    #             # dotnet tool install --global ILSpyCmdを実行する前に、ユーザに確認
    #             # $obj.Popup("dotnet SDKのインストールが完了しました。",0,"情報",0x40) | Out-Null
    #             $obj.Popup("dotnet SDKのインストールが完了しました。`r ILSpyCmdをインストールします。",0,"情報",0x40) | Out-Null
    #             try {
    #                 # dotnet tool install --global ilspycmd --version $ILSpyCmdVersion -s $ILSpyCmdSource -nologo -v q
    #                 dotnet tool install --global ilspycmd
    #                 Log-Message "'dotnet tool install --global ilspycmd' executed successfully."
    #                 Log-Message "ILSpyCmd installation completed."
    #             } catch {
    #                 Log-Message "Failed to install ILSpyCmd: $_"
    #                 # $obj = New-Object -ComObject WScript.Shell
    #                 $obj.Popup("Failed to install ILSpyCmd: $_ `r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
    #                 exit
    #             }
    #         }
    #         # いいえ 
    #         7 { 
    #             # $obj = New-Object -ComObject WScript.Shell
    #             $obj.Popup("プログラムを終了します。",0,"情報",0x40) | Out-Null
    #             exit 
    #         }
    #     }
    # }else{
    #     # dotnetがインストールされている場合の処理
    #     Log-Message "dotnet is already installed."
    #     # dotnet tool install --global ilspycmdを実行する前に、ユーザに確認
    #     # $obj = New-Object -ComObject WScript.Shell
    #     $obj.Popup("ILSpyCmdをインストールします。",0,"情報",0x40) | Out-Null
    #     try {
    #         # dotnet tool install --global ilspycmd --version $ILSpyCmdVersion -s $ILSpyCmdSource -nologo -v q
    #         dotnet tool install --global ilspycmd
    #         Log-Message "'dotnet tool install --global ilspycmd' executed successfully."
    #         Log-Message "ILSpyCmd installation completed."
    #     } catch {
    #         Log-Message "Failed to install ilspycmd: $_"
    #         # $obj = New-Object -ComObject WScript.Shell
    #         $obj.Popup("Failed to install ILSpyCmd: $_ `r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
    #         exit
    #     }
    # }
}

end{
    # # ILSpyCmdのインストール完了確認
    # $ILSpyCmdInstalled = Get-Command "ilspycmd" -ErrorAction SilentlyContinue
    # if ($ILSpyCmdInstalled) {
    #     Log-Message "ilspycmd is already installed."
    #     $obj.Popup("ILSpyCmdは無事インストールできました。",0,"情報",0x40) | Out-Null
    # } else {
    #     Log-Message "ILSpyCmd installation failed."
    #     # $obj = New-Object -ComObject WScript.Shell
    #     $obj.Popup("ILSpyCmdのインストールに失敗しました。`r`nプログラムを終了します。",0,"情報",0x40) | Out-Null
    #     Invoke-Item -Path $Log
    #     exit
    # }
    # スクリプトの終了メッセージをログに出力
    Log-Message "Script ended."
    # ログファイルを開く
    Invoke-Item -Path $Log
}
