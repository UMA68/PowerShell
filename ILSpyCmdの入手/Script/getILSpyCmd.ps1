<#
.SYNOPSIS
    ILSpyCmd (.NET逆コンパイルツール) をインストールします。

.DESCRIPTION
    このスクリプトは、ILSpyCmdとその前提条件である.NET SDKを自動的にインストールします。
    
    主な機能:
    - ILSpyCmdのインストール状態確認とバージョン比較
    - 管理者権限の確認と要求
    - ネットワーク接続の検証（NuGet.org）
    - .NET SDKの存在確認と自動インストール
    - インストーラーファイルの検証（サイズ、読み取り可能性）
    - インストールタイムアウト処理（10分）
    - インストール失敗時のロールバック機能
    - YAMLファイルからの設定読み込みと検証
    - 詳細なログ出力（INFO、WARN、ERROR、DEBUG）
    - ユーザーへの対話的な確認

    終了コード:
    - 0: 正常終了
    - 1: 一般エラー（ファイル未検出、スクリプトエラーなど）
    - 2: YAML検証エラー（必須フィールド不足）
    - 3: 権限不足（管理者権限が必要）
    - 4: ネットワークエラー（NuGet.orgに接続不可）
    - 5: インストーラー検証エラー（ファイル破損の可能性）
    - 6: タイムアウトエラー（インストールが10分を超過）

.PARAMETER EnvYaml
    使用するYAML設定ファイル名。デフォルトは "getILSpyCmd.yaml" です。
    YAMLファイルは "YAML" フォルダに配置する必要があります。
    
    必須YAMLフィールド:
    - Project: プロジェクト名
    - Version: スクリプトバージョン
    - LOG.FILENAME: ログファイル名
    - LOG.EXTENSION: ログ拡張子
    - DotnetSdk.SdkFolder: SDKインストーラー格納フォルダ名
    - DotnetSdk.Installer: SDKインストーラーファイル名
    - DotnetSdk.Version: インストールするSDKバージョン
    
    オプションYAMLフィールド:
    - ILSpyCmd.ExpectedVersion: 期待するILSpyCmdバージョン

.EXAMPLE
    .\getILSpyCmd.ps1
    デフォルト設定（getILSpyCmd.yaml）でILSpyCmdをインストールします。
    管理者権限、ネットワーク接続、YAMLファイルの検証を自動実行します。

.EXAMPLE
    .\getILSpyCmd.ps1 -EnvYaml "custom.yaml"
    カスタムYAML設定ファイル（custom.yaml）を使用してインストールします。

.NOTES
    File Name      : getILSpyCmd.ps1
    Author         : UMA
    Prerequisite   : PowerShell 7.x, powershell-yaml module
    Version        : 1.2.0
    
    前提条件:
    - PowerShell 7.x 以上
    - powershell-yamlモジュールがインストールされていること
    - Write-CommonLog.ps1が Common フォルダに存在すること
    - getILSpyCmd.yaml が YAML フォルダに存在すること
    - .NET SDKインストーラーが指定フォルダに存在すること
    - インターネット接続（NuGet.orgへのアクセス確認）
    - 管理者権限（.NET SDKインストール時に必要）
    
    動作詳細:
    1. YAML設定ファイルの読み込みと必須フィールド検証
    2. ILSpyCmdのインストール状態確認とバージョン比較
    3. 管理者権限チェック（SDK未インストール時）
    4. ネットワーク接続確認（NuGet.orgへPing/HTTP）
    5. .NET SDKの存在確認と必要に応じてインストール
    6. インストーラーファイルの整合性検証
    7. タイムアウト付きSDKインストール（最大10分）
    8. 環境変数PATH更新と反映確認
    9. ILSpyCmdのグローバルツールとしてのインストール
    10. インストール失敗時の自動ロールバック提案
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
        Write-Error "Exit Code 1: Common script import failed - $($_.Exception.Message)"
        exit 1
    }

    # YAMLファイルの存在チェック
    if (-not (Test-Path -Path $YamlPath)) {
        $script:comObject.Popup("YAMLファイルが存在しません。`r`n`r`nパス: $YamlPath",0,"ファイルエラー",0x10) | Out-Null
        Write-Error "Exit Code 1: YAML file not found - $YamlPath"
        exit 1
    }
    
    # YAMLファイルの読み込み（まず基本的なYAML読み込みのみ）
    try {
        Import-Module -Name "powershell-yaml" -ErrorAction Stop
        $yaml = Get-Content -Path $YamlPath -Raw -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    } catch {
        $script:comObject.Popup("YAMLファイルの読み込みに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)",0,"YAML読み込みエラー",0x10) | Out-Null
        Write-Error "Exit Code 1: YAML parse failed - $($_.Exception.Message)"
        exit 1
    }
    
    # YAMLファイルにバージョン指定があれば、指定バージョンで再インポート
    if ($yaml.Module.'Powershell-Yaml'.Version) {
        [string]$PowershellYamlVersion = $yaml.Module.'Powershell-Yaml'.Version.ToString()
        try {
            Import-Module -Name "powershell-yaml" -RequiredVersion $PowershellYamlVersion -Force -ErrorAction Stop
        } catch {
            $script:comObject.Popup("powershell-yaml (v$PowershellYamlVersion) モジュールのインポートに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)",0,"モジュールエラー",0x10) | Out-Null
            Write-Error "Exit Code 1: Module import failed - powershell-yaml v$PowershellYamlVersion"
            exit 1
        }
    }
    
    # YAML必須フィールドの検証
    $requiredFields = @(
        @{Path="LOG.FILENAME"; Name="ログファイル名"},
        @{Path="LOG.EXTENSION"; Name="ログ拡張子"},
        @{Path="Project"; Name="プロジェクト名"},
        @{Path="Version"; Name="バージョン"},
        @{Path="DotnetSdk.SdkFolder"; Name="SDKフォルダ名"},
        @{Path="DotnetSdk.Installer"; Name="SDKインストーラー名"},
        @{Path="DotnetSdk.Version"; Name="SDKバージョン"}
    )
    
    $missingFields = @()
    foreach ($field in $requiredFields) {
        $pathParts = $field.Path -split '\.'
        $value = $yaml
        $found = $true
        
        foreach ($part in $pathParts) {
            if ($null -eq $value) {
                $found = $false
                break
            }
            
            # OrderedDictionary または Hashtable の場合
            if ($value -is [System.Collections.IDictionary]) {
                if ($value.Contains($part)) {
                    $value = $value[$part]
                } else {
                    $found = $false
                    # デバッグ情報をログに記録
                    if ($script:Log -and (Test-Path $script:Log)) {
                        $availableKeys = ($value.Keys | ForEach-Object { $_ }) -join ', '
                        Write-CommonLog -Message "YAML validation: Field '$part' not found in path '$($field.Path)'. Available keys: $availableKeys" -LogPath $script:Log -Level "DEBUG"
                    }
                    break
                }
            }
            # PSCustomObject の場合
            elseif ($value.PSObject.Properties.Name -contains $part) {
                $value = $value.$part
            } else {
                $found = $false
                # デバッグ情報をログに記録
                if ($script:Log -and (Test-Path $script:Log)) {
                    Write-CommonLog -Message "YAML validation: Field '$part' not found in path '$($field.Path)'. Available keys: $($value.PSObject.Properties.Name -join ', ')" -LogPath $script:Log -Level "DEBUG"
                }
                break
            }
        }
        
        if (-not $found -or [string]::IsNullOrWhiteSpace($value)) {
            $missingFields += "  - $($field.Name) ($($field.Path))"
        }
    }
    
    if ($missingFields.Count -gt 0) {
        $errorMsg = "YAMLファイルに必須フィールドが不足しています。`r`n`r`n不足フィールド:`r`n" + ($missingFields -join "`r`n")
        $script:comObject.Popup($errorMsg,0,"YAML検証エラー",0x10) | Out-Null
        Write-Error "Exit Code 2: YAML validation failed - Missing required fields"
        exit 2
    }

    # ログディレクトリが作成されていなければ作成
    if (-not (Test-Path -Path $LogDir)) {
        try {
            New-Item -Path $LogDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            $script:comObject.Popup("ログディレクトリの作成に失敗しました。`r`n`r`nパス: $LogDir`r`nエラー: $($_.Exception.Message)",0,"ディレクトリエラー",0x10) | Out-Null
            Write-Error "Exit Code 1: Log directory creation failed - $LogDir"
            exit 1
        }
    }
    
    # ユーザーとホスト情報の取得
    $script:gblUser = $env:USERNAME
    $script:glbHostName = $env:COMPUTERNAME

    # YAMLファイルから必要な情報を取得
    $LogFileName = $yaml.LOG.FILENAME
    $Logextension = $yaml.LOG.EXTENSION

    # ログファイルパスの定義（ミリ秒を含めて重複を回避）
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $milliseconds = (Get-Date).Millisecond.ToString("000")
    $script:Log = Join-Path -Path $LogDir -ChildPath ($LogFileName + "_" + $timestamp + "-" + $milliseconds + $Logextension)
    
    # 管理者権限の確認
    $script:isAdmin = $false
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $script:isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
process{
    # タイトル表示
    Write-CommonLog -Message "HOST: $script:glbHostName" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "USER: $script:gblUser" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running as Administrator: $script:isAdmin" -LogPath $script:Log -Level "INFO"
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
        
        # バージョン情報の詳細ログ
        $installedVersion = $ILSpyCmdInstalled.Version
        $installedPath = $ILSpyCmdInstalled.Source
        Write-CommonLog -Message "Installed version: $installedVersion" -LogPath $script:Log -Level "INFO"
        Write-CommonLog -Message "Installation path: $installedPath" -LogPath $script:Log -Level "INFO"
        
        # YAMLに期待バージョンがあれば比較
        if ($yaml.ILSpyCmd -and $yaml.ILSpyCmd.ExpectedVersion) {
            $expectedVersion = $yaml.ILSpyCmd.ExpectedVersion
            Write-CommonLog -Message "Expected version (from YAML): $expectedVersion" -LogPath $script:Log -Level "INFO"
            
            if ($installedVersion.ToString() -ne $expectedVersion) {
                Write-CommonLog -Message "Version mismatch detected. Installed: $installedVersion, Expected: $expectedVersion" -LogPath $script:Log -Level "WARN"
                $script:comObject.Popup("ILSpyCmdはインストール済みですが、バージョンが異なります。`r`n`r`nインストール済み: $installedVersion`r`n期待バージョン: $expectedVersion`r`n`r`nプログラムを終了します。",0,"バージョン不一致",0x30) | Out-Null
            } else {
                Write-CommonLog -Message "Version matches expected version." -LogPath $script:Log -Level "INFO"
                $script:comObject.Popup("ILSpyCmdはすでにインストールされています。`r`n`r`nバージョン: $installedVersion (正常)`r`n`r`nプログラムを終了します。",0,"確認完了",0x40) | Out-Null
            }
        } else {
            $script:comObject.Popup("ILSpyCmdはすでにインストールされています。`r`n`r`nバージョン: $installedVersion`r`n`r`nプログラムを終了します。",0,"確認完了",0x40) | Out-Null
        }
        
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
        
        # 管理者権限の確認
        if (-not $script:isAdmin) {
            Write-CommonLog -Message "Administrator privileges required for SDK installation." -LogPath $script:Log -Level "WARN"
            $script:comObject.Popup(".NET SDKのインストールには管理者権限が必要です。`r`n`r`nこのスクリプトを管理者として実行してください。`r`n`r`nプログラムを終了します。",0,"管理者権限が必要",0x30) | Out-Null
            Write-CommonLog -Message "Exit Code 3: Insufficient privileges - Administrator rights required" -LogPath $script:Log -Level "ERROR"
            Invoke-Item -Path $script:Log
            exit 3
        }
        
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
                
                # インストーラーファイルの検証
                try {
                    $installerFile = Get-Item -Path $installerPath -ErrorAction Stop
                    $installerSizeMB = [math]::Round($installerFile.Length / 1MB, 2)
                    Write-CommonLog -Message "Installer file size: $installerSizeMB MB" -LogPath $script:Log -Level "INFO"
                    
                    # ファイルサイズが異常に小さい場合は警告（通常50MB以上）
                    if ($installerFile.Length -lt 10MB) {
                        Write-CommonLog -Message "Warning: Installer file size is unusually small ($installerSizeMB MB). File may be corrupted." -LogPath $script:Log -Level "WARN"
                        [int]$continueButton = $script:comObject.Popup("警告：インストーラーのファイルサイズが異常に小さいです ($installerSizeMB MB)。`r`n`r`nファイルが破損している可能性があります。`r`n`r`n続行しますか？",0,"ファイル検証警告",52)
                        if ($continueButton -eq 7) {
                            Write-CommonLog -Message "User chose not to continue with potentially corrupted installer." -LogPath $script:Log -Level "INFO"
                            Write-CommonLog -Message "Exit Code 5: Installer validation warning - User declined to continue" -LogPath $script:Log -Level "WARN"
                            Invoke-Item -Path $script:Log
                            exit 5
                        }
                    }
                    
                    # 読み取り可能かチェック
                    $fileStream = [System.IO.File]::OpenRead($installerPath)
                    $fileStream.Close()
                    Write-CommonLog -Message "Installer file is accessible and appears valid." -LogPath $script:Log -Level "INFO"
                } catch {
                    Write-CommonLog -Message "Installer file validation failed: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                    Write-CommonLog -Message "Exit Code 5: Installer validation failed - $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                    $script:comObject.Popup("インストーラーファイルの検証に失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`nプログラムを終了します。",0,"ファイル検証エラー",0x10) | Out-Null
                    Invoke-Item -Path $script:Log
                    exit 5
                }

                # dotnet SDKのインストール
                Write-CommonLog -Message "Starting .NET SDK ($verSDK) installation..." -LogPath $script:Log -Level "INFO"
                $script:comObject.Popup("dotnet SDK ($verSDK) のインストールを開始します。`r`n`r`nインストールウィンドウが表示されます。`r`n完了まで数分かかる場合があります。",0,"インストール開始",0x40) | Out-Null

                # インストール前の状態を記録（ロールバック用）
                $preSdks = if (Get-Command "dotnet" -ErrorAction SilentlyContinue) { & dotnet --list-sdks 2>$null } else { @() }
                Write-CommonLog -Message "Pre-installation SDK count: $($preSdks.Count)" -LogPath $script:Log -Level "INFO"

                Try{
                    # インストール（パッシブモード：進捗表示あり、操作不要）
                    Write-CommonLog -Message "Executing installer with 10-minute timeout..." -LogPath $script:Log -Level "INFO"
                    $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/install /passive /norestart" -PassThru
                    
                    # タイムアウト処理（10分）
                    $timeoutSeconds = 600
                    $waitResult = $installProcess.WaitForExit($timeoutSeconds * 1000)
                    
                    if (-not $waitResult) {
                        # タイムアウト発生
                        Write-CommonLog -Message "Installation process timed out after $timeoutSeconds seconds." -LogPath $script:Log -Level "ERROR"
                        Write-CommonLog -Message "Exit Code 6: Installation timeout - Process exceeded $timeoutSeconds seconds" -LogPath $script:Log -Level "ERROR"
                        try {
                            $installProcess.Kill()
                            Write-CommonLog -Message "Installation process terminated." -LogPath $script:Log -Level "WARN"
                        } catch {
                            Write-CommonLog -Message "Failed to terminate installation process: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                        }
                        $script:comObject.Popup("SDKのインストールがタイムアウトしました（${timeoutSeconds}秒）。`r`n`r`nインストールプロセスを中断しました。`r`n`r`nプログラムを終了します。",0,"タイムアウトエラー",0x10) | Out-Null
                        Invoke-Item -Path $script:Log
                        exit 6
                    }
                    
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
                        # インストール失敗時のロールバック試行
                        Write-CommonLog -Message ".NET SDK installation failed (Exit Code: $($installProcess.ExitCode))." -LogPath $script:Log -Level "ERROR"
                        
                        # インストール後の状態確認
                        $postSdks = if (Get-Command "dotnet" -ErrorAction SilentlyContinue) { & dotnet --list-sdks 2>$null } else { @() }
                        if ($postSdks.Count -gt $preSdks.Count) {
                            Write-CommonLog -Message "Partial installation detected. Attempting rollback..." -LogPath $script:Log -Level "WARN"
                            [int]$rollbackButton = $script:comObject.Popup("SDKのインストールに失敗しましたが、一部がインストールされた可能性があります。`r`n`r`nロールバック（削除）を試みますか？",0,"ロールバック確認",36)
                            if ($rollbackButton -eq 6) {
                                try {
                                    Write-CommonLog -Message "User chose to rollback. Executing uninstaller..." -LogPath $script:Log -Level "INFO"
                                    $uninstallProcess = Start-Process -FilePath $installerPath -ArgumentList "/uninstall /passive /norestart" -Wait -PassThru
                                    if ($uninstallProcess.ExitCode -eq 0) {
                                        Write-CommonLog -Message "Rollback completed successfully." -LogPath $script:Log -Level "INFO"
                                    } else {
                                        Write-CommonLog -Message "Rollback failed (Exit Code: $($uninstallProcess.ExitCode))." -LogPath $script:Log -Level "ERROR"
                                    }
                                } catch {
                                    Write-CommonLog -Message "Rollback failed: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                                }
                            }
                        }
                        
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
    
    # ネットワーク接続の確認（NuGet.orgへの接続テスト）
    Write-CommonLog -Message "Checking network connectivity to NuGet.org..." -LogPath $script:Log -Level "INFO"
    try {
        $testConnection = Test-Connection -ComputerName "nuget.org" -Count 2 -Quiet -ErrorAction SilentlyContinue
        if (-not $testConnection) {
            # Test-Connectionが失敗した場合、HTTP接続で再試行
            try {
                $webRequest = [System.Net.WebRequest]::Create("https://www.nuget.org")
                $webRequest.Timeout = 5000
                $response = $webRequest.GetResponse()
                $response.Close()
                $testConnection = $true
                Write-CommonLog -Message "Network connectivity confirmed via HTTP." -LogPath $script:Log -Level "INFO"
            } catch {
                $testConnection = $false
            }
        } else {
            Write-CommonLog -Message "Network connectivity confirmed via ICMP." -LogPath $script:Log -Level "INFO"
        }
        
        if (-not $testConnection) {
            Write-CommonLog -Message "Network connectivity check failed. Cannot reach NuGet.org." -LogPath $script:Log -Level "ERROR"
            Write-CommonLog -Message "Exit Code 4: Network connectivity error - Unable to reach NuGet.org" -LogPath $script:Log -Level "ERROR"
            $script:comObject.Popup("インターネット接続が確認できません。`r`n`r`nILSpyCmdのインストールにはインターネット接続が必要です。`r`n`r`nネットワーク接続を確認してください。",0,"ネットワークエラー",0x10) | Out-Null
            Invoke-Item -Path $script:Log
            exit 4
        }
    } catch {
        Write-CommonLog -Message "Network connectivity check encountered an error: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
        Write-CommonLog -Message "Proceeding with installation attempt..." -LogPath $script:Log -Level "INFO"
    }
    
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
