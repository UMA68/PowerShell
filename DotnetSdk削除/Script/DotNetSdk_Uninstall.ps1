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
    省略した場合は、対話的に入力を求められます。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1
    
    対話的モード。インストール済みSDKの一覧を表示し、削除するバージョンの入力を求めます。

.EXAMPLE
    .\DotNetSdk_Uninstall.ps1 -SdkVersion "9.0.301"
    
    指定したバージョン9.0.301の.NET SDKを削除します。

.NOTES
    File Name      : DotNetSdk_Uninstall.ps1
    Author         : UMA
    Prerequisite   : PowerShell 7.x, dotnet-core-uninstall tool
    Version        : 1.0.0
    
    前提条件:
    - PowerShell 7.x 以上
    - dotnet-core-uninstallツールがインストールされていること
    - .NET SDKがインストールされていること
    - 管理者権限での実行
    - Write-CommonLog.ps1が Common フォルダに存在すること
    
    動作詳細:
    1. 管理者権限の確認
    2. 必要なコマンド（dotnet、dotnet-core-uninstall）の存在確認
    3. インストール済みSDKの一覧表示
    4. 削除対象バージョンの入力または検証
    5. バージョン形式の検証（x.y.z形式）
    6. 指定バージョンがインストールされているか確認
    7. ユーザー確認ダイアログ
    8. dotnet-core-uninstallコマンドでアンインストール実行
    9. 削除後の検証（SDKリストから削除されているか確認）
    10. ログファイルを開いて結果を表示

.LINK
    https://github.com/UMA68/PowerShell
#>
param (
    [Parameter(Mandatory=$false)]
    [string]$SdkVersion
)

begin {
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $UpperPath = Split-Path -Parent $scriptPath
    $PowerShellDir = Split-Path -Parent $UpperPath
    $LogDir = Join-Path -Path $UpperPath -ChildPath "LOG"
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
    
    if (-not $script:isAdmin) {
        Write-CommonLog -Message "Administrator privileges required for SDK uninstallation." -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup(".NET SDKのアンインストールには管理者権限が必要です。`r`n`r`nこのスクリプトを管理者として実行してください。`r`n`r`nプログラムを終了します。", 0, "管理者権限が必要", 0x30) | Out-Null
        Write-Error "Exit Code 3: Insufficient privileges - Administrator rights required"
        Invoke-Item -Path $script:Log
        exit 3
    }
}

process {
    # タイトル表示
    Write-CommonLog -Message "HOST: $script:HostName" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "USER: $script:User" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running as Administrator: $script:isAdmin" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running PowerShell Version: $($PSVersionTable.PSVersion)" -LogPath $script:Log -Level "INFO"
    
    $ProjectLine = "=" * 50
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project name: Uninstall .NET SDK" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Script version: 1.0.0" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    
    # 改行をログに出力
    "`r`n" | Tee-Object -FilePath $script:Log -Append | Out-Null

    # dotnetコマンドの存在確認
    Write-CommonLog -Message "Checking for dotnet command..." -LogPath $script:Log -Level "INFO"
    $dotnetCommand = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if (-not $dotnetCommand) {
        Write-CommonLog -Message "dotnet command not found. .NET SDK may not be installed." -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("dotnetコマンドが見つかりません。`r`n`r`n.NET SDKがインストールされていない可能性があります。`r`n`r`nプログラムを終了します。", 0, "コマンドエラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: dotnet command not found"
        Invoke-Item -Path $script:Log
        exit 1
    }
    Write-CommonLog -Message "dotnet command found: $($dotnetCommand.Source)" -LogPath $script:Log -Level "INFO"

    # dotnet-core-uninstallコマンドの存在確認
    Write-CommonLog -Message "Checking for dotnet-core-uninstall tool..." -LogPath $script:Log -Level "INFO"
    $uninstallCommand = Get-Command "dotnet-core-uninstall" -ErrorAction SilentlyContinue
    if (-not $uninstallCommand) {
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
        if (-not $installedSdks -or $installedSdks.Count -eq 0) {
            Write-CommonLog -Message "No installed SDKs found." -LogPath $script:Log -Level "WARN"
            $script:comObject.Popup("インストールされているSDKが見つかりません。`r`n`r`nプログラムを終了します。", 0, "SDK未検出", 0x30) | Out-Null
            Write-Error "Exit Code 1: No installed SDKs found"
            Invoke-Item -Path $script:Log
            exit 1
        }
        
        Write-CommonLog -Message "Found $($installedSdks.Count) installed SDK(s):" -LogPath $script:Log -Level "INFO"
        $installedSdks | ForEach-Object { Write-CommonLog -Message "  - $_" -LogPath $script:Log -Level "INFO" }
    } catch {
        Write-CommonLog -Message "Failed to list SDKs: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("SDKの一覧取得に失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`nプログラムを終了します。", 0, "エラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: Failed to list SDKs"
        Invoke-Item -Path $script:Log
        exit 1
    }

    # バージョン指定がない場合は入力を求める
    if (-not $SdkVersion) {
        $sdkList = $installedSdks -join "`r`n"
        $inputVersion = $script:comObject.Popup("インストールされているSDKバージョン:`r`n`r`n$sdkList`r`n`r`n削除したいバージョンをテキスト入力してください（例: 9.0.301）", 0, "バージョン選択", 0x20)
        
        # Popupの戻り値が2（キャンセル）の場合
        if ($inputVersion -eq 2) {
            Write-CommonLog -Message "User cancelled the operation." -LogPath $script:Log -Level "INFO"
            Write-Error "Exit Code 2: User cancelled"
            Invoke-Item -Path $script:Log
            exit 2
        }
        
        # InputBoxを使用してバージョン入力
        $SdkVersion = [Microsoft.VisualBasic.Interaction]::InputBox("削除したいSDKのバージョンを入力してください`r`n`r`n例: 9.0.301`r`n`r`nインストール済みSDK:`r`n$sdkList", "バージョン入力", "")
        
        if ([string]::IsNullOrWhiteSpace($SdkVersion)) {
            Write-CommonLog -Message "No version entered. User cancelled." -LogPath $script:Log -Level "INFO"
            $script:comObject.Popup("バージョンが入力されませんでした。`r`n`r`nプログラムを終了します。", 0, "入力キャンセル", 0x30) | Out-Null
            Write-Error "Exit Code 2: No version entered"
            Invoke-Item -Path $script:Log
            exit 2
        }
    }

    Write-CommonLog -Message "Target SDK version for uninstallation: $SdkVersion" -LogPath $script:Log -Level "INFO"

    # バージョン形式の検証（x.y.z形式）
    if ($SdkVersion -notmatch '^\d+\.\d+\.\d+$') {
        Write-CommonLog -Message "Invalid version format: $SdkVersion (Expected format: x.y.z)" -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("バージョン番号の形式が不正です。`r`n`r`n入力値: $SdkVersion`r`n期待形式: x.y.z (例: 9.0.301)`r`n`r`nプログラムを終了します。", 0, "形式エラー", 0x10) | Out-Null
        Write-Error "Exit Code 4: Invalid version format"
        Invoke-Item -Path $script:Log
        exit 4
    }

    # 指定バージョンがインストールされているか確認
    $matchingSdk = $installedSdks | Where-Object { $_ -like "*$SdkVersion*" }
    if (-not $matchingSdk) {
        Write-CommonLog -Message "Specified SDK version $SdkVersion is not installed." -LogPath $script:Log -Level "ERROR"
        $installedList = ($installedSdks | ForEach-Object { "  - $_" }) -join "`r`n"
        $script:comObject.Popup("指定されたSDKバージョン $SdkVersion はインストールされていません。`r`n`r`nインストール済みSDK:`r`n$installedList`r`n`r`nプログラムを終了します。", 0, "バージョン未検出", 0x30) | Out-Null
        Write-Error "Exit Code 4: Specified version not installed"
        Invoke-Item -Path $script:Log
        exit 4
    }
    
    Write-CommonLog -Message "Verified: SDK version $SdkVersion is installed." -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Matching SDK: $matchingSdk" -LogPath $script:Log -Level "INFO"

    # 削除確認
    [int]$confirmation = $script:comObject.Popup("指定バージョン $SdkVersion を削除します。`r`n`r`nよろしいですか？`r`n`r`n※この操作は取り消せません。", 0, "削除確認", 52)
    if ($confirmation -eq 7) {  # No
        Write-CommonLog -Message "User cancelled the uninstallation." -LogPath $script:Log -Level "INFO"
        $script:comObject.Popup("削除をキャンセルしました。`r`n`r`nプログラムを終了します。", 0, "キャンセル", 0x40) | Out-Null
        Write-Error "Exit Code 2: User cancelled"
        Invoke-Item -Path $script:Log
        exit 2
    }

    # アンインストール実行
    Write-CommonLog -Message "Starting uninstallation of .NET SDK $SdkVersion..." -LogPath $script:Log -Level "INFO"
    try {
        $uninstallResult = & dotnet-core-uninstall remove --sdk --version $SdkVersion 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Uninstall command exited with code $LASTEXITCODE. Output: $uninstallResult"
        }
        
        Write-CommonLog -Message "Uninstall command executed successfully." -LogPath $script:Log -Level "INFO"
        Write-CommonLog -Message "Command output: $uninstallResult" -LogPath $script:Log -Level "INFO"
        
        # 削除後の確認
        Start-Sleep -Seconds 2
        $postSdks = & dotnet --list-sdks 2>&1
        $stillExists = $postSdks | Where-Object { $_ -like "*$SdkVersion*" }
        
        if ($stillExists) {
            Write-CommonLog -Message "Warning: SDK version $SdkVersion still appears in the list after uninstallation." -LogPath $script:Log -Level "WARN"
            $script:comObject.Popup("警告: SDK $SdkVersion はアンインストール後もリストに残っています。`r`n`r`n手動で確認してください。", 0, "警告", 0x30) | Out-Null
        } else {
            Write-CommonLog -Message "✅ Verified: SDK version $SdkVersion has been successfully removed." -LogPath $script:Log -Level "INFO"
            $script:comObject.Popup("✅ Microsoft .NET SDK $SdkVersion のアンインストールが完了しました。`r`n`r`n削除が正常に確認されました。", 0, "完了", 0x40) | Out-Null
        }
        
    } catch {
        Write-CommonLog -Message "❌ Uninstallation failed: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("❌ アンインストールに失敗しました。`r`n`r`nエラーメッセージ: $($_.Exception.Message)`r`n`r`nログを確認してください。", 0, "エラー", 0x10) | Out-Null
        Write-Error "Exit Code 5: Uninstallation failed"
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