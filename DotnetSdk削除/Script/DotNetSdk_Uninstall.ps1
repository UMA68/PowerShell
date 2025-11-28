<#
.SYNOPSIS
    .NET SDK をアンインストールします。

.DESCRIPTION
    このスクリプトは、インストールされている.NET SDKを安全にアンインストールします。
    dotnet-core-uninstallツールを使用してSDKを削除します。
    
    主な機能:
    - 管理者権限の確認と要求
    - インストール済みSDKの一覧表示
    - dotnetコマンドとdotnet-core-uninstallツールの存在確認
    - バージョン番号の形式検証
    - 削除前の確認ダイアログ
    - 削除後の検証
    - 詳細なログ出力（INFO、WARN、ERROR）
    
    終了コード:
    - 0: 正常終了
    - 1: 一般エラー（必要なコマンド未検出など）
    - 2: ユーザーキャンセル
    - 3: 権限不足（管理者権限が必要）
    - 4: バージョン検証エラー（指定バージョンが未インストール）
    - 5: アンインストール失敗

.PARAMETER SdkVersion
    削除する.NET SDKのバージョン番号（例: 9.0.301）。
    カンマ区切りで複数バージョンを指定可能（例: "9.0.301,8.0.100"）。
    省略した場合は、対話的に入力を求められます。

.PARAMETER WhatIf
    ドライランモード。実際には削除せず、削除対象を表示するのみです。
    安全確認のために使用してください。
    これは共通パラメーターとして自動的に提供されます。

.PARAMETER Verbose
    詳細モード。各処理ステップの詳細情報をコンソールに出力します。
    デバッグやトラブルシューティングに便利です。
    これは共通パラメーター（CmdletBinding）として自動的に提供されます。

.PARAMETER SkipAdminCheck
    管理者権限チェックをスキップします。デバッグ用途のみで使用してください。
    本番環境では使用しないでください。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1
    
    対話的モード。インストール済みSDKの一覧を表示し、削除するバージョンの入力を求めます。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301"
    
    指定したバージョン9.0.301の.NET SDKを削除します。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301,8.0.100"
    
    複数のバージョン（9.0.301と8.0.100）を一括削除します。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301" -WhatIf
    
    ドライランモード。実際には削除せず、削除対象を確認します。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301" -Verbose
    
    詳細モードで実行し、各処理ステップの詳細情報を表示します。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1 -SkipAdminCheck
    
    管理者権限チェックをスキップしてデバッグ実行します（デバッグ用途のみ）。

.NOTES
    File Name      : DotNetSdk_Uninstall.ps1
    Author         : UMA
    Prerequisite   : PowerShell 7.x, dotnet-core-uninstall tool
    Version        : 1.1.0
    
    前提条件:
    - PowerShell 7.x 以上
    - dotnet-core-uninstallツールがインストールされていること
    - .NET SDKがインストールされていること
    - 管理者権限での実行
    - Write-CommonLog.ps1が Common フォルダに存在すること
    
    動作詳細:
    1. 管理者権限の確認
    2. 必要なコマンド（dotnet、dotnet-core-uninstall）の存在確認
    3. 古いログファイルのクリーンアップ（30日以上経過）
    4. インストール済みSDKの一覧表示
    5. 削除対象バージョンの入力または検証
    6. バージョン形式の検証（x.y.z または x.y.z.w形式）
    7. 指定バージョンがインストールされているか確認
    8. 現状のバックアップ（SDK情報、グローバルツールリスト）
    9. ユーザー確認ダイアログ
    10. dotnet-core-uninstallコマンドでアンインストール実行（5分タイムアウト）
    11. 削除後の検証（SDKリストから削除されているか確認）
    12. 環境変数PATH更新の提案
    13. ログファイルを開いて結果を表示
    
    多言語対応:
    現在は日本語のみをサポートしています。
    英語対応が必要な場合は、メッセージを変数化して言語ファイルから読み込む設計を検討してください。

.LINK
    https://github.com/UMA68/PowerShell
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$SdkVersion,            # 削除する .NET SDKバージョン（省略時は対話的に入力を求める）
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,                # ドライランモード（削除せず確認のみ）
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAdminCheck         # 管理者権限チェックをスキップします。デバッグ用途のみで使用してください。
)

begin {
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path   # スクリプトの実行パスを取得
    $UpperPath = Split-Path -Parent $scriptPath                     # スクリプトの親パスを取得
    $PowerShellDir = Split-Path -Parent $UpperPath                  # スクリプトの親パスの親パスを取得
    $LogDir = Join-Path -Path $UpperPath -ChildPath "LOG"           # ログディレクトリのパスを指定
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"   # 共通スクリプトのパス
    
    # COMオブジェクトの作成（スクリプト全体で使用）
    $script:comObject = $null
    try {
        $script:comObject = New-Object -ComObject WScript.Shell
    } catch {
        Write-Error "COMオブジェクトの作成に失敗しました: $_"
        exit 1
    }

    # InputBox使用のためにアセンブリをロード（PowerShell 7対応）
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
    } catch {
        Write-Error "Microsoft.VisualBasicアセンブリのロードに失敗しました: $_"
        # InputBoxが使えない場合でも続行（COMダイアログで代替）
    }

    # 共通スクリプトのインポート
    $commonLogPath = Join-Path -Path $comPath -ChildPath "Write-CommonLog.ps1"
    try {
        . $commonLogPath -ErrorAction Stop
    } catch {
        $script:comObject.Popup("共通スクリプト (Write-CommonLog.ps1) を読み込めませんでした。処理を終了します。`r`n`r`nエラー: $($_.Exception.Message)", 0, "スクリプトエラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: Common script import failed - $($_.Exception.Message)"
        exit 1
    }

    # ログディレクトリが作成されていなければ作成
    if (-not (Test-Path -Path $LogDir)) {
        try {
            New-Item -Path $LogDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            $script:comObject.Popup("ログディレクトリの作成に失敗しました。`r`n`r`nパス: $LogDir`r`nエラー: $($_.Exception.Message)", 0, "ディレクトリエラー", 0x10) | Out-Null
            Write-Error "Exit Code 1: Log directory creation failed - $LogDir"
            exit 1
        }
    }
    
    # 古いログファイルのクリーンアップ（30日以上経過したログを削除）
    try {
        $logRetentionDays = 30
        $cutoffDate = (Get-Date).AddDays(-$logRetentionDays)
        $oldLogs = Get-ChildItem -Path $LogDir -Filter "DotNetSdk_Uninstall_*.log" -ErrorAction SilentlyContinue | 
                   Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldLogs -and $oldLogs.Count -gt 0) {
            foreach ($oldLog in $oldLogs) {
                Remove-Item -Path $oldLog.FullName -Force -ErrorAction SilentlyContinue
            }
            # 削除数を後でログに記録（ログファイル作成後）
            $script:CleanedLogCount = $oldLogs.Count
        } else {
            $script:CleanedLogCount = 0
        }
    } catch {
        # ログクリーンアップ失敗は続行可能なエラー
        $script:CleanedLogCount = -1
    }
    
    # ユーザーとホスト情報の取得
    $script:User = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME

    # ログファイルパスの定義（ミリ秒を含めて重複を回避）
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $milliseconds = (Get-Date).Millisecond.ToString("000")
    $script:Log = Join-Path -Path $LogDir -ChildPath ("DotNetSdk_Uninstall_" + $timestamp + "-" + $milliseconds + ".log")
    
    # 管理者権限の確認
    $script:isAdmin = $false
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $script:isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    # 管理者権限がない場合、かつスキップフラグが立っていない場合はエラー終了
    if (-not $script:isAdmin -and -not $SkipAdminCheck) {
        Write-CommonLog -Message "Administrator privileges required for .NET SDK uninstallation." -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup(".NET SDKのアンインストールには管理者権限が必要です。`r`n`r`nこのスクリプトを管理者として実行してください。`r`n`r`nプログラムを終了します。", 0, "管理者権限が必要", 0x30) | Out-Null
        Write-Error "Exit Code 3: Insufficient privileges - Administrator rights required"
        Invoke-Item -Path $script:Log
        exit 3
    }

    # デバッグモードで権限チェックをスキップした場合の警告ログ
    if ($SkipAdminCheck) {
        Write-CommonLog -Message "⚠️ WARNING: Admin check skipped (Debug mode)" -LogPath $script:Log -Level "WARN"
    }
}

process {
    # タイトル表示
    Write-CommonLog -Message "HOST: $script:HostName" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "USER: $script:User" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running as Administrator: $script:isAdmin" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running PowerShell Version: $($PSVersionTable.PSVersion)" -LogPath $script:Log -Level "INFO"
    
    # ログクリーンアップ結果を記録
    if ($script:CleanedLogCount -gt 0) {
        Write-CommonLog -Message "Log rotation: Cleaned up $script:CleanedLogCount old log file(s) (older than 30 days)" -LogPath $script:Log -Level "INFO"
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {  # Verboseモードで詳細表示
            Write-Verbose "Cleaned up $script:CleanedLogCount old log files"
        }
    } elseif ($script:CleanedLogCount -eq -1) {
        Write-CommonLog -Message "Log rotation: Failed to clean up old log files" -LogPath $script:Log -Level "WARN"
    }
    
    # Verboseモードの通知
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        Write-CommonLog -Message "Verbose mode enabled" -LogPath $script:Log -Level "INFO"
        Write-Verbose "=== Verbose Mode Enabled ==="
        Write-Verbose "Log file: $script:Log"
        Write-Verbose "Script version: 1.1.0"
    }
    
    $ProjectLine = "=" * 50
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project name: Uninstall .NET SDK" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Script version: 1.0.0" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    
    # 改行をログに出力
    "`r`n" | Tee-Object -FilePath $script:Log -Append | Out-Null

    # dotnetコマンドの存在確認
    Write-CommonLog -Message "Checking for dotnet command..." -LogPath $script:Log -Level "INFO"
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {  # Verboseモードで詳細表示
        Write-Verbose "Checking for dotnet command..."
    }
    $dotnetCommand = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if (-not $dotnetCommand) {  # dotnetコマンドが見つからない場合
        Write-CommonLog -Message "dotnet command not found. .NET SDK may not be installed." -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("dotnetコマンドが見つかりません。`r`n`r`n.NET SDKがインストールされていない可能性があります。`r`n`r`nプログラムを終了します。", 0, "コマンドエラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: dotnet command not found"
        Invoke-Item -Path $script:Log
        exit 1
    }
    Write-CommonLog -Message "dotnet command found: $($dotnetCommand.Source)" -LogPath $script:Log -Level "INFO"
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        Write-Verbose "dotnet command found at: $($dotnetCommand.Source)"
    }

    # dotnet-core-uninstallコマンドの存在確認
    Write-CommonLog -Message "Checking for dotnet-core-uninstall tool..." -LogPath $script:Log -Level "INFO"
    $uninstallCommand = Get-Command "dotnet-core-uninstall" -ErrorAction SilentlyContinue
    if (-not $uninstallCommand) {   # dotnet-core-uninstallコマンドが見つからない場合
        Write-CommonLog -Message "dotnet-core-uninstall tool not found." -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("dotnet-core-uninstallツールが見つかりません。`r`n`r`n先にツールをインストールしてください。`r`n`r`nプログラムを終了します。", 0, "ツールエラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: dotnet-core-uninstall tool not found"
        Invoke-Item -Path $script:Log
        exit 1
    }
    Write-CommonLog -Message "dotnet-core-uninstall tool found: $($uninstallCommand.Source)" -LogPath $script:Log -Level "INFO"

    # .NET SDKがインストールされているか確認
    Write-CommonLog -Message "Checking installed .NET SDKs..." -LogPath $script:Log -Level "INFO"
    try {
        $installedSdks = & dotnet --list-sdks 2>&1
        if (-not $installedSdks -or $installedSdks.Count -eq 0) {  # インストールされている .NET SDKが見つからない場合
            Write-CommonLog -Message "No installed .NET SDKs found." -LogPath $script:Log -Level "WARN"
            $script:comObject.Popup("インストールされている .NET SDKが見つかりません。`r`n`r`nプログラムを終了します。", 0, ".NET SDK未検出", 0x30) | Out-Null
            Write-Error "Exit Code 1: No installed .NET SDKs found"
            Invoke-Item -Path $script:Log
            exit 1
        }
        
        Write-CommonLog -Message "Found $($installedSdks.Count) installed .NET SDK(s):" -LogPath $script:Log -Level "INFO"
        $installedSdks | ForEach-Object { Write-CommonLog -Message "  - $_" -LogPath $script:Log -Level "INFO" }
    } catch {
        Write-CommonLog -Message "Failed to list .NET SDKs: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup(".NET SDKの一覧取得に失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`nプログラムを終了します。", 0, "エラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: Failed to list .NET SDKs"
        Invoke-Item -Path $script:Log
        exit 1
    }

    # バージョン指定がない場合は入力を求める
    if (-not $SdkVersion) {
        $sdkList = $installedSdks -join "`r`n"
        
        # InputBoxを使用してバージョン入力（二重Popup削除）
        try {
            $SdkVersion = [Microsoft.VisualBasic.Interaction]::InputBox("削除したい .NET SDKのバージョンを入力してください`r`n`r`n例: 9.0.301 または 8.0.100`r`n複数の場合: 9.0.301,8.0.100`r`n`r`nインストール済み .NET SDK:`r`n$sdkList", "バージョン入力", "")
        } catch {
            # InputBoxが使えない場合は単純なプロンプトにフォールバック
            Write-CommonLog -Message "InputBox not available, using console input." -LogPath $script:Log -Level "WARN"
            Write-Host "`nインストールされている .NET SDKバージョン:"
            $installedSdks | ForEach-Object { Write-Host "  $_" }
            $SdkVersion = Read-Host "`n削除したい .NET SDKのバージョンを入力してください (例: 9.0.301 または 9.0.301,8.0.100)"
        }
        
        # キャンセルまたは空入力の処理
        if ([string]::IsNullOrWhiteSpace($SdkVersion)) {
            Write-CommonLog -Message "No version entered. User cancelled." -LogPath $script:Log -Level "INFO"
            $script:comObject.Popup("バージョンが入力されませんでした。`r`n`r`nプログラムを終了します。", 0, "入力キャンセル", 0x30) | Out-Null
            Write-Error "Exit Code 2: No version entered"
            Invoke-Item -Path $script:Log
            exit 2
        }
    }
    
    # カンマ区切りで複数バージョンに対応
    $versionsToRemove = $SdkVersion -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    Write-CommonLog -Message "Target .NET SDK version(s) for uninstallation: $($versionsToRemove -join ', ')" -LogPath $script:Log -Level "INFO"
    
    if ($WhatIf) {
        Write-CommonLog -Message "⚠️ WhatIf mode enabled - No actual changes will be made" -LogPath $script:Log -Level "WARN"
    }

    # 各バージョンの検証とマッチング
    $validVersions = @()
    $invalidVersions = @()
    $notInstalledVersions = @()
    
    # バージョンごとに検証
    foreach ($version in $versionsToRemove) {
        # バージョン形式の検証（x.y.z または x.y.z.w 形式をサポート）
        if ($version -notmatch '^\d+\.\d+\.\d+(\.\d+)?$') {
            Write-CommonLog -Message "Invalid version format: $version (Expected format: x.y.z or x.y.z.w)" -LogPath $script:Log -Level "ERROR"
            $invalidVersions += $version
            continue
        }
        
        # 指定バージョンがインストールされているか確認
        $matchingSdk = $installedSdks | Where-Object { $_ -like "*$version*" }
        if (-not $matchingSdk) {
            Write-CommonLog -Message "Specified .NET SDK version $version is not installed." -LogPath $script:Log -Level "WARN"
            $notInstalledVersions += $version
            continue
        }
        
        Write-CommonLog -Message "Verified: .NET SDK version $version is installed." -LogPath $script:Log -Level "INFO"
        Write-CommonLog -Message "Matching .NET SDK: $matchingSdk" -LogPath $script:Log -Level "INFO"
        $validVersions += $version
    }
    
    # エラーチェック
    if ($invalidVersions.Count -gt 0) {
        $errorMsg = "バージョン番号の形式が不正です。`r`n`r`n不正なバージョン:`r`n  - " + ($invalidVersions -join "`r`n  - ") + "`r`n`r`n期待形式: x.y.z または x.y.z.w (例: 9.0.301)"
        $script:comObject.Popup($errorMsg, 0, "形式エラー", 0x10) | Out-Null
        Write-Error "Exit Code 4: Invalid version format"
        Invoke-Item -Path $script:Log
        exit 4
    }
    
    # 指定されたバージョンがインストールされていない場合のエラー
    if ($validVersions.Count -eq 0) {
        $errorMsg = "指定された .NET SDKバージョンがインストールされていません。"
        if ($notInstalledVersions.Count -gt 0) {
            $errorMsg += "`r`n`r`n未インストール:`r`n  - " + ($notInstalledVersions -join "`r`n  - ")
        }
        $installedList = ($installedSdks | ForEach-Object { "  - $_" }) -join "`r`n"
        $errorMsg += "`r`n`r`nインストール済み .NET SDK:`r`n$installedList"
        $script:comObject.Popup($errorMsg, 0, "バージョン未検出", 0x30) | Out-Null
        Write-Error "Exit Code 4: No valid versions to uninstall"
        Invoke-Item -Path $script:Log
        exit 4
    }
    
    # インストールされていないバージョンの警告ログ
    if ($notInstalledVersions.Count -gt 0) {
        Write-CommonLog -Message "Warning: Some versions are not installed and will be skipped: $($notInstalledVersions -join ', ')" -LogPath $script:Log -Level "WARN"
    }
    
    Write-CommonLog -Message "Valid versions to process: $($validVersions -join ', ')" -LogPath $script:Log -Level "INFO"

    # グローバルツールの依存関係チェック
    Write-CommonLog -Message "Checking for installed global tools..." -LogPath $script:Log -Level "INFO"
    #   Verboseモードの通知
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        Write-Verbose "Checking for installed global tools..."
    }
    try {
        # グローバルツールの一覧取得
        $globalTools = & dotnet tool list --global 2>&1 | Select-Object -Skip 2
        if ($globalTools -and $globalTools.Count -gt 0) {
            Write-CommonLog -Message "Found $($globalTools.Count) global tool(s) installed:" -LogPath $script:Log -Level "INFO"
            $globalTools | ForEach-Object { Write-CommonLog -Message "  - $_" -LogPath $script:Log -Level "INFO" }
            $toolsList = ($globalTools | ForEach-Object { "  - $_" }) -join "`r`n"
            Write-CommonLog -Message "Warning: Removing .NET SDK may affect global tools" -LogPath $script:Log -Level "WARN"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {  # Verboseモードで詳細表示
                Write-Verbose "Found $($globalTools.Count) global tools:"
                $globalTools | ForEach-Object { Write-Verbose "  $_" }
            }
        } else {
            Write-CommonLog -Message "No global tools found." -LogPath $script:Log -Level "INFO"
            $toolsList = "  (なし)"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {  # Verboseモードで詳細表示
                Write-Verbose "No global tools installed"
            }
        }
    } catch {
        Write-CommonLog -Message "Failed to check global tools: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
        $toolsList = "  (確認できませんでした)"
    }
    
    # 削除前のバックアップ作成（JSON形式）
    if (-not $WhatIf) {
        try {
            $backupData = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                HostName = $script:HostName
                UserName = $script:User
                InstalledSDKs = $installedSdks
                GlobalTools = $globalTools
                TargetVersions = $validVersions
            }
            
            $backupFileName = "Backup_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json"
            $backupPath = Join-Path -Path $LogDir -ChildPath $backupFileName
            $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupPath -Encoding UTF8
            
            Write-CommonLog -Message "Backup created: $backupPath" -LogPath $script:Log -Level "INFO"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {  # Verboseモードで詳細表示
                Write-Verbose "Backup file created at: $backupPath"
                Write-Verbose "Backup contains: .NET SDK list, global tools, target versions"
            }
        } catch {
            Write-CommonLog -Message "Warning: Failed to create backup: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {  # Verboseモードで詳細表示#
                Write-Verbose "Backup creation failed: $($_.Exception.Message)"
            }
        }
    }
    
    # WhatIfモードの場合は削除をスキップ
    if ($WhatIf) {
        $whatIfMsg = "[WhatIf] 以下の.NET SDKバージョンが削除対象です:`r`n`r`n"
        $whatIfMsg += ($validVersions | ForEach-Object { "  - $_" }) -join "`r`n"
        $whatIfMsg += "`r`n`r`nインストール済みグローバルツール:`r`n$toolsList"
        $whatIfMsg += "`r`n`r`n実際には削除されません（-WhatIfモード）。"
        Write-CommonLog -Message "[WhatIf] Would remove versions: $($validVersions -join ', ')" -LogPath $script:Log -Level "INFO"
        $script:comObject.Popup($whatIfMsg, 0, "WhatIf: 削除対象確認", 0x40) | Out-Null
        Invoke-Item -Path $script:Log
        exit 0
    }
    
    # 削除確認
    $versionsList = ($validVersions | ForEach-Object { "  - $_" }) -join "`r`n"
    $confirmMsg = "以下の .NET SDKバージョンを削除します:`r`n`r`n$versionsList`r`n`r`nインストール済みグローバルツール:`r`n$toolsList`r`n`r`nよろしいですか？`r`n`r`n※この操作は取り消せません。"
    [int]$confirmation = $script:comObject.Popup($confirmMsg, 0, "削除確認", 52)
    if ($confirmation -eq 7) {  # No
        Write-CommonLog -Message "User cancelled the uninstallation." -LogPath $script:Log -Level "INFO"
        $script:comObject.Popup("削除をキャンセルしました。`r`n`r`nプログラムを終了します。", 0, "キャンセル", 0x40) | Out-Null
        Write-Error "Exit Code 2: User cancelled"
        Invoke-Item -Path $script:Log
        exit 2
    }

    # アンインストール実行（複数バージョン対応）
    $successVersions = @()
    $failedVersions = @()
    $timeoutSeconds = 300  # 5分タイムアウト
    
    # 各バージョンの削除ループ
    foreach ($version in $validVersions) {
        Write-CommonLog -Message "Starting uninstallation of .NET SDK $version..." -LogPath $script:Log -Level "INFO"
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {  # Verboseモードで詳細表示
            Write-Verbose "=== Starting uninstallation of .NET SDK $version ==="
            Write-Verbose "Timeout: $timeoutSeconds seconds"
        }
        
        try {
            # タイムアウト付きでプロセス実行
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "dotnet-core-uninstall"
            $processInfo.Arguments = "remove --sdk --version $version"
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            
            Write-CommonLog -Message "Executing: dotnet-core-uninstall remove --sdk --version $version (Timeout: ${timeoutSeconds}s)" -LogPath $script:Log -Level "INFO"
            $process.Start() | Out-Null
            
            $completed = $process.WaitForExit($timeoutSeconds * 1000)
            
            # タイムアウトチェック
            if (-not $completed) {
                # タイムアウト発生
                Write-CommonLog -Message "Uninstallation of $version timed out after $timeoutSeconds seconds." -LogPath $script:Log -Level "ERROR"
                try {
                    $process.Kill()
                    Write-CommonLog -Message "Process terminated due to timeout." -LogPath $script:Log -Level "WARN"
                } catch {
                    Write-CommonLog -Message "Failed to terminate process: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                }
                $failedVersions += $version
                continue
            }
            
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $exitCode = $process.ExitCode
            
            # 結果のログ出力
            if ($exitCode -ne 0) {
                Write-CommonLog -Message "Uninstall command exited with code $exitCode" -LogPath $script:Log -Level "ERROR"
                Write-CommonLog -Message "STDOUT: $stdout" -LogPath $script:Log -Level "ERROR"
                Write-CommonLog -Message "STDERR: $stderr" -LogPath $script:Log -Level "ERROR"
                $failedVersions += $version
                continue
            }
            
            # 成功時のログ出力
            Write-CommonLog -Message "Uninstall command executed successfully for $version" -LogPath $script:Log -Level "INFO"
            if (-not [string]::IsNullOrWhiteSpace($stdout)) {
                Write-CommonLog -Message "Command output: $stdout" -LogPath $script:Log -Level "INFO"
            }
            
            # 削除後の確認
            Start-Sleep -Seconds 2
            $postSdks = & dotnet --list-sdks 2>&1
            $stillExists = $postSdks | Where-Object { $_ -like "*$version*" }
            
            # 検証結果のログ出力
            if ($stillExists) {
                Write-CommonLog -Message "Warning: .NET SDK version $version still appears in the list after uninstallation." -LogPath $script:Log -Level "WARN"
                $failedVersions += $version
            } else {
                Write-CommonLog -Message "✅ Verified: .NET SDK version $version has been successfully removed." -LogPath $script:Log -Level "INFO"
                $successVersions += $version
            }
            
        } catch {
            $errorMsg = $_.Exception.Message
            Write-CommonLog -Message "❌ Uninstallation failed for ${version}: $errorMsg" -LogPath $script:Log -Level "ERROR"
            $failedVersions += $version
        }
    }
    
    # 結果サマリー
    Write-CommonLog -Message "Uninstallation completed. Success: $($successVersions.Count), Failed: $($failedVersions.Count)" -LogPath $script:Log -Level "INFO"
    
    # 環境変数PATH更新の提案
    if ($successVersions.Count -gt 0) {
        Write-CommonLog -Message "Suggesting environment variable PATH refresh..." -LogPath $script:Log -Level "INFO"
        $pathRefreshMsg = "SDKの削除が完了しました。`r`n`r`n削除済み:`r`n  - " + ($successVersions -join "`r`n  - ")
        # 失敗したバージョンがあれば追記
        if ($failedVersions.Count -gt 0) {
            $pathRefreshMsg += "`r`n`r`n削除失敗:`r`n  - " + ($failedVersions -join "`r`n  - ")
        }
        $pathRefreshMsg += "`r`n`r`n💡 重要: 環境変数の変更を反映するため、`r`n以下のいずれかを実行してください:`r`n`r`n1. PowerShellセッションを再起動する`r`n2. 以下のコマンドを実行:`r`n   `$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"
        
        $popupIcon = if ($failedVersions.Count -gt 0) { 0x30 } else { 0x40 }
        $script:comObject.Popup($pathRefreshMsg, 0, "削除完了", $popupIcon) | Out-Null
    } else {
        # すべての削除が失敗した場合のエラーメッセージ
        $errorMsg = "すべての.NET SDKの削除に失敗しました。`r`n`r`n失敗:`r`n  - " + ($failedVersions -join "`r`n  - ") + "`r`n`r`nログを確認してください。"
        $script:comObject.Popup($errorMsg, 0, "エラー", 0x10) | Out-Null
        Write-Error "Exit Code 5: All uninstallations failed"
        Invoke-Item -Path $script:Log
        exit 5
    }

    Write-CommonLog -Message "Script completed successfully." -LogPath $script:Log -Level "INFO"
    Invoke-Item -Path $script:Log
}

end {
    # COMオブジェクトのクリーンアップ
    if ($script:comObject) {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:comObject) | Out-Null
        $script:comObject = $null
    }
}