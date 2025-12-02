<#
.SYNOPSIS
        .NET Uninstall Tool のインストール/アンインストールを安全に管理します。

.DESCRIPTION
        .NET Uninstall Tool を対話式メニューでインストール/アンインストールします。
        設定は YAML で一元管理し、ログ出力・権限確認・二重起動防止・ドライラン（-WhatIf）に対応します。

        主な機能:
        - YAML 設定ファイルで全設定を管理（MSI、タイムアウト、ログ、終了コード 等）
        - 管理者権限チェック（-SkipAdminCheck でデバッグ時のみスキップ可能）
        - MSI の存在確認と Unblock（ブロック解除）
        - msiexec によるインストール/アンインストール（タイムアウト付き）
        - レジストリからの製品コード/インストール場所の自動検出
        - インストール/アンインストール後の検証
        - ログ生成と自動ローテーション、終了時のログ自動オープン
        - 二重起動防止（Mutex）
        - ドライラン（-WhatIf）対応：実行計画のみログに記録、変更は行いません

        -WhatIf の挙動（重要）:
        - ShouldProcess で保護された操作（Unblock-File / msiexec / フォルダ削除）は実行せず、
            「何を実行するか」を [WhatIf] でログ出力します。
        - ログ作成/追記とログファイルを開く処理は -WhatIf の影響を受けません（常に実行）。

.PARAMETER SkipAdminCheck
        管理者権限チェックをスキップします（デバッグ用途のみ）。
        本番運用では使用しないでください。

.EXAMPLE
        .\DotNetUninstallTool.ps1
        対話的メニューでインストール/アンインストールを選択します。

.EXAMPLE
        .\DotNetUninstallTool.ps1 -Verbose
        詳細モードで実行し、各ステップの詳細を表示します。

.EXAMPLE
        .\DotNetUninstallTool.ps1 -WhatIf
        ドライランモードで実行し、実際の変更は行わず計画のみをログに記録します。

.EXAMPLE
        .\DotNetUninstallTool.ps1 -WhatIf -Verbose
        ドライラン＋詳細モード。実行計画を詳細に確認できます。

.NOTES
        File Name   : DotNetUninstallTool.ps1
        Author      : UMA
        PowerShell  : 7.x 以上
        Modules     : powershell-yaml（YAML読み込み）
        Version     : YAML の Project.ScriptVersion を参照

        前提条件:
        - 管理者権限での実行（-SkipAdminCheck はデバッグ専用）
        - `Common\Write-CommonLog.ps1` が存在すること
        - `YAML\DotNetUninstallTool.yaml` が存在すること
        - `dotNetSdkUninstallTool\dotnet-core-uninstall.msi` が存在すること

        設定ファイル（YAML\DotNetUninstallTool.yaml）主要項目:
        - Project:
            * Name, ScriptVersion
        - MSI:
            * FileName: MSI ファイル名（例: dotnet-core-uninstall.msi）
            * ProductName: レジストリの DisplayName 検索パターン（例: *dotnet-core-uninstall*）
        - Installation:
            * DefaultPath: 既定インストールパス（例: C:\Program Files (x86)\dotnet-core-uninstall）
            * CommandName: コマンド名（例: dotnet-core-uninstall）
        - LOG:
            * FILENAME, EXTENSION（例: DotNetUninstallTool, .log）
        - LogCleanup:
            * RetentionDays: ログ保持日数（例: 30）
        - Timeout:
            * InstallSeconds, UninstallSeconds, SleepAfterOperation（秒）
        - PopupIcon:
            * Error/Warning/Information: WScript.Shell.Popup 用の数値（0x10/0x30/0x40 など）
        - ExitCode:
            * Success, GeneralError, UserCancelled, InsufficientPrivileges,
                FileNotFound, InstallFailed, UninstallFailed

        動作フロー（概要）:
        1. YAML 読み込み → ログ初期化 → 権限確認 → Mutex 取得 → ログローテーション
        2. メニュー表示 → ユーザー選択
        3. インストール: MSI 存在確認 → Unblock → msiexec /i → 検証
        4. アンインストール: レジストリ検索 → msiexec /x → 残存フォルダ削除 → 検証
        5. 終了時にログを自動オープン（常に実行）

        終了コード（YAMLの ExitCode に準拠）:
        - 0: Success（正常終了）
        - 1: GeneralError（一般エラー）
        - 2: UserCancelled（ユーザーキャンセル）
        - 3: InsufficientPrivileges（権限不足）
        - 4: FileNotFound（MSI 不在など）
        - 5: InstallFailed（インストール失敗/タイムアウト含む）
        - 6: UninstallFailed（アンインストール失敗/タイムアウト含む）

.LINK
        https://github.com/UMA68/PowerShell
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$false)]
    [switch]$SkipAdminCheck  # 管理者権限チェックをスキップ（デバッグ用）
)

begin {
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path   # スクリプトの実行パスを取得
    $UpperPath = Split-Path -Parent $scriptPath                     # スクリプトの親パスを取得   
    $PowerShellDir = Split-Path -Parent $UpperPath                  # スクリプトの親パスの親パスを取得
    $LogDir = Join-Path -Path $UpperPath -ChildPath "LOG"           # ログディレクトリのパスを指定
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"   # 共通スクリプトのパスを指定
    $yamlPath = Join-Path -Path $UpperPath -ChildPath "YAML\DotNetUninstallTool.yaml"               # YAML設定ファイルのパスを指定
    $dotNetSdkUninstallToolPath = Join-Path -Path $UpperPath -ChildPath "dotNetSdkUninstallTool"    # dotNetSdkUninstallToolフォルダのパスを指定
    
    # YAML設定ファイルの読み込み
    try {
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
            Write-Error "powershell-yamlモジュールがインストールされていません。"
            exit 1
        }
        Import-Module powershell-yaml -ErrorAction Stop
        
        $yamlContent = Get-Content -Path $yamlPath -Raw -Encoding UTF8
        $script:config = ConvertFrom-Yaml -Yaml $yamlContent
        
        if (-not $script:config) {
            Write-Error "YAML設定ファイルの読み込みに失敗しました。"
            exit 1
        }
    } catch {
        Write-Error "YAML設定ファイルの処理中にエラーが発生しました: $($_.Exception.Message)"
        exit 1
    }
    
    # COMオブジェクトの作成
    $script:comObject = $null
    try {
        $script:comObject = New-Object -ComObject WScript.Shell
    } catch {
        Write-Error "COMオブジェクトの作成に失敗しました: $_"
        exit 1
    }

    # 共通スクリプトのインポート
    $commonLogPath = Join-Path -Path $comPath -ChildPath "Write-CommonLog.ps1"
    try {
        . $commonLogPath -ErrorAction Stop
    } catch {
        $iconError = [int]$script:config.PopupIcon.Error
        $script:comObject.Popup("共通スクリプト (Write-CommonLog.ps1) を読み込めませんでした。処理を終了します。`r`n`r`nエラー: $($_.Exception.Message)", 0, "スクリプトエラー", $iconError) | Out-Null
        Write-Error "Exit Code $($script:config.ExitCode.GeneralError): Common script import failed"
        exit $script:config.ExitCode.GeneralError
    }

    # ログディレクトリの作成
    if (-not (Test-Path -Path $LogDir)) {
        try {
            New-Item -Path $LogDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            $iconError = [int]$script:config.PopupIcon.Error
            $script:comObject.Popup("ログディレクトリの作成に失敗しました。`r`n`r`nパス: $LogDir`r`nエラー: $($_.Exception.Message)", 0, "ディレクトリエラー", $iconError) | Out-Null
            Write-Error "Exit Code $($script:config.ExitCode.GeneralError): Log directory creation failed"
            exit $script:config.ExitCode.GeneralError
        }
    }
    
    # 古いログファイルのクリーンアップ
    try {
        $logRetentionDays = $script:config.LogCleanup.RetentionDays
        $cutoffDate = (Get-Date).AddDays(-$logRetentionDays)
        $logFileName = $script:config.LOG.FILENAME
        $logExtension = $script:config.LOG.EXTENSION
        $oldLogs = Get-ChildItem -Path $LogDir -Filter "${logFileName}_*${logExtension}" -ErrorAction SilentlyContinue | 
                   Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldLogs -and $oldLogs.Count -gt 0) {
            foreach ($oldLog in $oldLogs) {
                Remove-Item -Path $oldLog.FullName -Force -ErrorAction SilentlyContinue
            }
            $script:CleanedLogCount = $oldLogs.Count
        } else {
            $script:CleanedLogCount = 0
        }
    } catch {
        $script:CleanedLogCount = -1
    }
    
    # ログファイルパスの定義
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $milliseconds = (Get-Date).Millisecond.ToString("000")
    $logFileName = $script:config.LOG.FILENAME
    $logExtension = $script:config.LOG.EXTENSION
    $script:Log = Join-Path -Path $LogDir -ChildPath ("${logFileName}_" + $timestamp + "-" + $milliseconds + $logExtension)
    
    # ログファイルを初期化（-WhatIfモードでも必ず作成）
    try {
        "" | Out-File -FilePath $script:Log -Encoding UTF8 -Force -WhatIf:$false
    } catch {
        Write-Error "Failed to create log file: $($_.Exception.Message)"
    }
    
    # 管理者権限の確認
    $script:isAdmin = $false
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $script:isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $script:isAdmin -and -not $SkipAdminCheck) {
        Write-CommonLog -Message "Administrator privileges required." -LogPath $script:Log -Level "ERROR"
        $iconWarning = [int]$script:config.PopupIcon.Warning
        $exitCodePriv = $script:config.ExitCode.InsufficientPrivileges
        $script:comObject.Popup(".NET Uninstall Toolの管理には管理者権限が必要です。`r`n`r`nこのスクリプトを管理者として実行してください。`r`n`r`nプログラムを終了します。", 0, "管理者権限が必要", $iconWarning) | Out-Null
        Write-Error "Exit Code ${exitCodePriv}: Insufficient privileges"
        if (Test-Path -Path $script:Log) {
            Invoke-Item -Path $script:Log -WhatIf:$false
        }
        exit $exitCodePriv
    }

    if ($SkipAdminCheck) {
        Write-CommonLog -Message "⚠️ WARNING: Admin check skipped (Debug mode)" -LogPath $script:Log -Level "WARN"
    }
    
    # 二重起動防止（Mutex）
    $mutexName = "Global\DotNetUninstallToolScript"
    $script:mutex = New-Object System.Threading.Mutex($false, $mutexName)
    
    if (-not $script:mutex.WaitOne(0)) {
        Write-CommonLog -Message "Another instance is already running." -LogPath $script:Log -Level "ERROR"
        $iconWarning = [int]$script:config.PopupIcon.Warning
        $script:comObject.Popup("このスクリプトは既に実行中です。`r`n`r`n同時に複数実行することはできません。", 0, "二重起動エラー", $iconWarning) | Out-Null
        Write-Error "Exit Code $($script:config.ExitCode.GeneralError): Another instance is already running"
        exit $script:config.ExitCode.GeneralError
    }
    
    # PowerShell終了時にMutexを解放
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if ($script:mutex) {
            $script:mutex.ReleaseMutex()
            $script:mutex.Dispose()
        }
    }
}

process {
    # タイトル表示
    $script:User = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME
    
    Write-CommonLog -Message "HOST: $script:HostName" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "USER: $script:User" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running as Administrator: $script:isAdmin" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running PowerShell Version: $($PSVersionTable.PSVersion)" -LogPath $script:Log -Level "INFO"
    
    if ($script:CleanedLogCount -gt 0) {
        Write-CommonLog -Message "Log rotation: Cleaned up $script:CleanedLogCount old log file(s)" -LogPath $script:Log -Level "INFO"
    }
    
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        Write-CommonLog -Message "Verbose mode enabled" -LogPath $script:Log -Level "INFO"
        Write-Verbose "Log file: $script:Log"
        Write-Verbose "Script version: $($script:config.Project.ScriptVersion)"
    }
    
    if ($WhatIfPreference) {
        Write-CommonLog -Message "⚠️ WhatIf mode enabled - No actual changes will be made" -LogPath $script:Log -Level "INFO"
        Write-Host "`n⚠️ ドライランモード: 実際の処理は実行されません（ログのみ）" -ForegroundColor Yellow
    }
    
    $ProjectLine = "=" * 50
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project name: $($script:config.Project.Name)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Script version: $($script:config.Project.ScriptVersion)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    "" | Out-File -FilePath $script:Log -Append -WhatIf:$false

    # メニュー表示関数
    function Show-Menu {
        Write-Host ""
        Write-Host "=== .NET Uninstall Tool 管理メニュー ===" -ForegroundColor Cyan
        Write-Host "1. インストール" -ForegroundColor Green
        Write-Host "2. アンインストール" -ForegroundColor Yellow
        Write-Host "Q. 終了" -ForegroundColor Red
        Write-Host ""
    }

    # インストール関数
    function Install-UninstallTool {
        Write-CommonLog -Message "Starting installation process..." -LogPath $script:Log -Level "INFO"
        
        $msiFileName = $script:config.MSI.FileName
        $msiPath = Join-Path -Path $dotNetSdkUninstallToolPath -ChildPath $msiFileName
        
        # MSIファイルの存在確認
        if (-not (Test-Path $msiPath)) {
            Write-CommonLog -Message "MSI file not found: $msiPath" -LogPath $script:Log -Level "ERROR"
            $iconError = [int]$script:config.PopupIcon.Error
            $exitCodeFile = $script:config.ExitCode.FileNotFound
            Write-Host "❌ MSIファイルが見つかりません: $msiPath" -ForegroundColor Red
            $script:comObject.Popup("MSIファイルが見つかりません。`r`n`r`nパス: $msiPath`r`n`r`ndotNetSdkUninstallToolフォルダにMSIファイルを配置してください。", 0, "ファイル未検出", $iconError) | Out-Null
            return $exitCodeFile
        }
        
        Write-CommonLog -Message "MSI file found: $msiPath" -LogPath $script:Log -Level "INFO"
        
        # ファイルのブロック解除
        try {
            if ($PSCmdlet.ShouldProcess($msiPath, "Unblock file")) {
                Unblock-File -Path $msiPath -ErrorAction Stop
                Write-CommonLog -Message "File unblocked successfully" -LogPath $script:Log -Level "INFO"
            } else {
                Write-CommonLog -Message "[WhatIf] Would unblock file: $msiPath" -LogPath $script:Log -Level "INFO"
            }
        } catch {
            Write-CommonLog -Message "Failed to unblock file: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
        }
        
        # インストール実行
        Write-Host "🛠 インストールを開始します..." -ForegroundColor Yellow
        Write-CommonLog -Message "Executing MSI installation..." -LogPath $script:Log -Level "INFO"
        
        if (-not $PSCmdlet.ShouldProcess($msiPath, "Install MSI package")) {
            Write-CommonLog -Message "[WhatIf] Would execute: msiexec.exe /i `"$msiPath`" /passive /norestart" -LogPath $script:Log -Level "INFO"
            Write-Host "[WhatIf] インストール処理はスキップされました" -ForegroundColor Cyan
            return $script:config.ExitCode.Success
        }
        
        try {
            $timeoutSeconds = $script:config.Timeout.InstallSeconds
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "msiexec.exe"
            $processInfo.Arguments = "/i `"$msiPath`" /passive /norestart"
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            $processInfo.Verb = "RunAs"
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            
            Write-CommonLog -Message "Command: msiexec.exe /i `"$msiPath`" /passive /norestart (Timeout: ${timeoutSeconds}s)" -LogPath $script:Log -Level "INFO"
            $process.Start() | Out-Null
            
            $completed = $process.WaitForExit($timeoutSeconds * 1000)
            
            if (-not $completed) {
                Write-CommonLog -Message "Installation timed out after $timeoutSeconds seconds" -LogPath $script:Log -Level "ERROR"
                try {
                    $process.Kill()
                    Write-CommonLog -Message "Process terminated due to timeout" -LogPath $script:Log -Level "WARN"
                } catch {}
                Write-Host "⚠️ インストールがタイムアウトしました" -ForegroundColor Red
                return $script:config.ExitCode.InstallFailed
            }
            
            $exitCode = $process.ExitCode
            Write-CommonLog -Message "Installation process exited with code: $exitCode" -LogPath $script:Log -Level "INFO"
            
            if ($exitCode -ne 0) {
                Write-CommonLog -Message "Installation failed with exit code: $exitCode" -LogPath $script:Log -Level "ERROR"
                Write-Host "❌ インストールに失敗しました (Exit Code: $exitCode)" -ForegroundColor Red
                return $script:config.ExitCode.InstallFailed
            }
            
        } catch {
            Write-CommonLog -Message "Installation error: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
            Write-Host "❌ インストール中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
            return $script:config.ExitCode.InstallFailed
        }
        
        # インストール後の待機
        $sleepSeconds = $script:config.Timeout.SleepAfterOperation
        Write-CommonLog -Message "Waiting ${sleepSeconds} seconds for installation to complete..." -LogPath $script:Log -Level "INFO"
        Start-Sleep -Seconds $sleepSeconds
        
        # インストール検証
        $commandName = $script:config.Installation.CommandName
        if (Get-Command $commandName -ErrorAction SilentlyContinue) {
            Write-CommonLog -Message "✅ Installation completed successfully" -LogPath $script:Log -Level "INFO"
            Write-Host "✅ インストールが完了しました。" -ForegroundColor Green
            
            # バージョン情報を表示
            try {
                Write-Host "`nインストールされたツール情報:" -ForegroundColor Cyan
                & $commandName --help
                Write-CommonLog -Message "Tool help displayed successfully" -LogPath $script:Log -Level "INFO"
            } catch {
                Write-CommonLog -Message "Failed to display tool help: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
            }
            return $script:config.ExitCode.Success
        } else {
            Write-CommonLog -Message "⚠️ Command not recognized after installation" -LogPath $script:Log -Level "WARN"
            Write-Host "⚠️ インストール後にコマンドが認識されていません。PowerShellを再起動して確認してください。" -ForegroundColor Yellow
            return $script:config.ExitCode.Success
        }
    }

    # アンインストール関数
    function Uninstall-UninstallTool {
        Write-CommonLog -Message "Starting uninstallation process..." -LogPath $script:Log -Level "INFO"
        
        $uninstallKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        $uninstallKeyWow = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        $productPattern = $script:config.MSI.ProductName
        
        # レジストリからアンインストール情報を検索
        Write-CommonLog -Message "Searching registry for uninstall information..." -LogPath $script:Log -Level "INFO"
        $keys = Get-ChildItem $uninstallKey, $uninstallKeyWow -ErrorAction SilentlyContinue | Where-Object {
            (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName -like $productPattern
        }
        
        if (-not $keys) {
            Write-CommonLog -Message "Product not found in registry" -LogPath $script:Log -Level "INFO"
            Write-Host "✅ .NET Uninstall Tool はインストールされていません。" -ForegroundColor Green
            return $script:config.ExitCode.Success
        }
        
        # インストール情報の取得
        $productCode = $keys[0].PSChildName
        $installLocation = (Get-ItemProperty $keys[0].PSPath -ErrorAction SilentlyContinue).InstallLocation
        
        if (-not $installLocation) {
            $installLocation = $script:config.Installation.DefaultPath
        }
        
        Write-CommonLog -Message "Product code: $productCode" -LogPath $script:Log -Level "INFO"
        Write-CommonLog -Message "Install location: $installLocation" -LogPath $script:Log -Level "INFO"
        Write-Host "🧾 製品コード: $productCode" -ForegroundColor Cyan
        if ($installLocation) {
            Write-Host "📁 インストール場所: $installLocation" -ForegroundColor Cyan
        }
        
        # アンインストール実行
        Write-Host "🛠 アンインストールを開始します..." -ForegroundColor Yellow
        Write-CommonLog -Message "Executing MSI uninstallation..." -LogPath $script:Log -Level "INFO"
        
        if (-not $PSCmdlet.ShouldProcess($productCode, "Uninstall MSI package")) {
            Write-CommonLog -Message "[WhatIf] Would execute: msiexec.exe /x $productCode /passive /norestart" -LogPath $script:Log -Level "INFO"
            Write-Host "[WhatIf] アンインストール処理はスキップされました" -ForegroundColor Cyan
            if ($installLocation) {
                Write-CommonLog -Message "[WhatIf] Would remove folder: $installLocation" -LogPath $script:Log -Level "INFO"
            }
            return $script:config.ExitCode.Success
        }
        
        try {
            $timeoutSeconds = $script:config.Timeout.UninstallSeconds
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "msiexec.exe"
            $processInfo.Arguments = "/x $productCode /passive /norestart"
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            $processInfo.Verb = "RunAs"
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            
            Write-CommonLog -Message "Command: msiexec.exe /x $productCode /passive /norestart (Timeout: ${timeoutSeconds}s)" -LogPath $script:Log -Level "INFO"
            $process.Start() | Out-Null
            
            $completed = $process.WaitForExit($timeoutSeconds * 1000)
            
            if (-not $completed) {
                Write-CommonLog -Message "Uninstallation timed out after $timeoutSeconds seconds" -LogPath $script:Log -Level "ERROR"
                try {
                    $process.Kill()
                    Write-CommonLog -Message "Process terminated due to timeout" -LogPath $script:Log -Level "WARN"
                } catch {}
                Write-Host "⚠️ アンインストールがタイムアウトしました" -ForegroundColor Red
                return $script:config.ExitCode.UninstallFailed
            }
            
            $exitCode = $process.ExitCode
            Write-CommonLog -Message "Uninstallation process exited with code: $exitCode" -LogPath $script:Log -Level "INFO"
            
            if ($exitCode -ne 0) {
                Write-CommonLog -Message "Uninstallation failed with exit code: $exitCode" -LogPath $script:Log -Level "ERROR"
                Write-Host "❌ アンインストールに失敗しました (Exit Code: $exitCode)" -ForegroundColor Red
                return $script:config.ExitCode.UninstallFailed
            }
            
        } catch {
            Write-CommonLog -Message "Uninstallation error: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
            Write-Host "❌ アンインストール中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
            return $script:config.ExitCode.UninstallFailed
        }
        
        # アンインストール後の待機
        $sleepSeconds = $script:config.Timeout.SleepAfterOperation
        Write-CommonLog -Message "Waiting ${sleepSeconds} seconds for uninstallation to complete..." -LogPath $script:Log -Level "INFO"
        Start-Sleep -Seconds $sleepSeconds
        
        # 残存フォルダの削除
        if ($installLocation -and (Test-Path $installLocation)) {
            try {
                Remove-Item $installLocation -Recurse -Force -ErrorAction Stop
                Write-CommonLog -Message "Removed remaining folder: $installLocation" -LogPath $script:Log -Level "INFO"
                Write-Host "🧹 残存フォルダを削除しました: $installLocation" -ForegroundColor Green
            } catch {
                Write-CommonLog -Message "Failed to remove folder: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
                Write-Host "⚠️ 残存フォルダの削除に失敗しました: $installLocation" -ForegroundColor Yellow
            }
        }
        
        # アンインストール検証
        $commandName = $script:config.Installation.CommandName
        if (Get-Command $commandName -ErrorAction SilentlyContinue) {
            Write-CommonLog -Message "⚠️ Command still recognized after uninstallation" -LogPath $script:Log -Level "WARN"
            Write-Host "⚠️ アンインストール後もコマンドが残っています。PowerShellを再起動して確認してください。" -ForegroundColor Yellow
            return $script:config.ExitCode.Success
        } else {
            Write-CommonLog -Message "✅ Uninstallation completed successfully" -LogPath $script:Log -Level "INFO"
            Write-Host "✅ アンインストールが完了しました。" -ForegroundColor Green
            return $script:config.ExitCode.Success
        }
    }

    # メインループ
    $exitFlag = $false
    
    do {
        Show-Menu
        $choice = Read-Host "操作を選択してください (1/2/Q)"
        
        Write-CommonLog -Message "User selected: $choice" -LogPath $script:Log -Level "INFO"
        
        switch ($choice) {
            "1" { 
                $result = Install-UninstallTool
                if ($result -ne $script:config.ExitCode.Success) {
                    Write-CommonLog -Message "Installation operation failed with code: $result" -LogPath $script:Log -Level "ERROR"
                }
            }
            "2" { 
                $result = Uninstall-UninstallTool
                if ($result -ne $script:config.ExitCode.Success) {
                    Write-CommonLog -Message "Uninstallation operation failed with code: $result" -LogPath $script:Log -Level "ERROR"
                }
            }
            "Q" { 
                $exitFlag = $true
                Write-CommonLog -Message "User selected exit" -LogPath $script:Log -Level "INFO"
            }
            "q" { 
                $exitFlag = $true
                Write-CommonLog -Message "User selected exit" -LogPath $script:Log -Level "INFO"
            }
            default { 
                Write-Host "⚠️ 無効な選択です。もう一度入力してください。" -ForegroundColor Red
                Write-CommonLog -Message "Invalid selection: $choice" -LogPath $script:Log -Level "WARN"
            }
        }
    } while (-not $exitFlag)

    Write-Host "`n終了しました。" -ForegroundColor Cyan
    Write-CommonLog -Message "Script completed successfully" -LogPath $script:Log -Level "INFO"
    
    # ログファイルが存在する場合のみ開く（-WhatIfモードでも開く）
    if (Test-Path -Path $script:Log) {
        Invoke-Item -Path $script:Log -WhatIf:$false
    }
}

end {
    # Mutexの解放
    if ($script:mutex) {
        try {
            $script:mutex.ReleaseMutex()
            $script:mutex.Dispose()
        } catch {}
    }
    
    # COMオブジェクトのクリーンアップ
    if ($script:comObject) {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:comObject) | Out-Null
        $script:comObject = $null
    }
}
