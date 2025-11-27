<#
.SYNOPSIS
    ILSpyCmd (.NET逆コンパイルツール) をインストールします。

.DESCRIPTION
    このスクリプトは、ILSpyCmdとその前提条件である.NET SDKを自動的にインストールします。
    
    主な機能:
    - ILSpyCmdのインストール状態確認
    - .NET SDKの存在確認と自動インストール
    - YAMLファイルからの設定読み込み
    - 詳細なログ出力
    - ユーザーへの対話的な確認

.PARAMETER EnvYaml
    使用するYAML設定ファイル名。デフォルトは "getILSpyCmd.yaml" です。
    YAMLファイルは "YAML" フォルダに配置する必要があります。

.EXAMPLE
    .\getILSpyCmd.ps1
    デフォルト設定でILSpyCmdをインストールします。

.EXAMPLE
    .\getILSpyCmd.ps1 -EnvYaml "custom.yaml"
    カスタムYAML設定ファイルを使用してインストールします。

.NOTES
    File Name      : getILSpyCmd.ps1
    Author         : UMA
    Prerequisite   : PowerShell, powershell-yaml module
    Version        : 1.1.0
    
    前提条件:
    - powershell-yamlモジュールがインストールされていること
    - Write-CommonLog.ps1が Common フォルダに存在すること
    - getILSpyCmd.yaml が YAML フォルダに存在すること
#>
param (
    [Parameter(Mandatory=$false)]
    [string]$EnvYaml = "getILSpyCmd.yaml"
)

begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $UpperPath = Split-Path -Parent $scriptPath
    $PowerShellDir = Split-Path -Parent $UpperPath
    $YamlDir = Join-Path -Path $UpperPath -ChildPath "YAML"
    $YamlPath = Join-Path -Path $YamlDir -ChildPath $EnvYaml
    $LogDir = Join-Path -Path $UpperPath -ChildPath "Log"
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"
    
    # COMオブジェクトの作成（スクリプト全体で使用）
    $script:comObject = $null
    try {
        $script:comObject = New-Object -ComObject WScript.Shell
    } catch {
        Write-Error "COMオブジェクトの作成に失敗しました: $_"
        exit 1
    }

    # 共通スクリプトのインポート
    $commonLogPath = Join-Path -Path $comPath -ChildPath "Write-CommonLog.ps1"
    try{
        . $commonLogPath -ErrorAction Stop
    }catch{
        $script:comObject.Popup("共通スクリプト (Write-CommonLog.ps1) を読み込めませんでした。処理を終了します。`r`n`r`nエラー: $($_.Exception.Message)", 0, "スクリプトエラー", 0x10) | Out-Null
        exit 1
    }

    # YAMLファイルの存在チェック
    if (-not (Test-Path -Path $YamlPath)) {
        $script:comObject.Popup("YAMLファイルが存在しません。`r`n`r`nパス: $YamlPath",0,"ファイルエラー",0x10) | Out-Null
        exit 1
    }
    
    # YAMLファイルの読み込み（まず基本的なYAML読み込みのみ）
    try {
        Import-Module -Name "powershell-yaml" -ErrorAction Stop
        $yaml = Get-Content -Path $YamlPath -Raw -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    } catch {
        $script:comObject.Popup("YAMLファイルの読み込みに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)",0,"YAML読み込みエラー",0x10) | Out-Null
        exit 1
    }
    
    # YAMLファイルにバージョン指定があれば、指定バージョンで再インポート
    if ($yaml.Module.'Powershell-Yaml'.Version) {
        [string]$PowershellYamlVersion = $yaml.Module.'Powershell-Yaml'.Version.ToString()
        try {
            Import-Module -Name "powershell-yaml" -RequiredVersion $PowershellYamlVersion -Force -ErrorAction Stop
        } catch {
            $script:comObject.Popup("powershell-yaml (v$PowershellYamlVersion) モジュールのインポートに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)",0,"モジュールエラー",0x10) | Out-Null
            exit 1
        }
    }

    # ログディレクトリが作成されていなければ作成
    if (-not (Test-Path -Path $LogDir)) {
        try {
            New-Item -Path $LogDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            $script:comObject.Popup("ログディレクトリの作成に失敗しました。`r`n`r`nパス: $LogDir`r`nエラー: $($_.Exception.Message)",0,"ディレクトリエラー",0x10) | Out-Null
            exit 1
        }
    }
    
    # ユーザーとホスト情報の取得
    $script:gblUser = $env:USERNAME
    $script:glbHostName = $env:COMPUTERNAME

    # YAMLファイルから必要な情報を取得
    $LogFileName = $yaml.LOG.FILENAME
    $Logextension = $yaml.LOG.EXTENSION

    # ログファイルパスの定義
    $script:Log = Join-Path -Path $LogDir -ChildPath ($LogFileName + "_" + (Get-Date -Format "yyyyMMdd-HHmmss") + $Logextension)    
}
process{
    # タイトル表示
    Write-CommonLog -Message "HOST: $script:glbHostName" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "USER: $script:gblUser" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running PowerShell Version: $($PSVersionTable.PSVersion)" -LogPath $script:Log -Level "INFO"
    $ProjectLength = ("Project name: " + $yaml.Project).Length
    $ProjectLine = "=" * $ProjectLength
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project name: $($yaml.Project)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project version: $($yaml.Version)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    
    # 改行をログに出力
    "`r`n" | Tee-Object -FilePath $script:Log -Append | Out-Null

    # ILSpyCmdがインストールされているか確認
    Write-CommonLog -Message "Checking if ILSpyCmd is already installed..." -LogPath $script:Log -Level "INFO"
    $ILSpyCmdInstalled = Get-Command "ilspycmd" -ErrorAction SilentlyContinue
    if ($ILSpyCmdInstalled) {
        Write-CommonLog -Message "✅ ILSpyCmd is already installed." -LogPath $script:Log -Level "INFO"
        Write-CommonLog -Message "Version: $($ILSpyCmdInstalled.Version)" -LogPath $script:Log -Level "INFO"
        $script:comObject.Popup("ILSpyCmdはすでにインストールされています。`r`n`r`nバージョン: $($ILSpyCmdInstalled.Version)`r`n`r`nプログラムを終了します。",0,"確認完了",0x40) | Out-Null
        Invoke-Item -Path $script:Log
        exit 0
    } else {
        Write-CommonLog -Message "ILSpyCmd is not installed. Proceeding with installation..." -LogPath $script:Log -Level "INFO"
    }

    # .NET SDKの存在確認
    Write-CommonLog -Message "Checking for .NET SDK installation..." -LogPath $script:Log -Level "INFO"
    $dotnetCommand = Get-Command "dotnet" -ErrorAction SilentlyContinue
    $sdks = if ($dotnetCommand) { & dotnet --list-sdks 2>$null } else { $null }
    
    # SDKのインストール
    if (-not $sdks) {
        Write-CommonLog -Message ".NET SDK is not installed." -LogPath $script:Log -Level "WARN"
        [int]$retButton = $script:comObject.Popup("dotnet(sdk)がインストールされていません。`r`n`r`n.NET SDK をインストールしますか？`r`n`r`n※インストールには数分かかる場合があります。",0,"SDK未検出",36)
        switch($retButton){
            # はい(.NET SDKをインストール)
            6 {
                # インストーラー格納先
                $SdkFolderName = $yaml.DotnetSdk.SdkFolder
                $SdkFolderPath = Join-Path -Path $UpperPath -ChildPath $SdkFolderName
                $installerPath = Join-Path -Path $SdkFolderPath -ChildPath $yaml.DotnetSdk.Installer
                $verSDK = $yaml.DotnetSdk.Version
                
                # インストーラーの存在確認
                if (-not (Test-Path -Path $installerPath)) {
                    Write-CommonLog -Message ".NET SDK installer not found: $installerPath" -LogPath $script:Log -Level "ERROR"
                    $script:comObject.Popup("SDKインストーラーが見つかりません。`r`n`r`nパス: $installerPath`r`n`r`nプログラムを終了します。",0,"ファイルエラー",0x10) | Out-Null
                    Invoke-Item -Path $script:Log
                    exit 1
                }

                # dotnet SDKのインストール
                Write-CommonLog -Message "Starting .NET SDK ($verSDK) installation..." -LogPath $script:Log -Level "INFO"
                $script:comObject.Popup("dotnet SDK ($verSDK) のインストールを開始します。`r`n`r`nインストールウィンドウが表示されます。`r`n完了まで数分かかる場合があります。",0,"インストール開始",0x40) | Out-Null

                Try{
                    # インストール（パッシブモード：進捗表示あり、操作不要）
                    $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/install /passive /norestart" -Wait -PassThru
                    
                    if ($installProcess.ExitCode -eq 0) {
                        Write-CommonLog -Message ".NET SDK installation completed successfully (Exit Code: 0)." -LogPath $script:Log -Level "INFO"
                        
                        # 環境変数のPATHを更新（現在のセッションに反映）
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                        Write-CommonLog -Message "Environment PATH updated." -LogPath $script:Log -Level "INFO"
                        
                        # インストール確認（PATH更新後に再確認）
                        Start-Sleep -Seconds 2
                        $dotnetCheck = Get-Command "dotnet" -ErrorAction SilentlyContinue
                        if ($dotnetCheck) {
                            $dotnetVersion = & dotnet --version 2>$null
                            Write-CommonLog -Message "✅ .NET SDK installed successfully. Version: $dotnetVersion" -LogPath $script:Log -Level "INFO"
                        } else {
                            Write-CommonLog -Message "Warning: dotnet command not found after installation. May require system restart." -LogPath $script:Log -Level "WARN"
                            $script:comObject.Popup("SDKのインストールは完了しましたが、`r`nコマンドが認識されません。`r`n`r`nシステムの再起動が必要な場合があります。",0,"警告",0x30) | Out-Null
                        }
                    } else {
                        Write-CommonLog -Message ".NET SDK installation failed (Exit Code: $($installProcess.ExitCode))." -LogPath $script:Log -Level "ERROR"
                        $script:comObject.Popup("dotnet SDKのインストールに失敗しました。`r`n`r`n終了コード: $($installProcess.ExitCode)`r`n`r`nプログラムを終了します。",0,"インストールエラー",0x10) | Out-Null
                        Invoke-Item -Path $script:Log
                        exit 1
                    }
            
                } catch {
                    Write-CommonLog -Message "Failed to start .NET SDK installation: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                    $script:comObject.Popup("SDKインストーラーの起動に失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`nプログラムを終了します。",0,"起動エラー",0x10) | Out-Null
                    Invoke-Item -Path $script:Log
                    exit 1
                }
            }                
            # いいえ(スクリプト終了)
            7 {
                Write-CommonLog -Message "User declined .NET SDK installation. Exiting script." -LogPath $script:Log -Level "INFO"
                $script:comObject.Popup(".NET SDKのインストールがキャンセルされました。`r`n`r`nプログラムを終了します。",0,"キャンセル",0x40) | Out-Null
                Invoke-Item -Path $script:Log
                exit 0
            }
        }

    } else {
        # dotnetがインストールされていた場合の処理
        Write-CommonLog -Message "✅ .NET SDK is already installed." -LogPath $script:Log -Level "INFO"
        $DotnetSdks = & dotnet --list-sdks 2>$null
        Write-CommonLog -Message "Installed SDKs:" -LogPath $script:Log -Level "INFO"
        foreach ($sdk in $DotnetSdks) {
            Write-CommonLog -Message "  $sdk" -LogPath $script:Log -Level "INFO"
        }
    }

    # ILSpyCmdのインストール
    Write-CommonLog -Message "Starting ILSpyCmd installation..." -LogPath $script:Log -Level "INFO"
    $script:comObject.Popup("ILSpyCmdをインストールします。`r`n`r`nコマンドプロンプトウィンドウが表示されます。`r`n完了まで数分かかる場合があります。",0,"インストール開始",0x40) | Out-Null
    
    try {
        # dotnet tool install --global ilspycmd をコマンドプロンプトで実行
        $cmdCommand = 'dotnet tool install --global ilspycmd && echo. && echo ILSpyCmd のインストールが完了しました。 && echo Enterキーを押して終了してください。 && pause'
        $installProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmdCommand" -Wait -PassThru -ErrorAction Stop
        
        if ($installProcess.ExitCode -eq 0) {
            Write-CommonLog -Message "'dotnet tool install --global ilspycmd' executed successfully (Exit Code: 0)." -LogPath $script:Log -Level "INFO"
            
            # インストール確認
            Start-Sleep -Seconds 2
            $ilspyCheck = Get-Command "ilspycmd" -ErrorAction SilentlyContinue
            if ($ilspyCheck) {
                Write-CommonLog -Message "✅ ILSpyCmd installed successfully." -LogPath $script:Log -Level "INFO"
                Write-CommonLog -Message "ILSpyCmd Path: $($ilspyCheck.Source)" -LogPath $script:Log -Level "INFO"
                $script:comObject.Popup("ILSpyCmdのインストールが完了しました。`r`n`r`nインストール先: $($ilspyCheck.Source)",0,"インストール完了",0x40) | Out-Null
            } else {
                Write-CommonLog -Message "Warning: ilspycmd command not found after installation." -LogPath $script:Log -Level "WARN"
                $script:comObject.Popup("インストールは完了しましたが、`r`nコマンドが認識されません。`r`n`r`nターミナルの再起動が必要な場合があります。",0,"警告",0x30) | Out-Null
            }
        } else {
            Write-CommonLog -Message "ILSpyCmd installation failed (Exit Code: $($installProcess.ExitCode))." -LogPath $script:Log -Level "ERROR"
            $script:comObject.Popup("ILSpyCmdのインストールに失敗しました。`r`n`r`n終了コード: $($installProcess.ExitCode)`r`n`r`n詳細はログを確認してください。",0,"インストールエラー",0x10) | Out-Null
            Invoke-Item -Path $script:Log
            exit 1
        }
    } catch {
        Write-CommonLog -Message "Failed to install ILSpyCmd: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("ILSpyCmdのインストールに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`n詳細はログを確認してください。",0,"インストールエラー",0x10) | Out-Null
        Invoke-Item -Path $script:Log
        exit 1
    }
}
end{
    # スクリプトの終了メッセージをログに出力
    Write-CommonLog -Message "Script completed successfully." -LogPath $script:Log -Level "INFO"
    
    # COMオブジェクトの解放
    if ($script:comObject) {
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:comObject) | Out-Null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        } catch {
            # COMオブジェクト解放のエラーは無視
        }
    }
    
    # ログファイルを開く
    Invoke-Item -Path $script:Log
}
