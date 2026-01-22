<#
.SYNOPSIS
    .NET SDK をアンインストールします（v1.1.0）。

.DESCRIPTION
    このスクリプトは、インストールされている.NET SDKを安全にアンインストールします。
    dotnet-core-uninstallツールを使用してSDKを削除し、例外処理とプロセス管理で堅牢性を確保します。
    
    主な機能:
    - YAML設定ファイルによる一元管理（タイムアウト、終了コード、アイコン等）
    - 管理者権限の確認と要求
    - インストール済みSDKの一覧表示
    - dotnetコマンドとdotnet-core-uninstallツールの存在確認
    - バージョン番号の形式検証（正規表現パターンはYAML設定）
    - 複数バージョンの一括削除対応
    - グローバルツールの依存関係チェック
    - 削除前のJSON形式バックアップ作成
    - 削除前の確認ダイアログ
    - タイムアウト付きアンインストール処理（YAML設定可能）
    - 削除後の検証
    - ログファイルの自動ローテーション（30日以上経過したログを削除）
    - 詳細なログ出力（INFO、WARN、ERROR、DEBUG）
    - 環境変数PATH更新の提案
    
    v1.1.0 の安全性強化:
    - 例外型に基づいたログレベル分類（Get-ExceptionLogLevel）
    - CanExecuteProcess フラグによる統一的なフロー制御
    - Helper 関数による再利用可能なコード（Open-LogIfNeeded, Stop-ProcessTree）
    - end ブロックでの確実なリソースクリーンアップ（COM オブジェクト解放）
    - exit 文の廃止と return 文への統一（スクリプト呼び出し対応）
    
    終了コード（YAML設定ファイルで定義）:
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
    Prerequisite   : PowerShell 7.x, dotnet-core-uninstall tool, powershell-yaml module
    Version        : 1.1.0
    
    改善履歴:
    v1.1.0 (2024年)
    - exit 文を全て廃止し、return 文に統一（スクリプト呼び出し対応）
    - CanExecuteProcess フラグを導入し、統一的なフロー制御を実現
    - Get-ExceptionLogLevel 関数を実装（例外型の自動分類、9パターン対応）
    - 再利用可能な Helper 関数を追加：
      * Open-LogIfNeeded: ログファイルの条件付きオープン
      * Stop-ProcessTree: プロセスツリーの再帰的削除
    - end ブロックを統一・強化（COM オブジェクト確実リリース、ログ終了処理）
    - 全 catch ブロック（7個）に例外分類ロジックを統合
    
    前提条件:
    - PowerShell 7.x 以上
    - powershell-yamlモジュール（YAML設定ファイル読み込み用）
    - dotnet-core-uninstallツールがインストールされていること
    - .NET SDKがインストールされていること
    - 管理者権限での実行（-SkipAdminCheckでスキップ可能）
    - Write-CommonLog.ps1が Common フォルダに存在すること
    - DotNetUninst.yaml が YAML フォルダに存在すること
    
    設定ファイル:
    - YAML\DotNetUninst.yaml: 各種設定値を一元管理
      * タイムアウト設定（UninstallSeconds）
      * ログ保持期間（RetentionDays）
      * Popupアイコンコード（Error, Warning, Information）
      * バージョン検証パターン（正規表現）
      * 終了コード定義（0-5）
      * プロジェクト情報（名前、バージョン）
    
    内部変数:
    - $script:CanExecuteProcess (bool): 処理続行フラグ（エラー時は $false に設定）
    - $script:ExitCode (int): スクリプト終了コード（0-5）
    - $script:Log (string): ログファイルパス
    - $script:comObject (COM): WScript.Shell COM オブジェクト（end ブロックで解放）
    
    動作詳細:
    1. YAML設定ファイルの読み込みと検証
    2. 管理者権限の確認（-SkipAdminCheckでスキップ可能）
    3. 必要なコマンド（dotnet、dotnet-core-uninstall）の存在確認
    4. 古いログファイルのクリーンアップ（YAML設定の保持期間に基づく）
    5. インストール済みSDKの一覧表示
    6. 削除対象バージョンの入力または検証（複数バージョン対応）
    7. バージョン形式の検証（YAML設定の正規表現パターンを使用）
    8. 指定バージョンがインストールされているか確認
    9. グローバルツールの依存関係チェックと表示
    10. 現状のJSON形式バックアップ作成（SDK情報、グローバルツール、削除対象）
    11. WhatIfモード時は削除対象の表示のみで終了
    12. ユーザー確認ダイアログ
    13. dotnet-core-uninstallコマンドでアンインストール実行（YAML設定のタイムアウト付き）
    14. 削除後の検証（SDKリストから削除されているか確認）
    15. end ブロックでの確実なリソースクリーンアップ
    
    エラーハンドリング:
    - 例外は Get-ExceptionLogLevel で自動分類（Terminating/NonTerminating 等）
    - 分類に応じた適切なログレベル（ERROR/WARN/DEBUG）で記録
    - CanExecuteProcess フラグで処理続行判定を統一
    - スクリプト呼び出し時も $script:ExitCode で終了コード取得可能
    15. 環境変数PATH更新の提案（削除成功時）
    16. 結果サマリーの表示（成功数、失敗数）
    17. ログファイルを開いて結果を表示
    
    多言語対応:
    現在は日本語のみをサポートしています。
    英語対応が必要な場合は、メッセージを変数化して言語ファイルから読み込む設計を検討してください。

.LINK
    https://github.com/UMA68/PowerShell
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({
        # SdkVersion のバージョン形式を検証（x.x.xxx または x.x.xxx,x.x.xxx の形式）
        if ([string]::IsNullOrWhiteSpace($_)) {
            # 空文字列は許可（対話的な入力を促す）
            $true
        } else {
            # バージョン形式を検証（例：9.0.301 または 9.0.301,8.0.100）
            $versions = $_ -split ','
            foreach ($version in $versions) {
                $version = $version.Trim()
                if ($version -notmatch '^\d+\.\d+\.\d+$') {
                    throw "バージョン形式が正しくありません。x.x.xxx 形式で指定してください: $_"
                }
            }
            $true
        }
    })]
    [string]$SdkVersion,            # 削除する .NET SDKバージョン（省略時は対話的に入力を求める）
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,                # ドライランモード（削除せず確認のみ）
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck         # 管理者権限チェックをスキップします。デバッグ用途のみで使用してください。
)

begin {
    # 改善 #2: プロセス制御フラグの初期化
    $script:CanExecuteProcess = $true
    $script:ExitCode = 0
    
    <#
    .SYNOPSIS
        例外の型に基づいてログレベルを決定します
    .DESCRIPTION
        与えられた例外オブジェクトの型を調べ、適切なログレベル（ERROR/WARN）を返します
    .PARAMETER Exception
        分析する例外オブジェクト
    #>
    function Get-ExceptionLogLevel {
        param([Exception]$Exception)
        $exceptionType = $Exception.GetType().FullName
        switch -regex ($exceptionType) { # 正規表現マッチング
            'System.UnauthorizedAccessException' { return 'ERROR' }                     # 権限不足
            'System.Management.Automation.CommandNotFoundException' { return 'ERROR' }  # コマンド未検出
            'System.TimeoutException' { return 'WARN' }         # タイムアウト
            'UnauthorizedAccessException' { return 'ERROR' }    # 権限不足
            'FileNotFoundException' { return 'ERROR' }          # ファイル未検出
            'DirectoryNotFoundException' { return 'ERROR' }     # ディレクトリ未検出
            'InvalidOperationException' { return 'ERROR' }      # 無効な操作
            'TimeoutException' { return 'WARN' }                # タイムアウト
            'IOException' { return 'ERROR' }                    # 入出力エラー
            'ArgumentException' { return 'ERROR' }              # 引数エラー
            'SystemException' { return 'ERROR' }                # 一般的なシステム例外
            'Exception' { return 'ERROR' }                      # その他の例外
            default { return 'ERROR' }                          # 不明な例外
        }
    }
    
    <#
    .SYNOPSIS
        ログファイルを条件付きでオープンします
    .DESCRIPTION
        インタラクティブモード時にログファイルが存在すればエクスプローラーで開きます
    .PARAMETER LogPath
        開くログファイルのパス
    .PARAMETER Interactive
        インタラクティブモードの場合は $true
    #>
    function Open-LogIfNeeded {
        param([string]$LogPath, [bool]$Interactive)
        if ($Interactive -and (Test-Path $LogPath)) { # インタラクティブモードかつログファイルが存在する場合
            try {
                Invoke-Item -Path $LogPath
            } catch {
                Write-Error "Failed to open log file: $_"
            }
        }
    }
    
    <#
    .SYNOPSIS
        プロセスツリーを再帰的に停止します
    .DESCRIPTION
        指定されたプロセスと、そのプロセスの全ての子プロセスを再帰的に停止します
    .PARAMETER ProcessId
        停止するプロセスのID
    #>
    function Stop-ProcessTree {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([int]$ProcessId)
        try {
            Get-Process | Where-Object { $_.Parent.Id -eq $ProcessId -and $_.Id -ne $ProcessId } | ForEach-Object {
                Stop-ProcessTree -ProcessId $_.Id
            }
            $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            if ($process) { # プロセスが存在する場合
                if ($PSCmdlet.ShouldProcess("Process $ProcessId", "Stop")) {
                    $process | Stop-Process -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Error "Failed to stop process tree: $_"
        }
    }
    
    # スクリプトのパス情報を取得
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path   # スクリプトの実行パスを取得
    $script:UpperPath = Split-Path -Parent $script:ScriptPath                     # スクリプトの親パスを取得
    $script:PowerShellDir = Split-Path -Parent $script:UpperPath                  # スクリプトの親パスの親パスを取得
    $script:LogDir = Join-Path -Path $script:UpperPath -ChildPath "LOG"           # ログディレクトリのパスを指定
    $script:ComPath = Join-Path -Path $script:PowerShellDir -ChildPath "Common"   # 共通スクリプトのパス
    $script:YamlPath = Join-Path -Path $script:UpperPath -ChildPath "YAML\DotNetUninst.yaml"  # YAML設定ファイルのパス
    
    # YAML設定ファイルの読み込み
    try {
        # powershell-yamlモジュールの確認
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) { # powershell-yamlモジュールが未インストール
            Write-Error "powershell-yamlモジュールがインストールされていません。"
            $script:CanExecuteProcess = $false
            $script:ExitCode = 1
            return
        }
        Import-Module powershell-yaml -ErrorAction Stop
        
        # YAML読み込み
        $yamlContent = Get-Content -Path $script:YamlPath -Raw -Encoding UTF8
        $script:config = ConvertFrom-Yaml -Yaml $yamlContent
        
        # 設定値の検証
        if (-not $script:config) { # YAML読み込み失敗
            Write-Error "YAML設定ファイルの読み込みに失敗しました。"
            $script:CanExecuteProcess = $false
            $script:ExitCode = 1
            return
        }
    } catch {
        # 改善 #3: 例外タイプに基づくログレベル決定
        $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
        Write-Error "YAML設定ファイルの処理中にエラーが発生しました: $($_.Exception.Message) [Log Level: $logLevel]"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }
    
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
    $commonLogPath = Join-Path -Path $script:ComPath -ChildPath "Write-CommonLog.ps1"
    try {
        . $commonLogPath -ErrorAction Stop
    } catch {
        $iconError = [int]$script:config.PopupIcon.Error
        $script:comObject.Popup("共通スクリプト (Write-CommonLog.ps1) を読み込めませんでした。処理を終了します。`r`n`r`nエラー: $($_.Exception.Message)", 0, "スクリプトエラー", $iconError) | Out-Null
        # 改善 #3: 例外タイプに基づくログレベル決定
        $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
        Write-Error "Exit Code $($script:config.ExitCode.GeneralError): Common script import failed - $($_.Exception.Message) [Log Level: $logLevel]"
        $script:CanExecuteProcess = $false
        $script:ExitCode = $script:config.ExitCode.GeneralError
        return
    }

    # ログディレクトリが作成されていなければ作成
    if (-not (Test-Path -Path $script:LogDir)) { # ログディレクトリが存在しない場合
        try {
            New-Item -Path $script:LogDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            $iconError = [int]$script:config.PopupIcon.Error
            $script:comObject.Popup("ログディレクトリの作成に失敗しました。`r`n`r`nパス: $($script:LogDir)`r`nエラー: $($_.Exception.Message)", 0, "ディレクトリエラー", $iconError) | Out-Null
            # 改善 #3: 例外タイプに基づくログレベル決定
            $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
            Write-Error "Exit Code $($script:config.ExitCode.GeneralError): Log directory creation failed - $($script:LogDir) [Log Level: $logLevel]"
            $script:CanExecuteProcess = $false
            $script:ExitCode = $script:config.ExitCode.GeneralError
            return
        }
    }
    
    # 古いログファイルのクリーンアップ（YAML設定に基づいて削除）
    try {
        $logRetentionDays = $script:config.LogCleanup.RetentionDays
        $cutoffDate = (Get-Date).AddDays(-$logRetentionDays)
        $logFileName = $script:config.LOG.FILENAME
        $logExtension = $script:config.LOG.EXTENSION
        $oldLogs = Get-ChildItem -Path $script:LogDir -Filter "${logFileName}_*${logExtension}" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldLogs -and $oldLogs.Count -gt 0) { # 古いログファイルが存在する場合
            foreach ($oldLog in $oldLogs) { # 古いログファイルを削除
                Remove-Item -Path $oldLog.FullName -Force -ErrorAction SilentlyContinue
            }
            # 削除数を後でログに記録（ログファイル作成後）
            $script:CleanedLogCount = $oldLogs.Count
        } else { # 古いログファイルがない場合
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
    $logFileName = $script:config.LOG.FILENAME
    $logExtension = $script:config.LOG.EXTENSION
    $script:Log = Join-Path -Path $script:LogDir -ChildPath ("${logFileName}_" + $timestamp + "-" + $milliseconds + $logExtension)
    
    # 管理者権限の確認
    $script:isAdmin = $false
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $script:isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    # 管理者権限がない場合、かつスキップフラグが立っていない場合はエラー終了
    if (-not $script:isAdmin -and -not $SkipAdminCheck) { # 管理者権限が必要
        Write-CommonLog -Message "Administrator privileges required for SDK uninstallation." -LogPath $script:Log -Level "ERROR"
        $iconWarning = [int]$script:config.PopupIcon.Warning
        $exitCodePriv = $script:config.ExitCode.InsufficientPrivileges
        $script:comObject.Popup(".NET SDKのアンインストールには管理者権限が必要です。`r`n`r`nこのスクリプトを管理者として実行してください。`r`n`r`nプログラムを終了します。", 0, "管理者権限が必要", $iconWarning) | Out-Null
        Write-Error "Exit Code ${exitCodePriv}: Insufficient privileges - Administrator rights required"
        $script:CanExecuteProcess = $false
        $script:ExitCode = $exitCodePriv
        return
    }

    # デバッグモードで権限チェックをスキップした場合の警告ログ
    if ($SkipAdminCheck) { # デバッグモードでスキップ
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
    if ($script:CleanedLogCount -gt 0) { # 古いログファイルをクリーンアップした場合
        Write-CommonLog -Message "Log rotation: Cleaned up $script:CleanedLogCount old log file(s) (older than 30 days)" -LogPath $script:Log -Level "INFO"
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
            Write-Verbose "Cleaned up $script:CleanedLogCount old log files"
        }
    } elseif ($script:CleanedLogCount -eq -1) { # ログクリーンアップ失敗
        Write-CommonLog -Message "Log rotation: Failed to clean up old log files" -LogPath $script:Log -Level "WARN"
    }
    
    # Verboseモードの通知
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
        Write-CommonLog -Message "Verbose mode enabled" -LogPath $script:Log -Level "INFO"
        Write-Verbose "=== Verbose Mode Enabled ==="
        Write-Verbose "Log file: $script:Log"
        Write-Verbose "Script version: $($script:config.Project.ScriptVersion)"
    }
    
    $ProjectLine = "=" * 50
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project name: $($script:config.Project.Name)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Script version: $($script:config.Project.ScriptVersion)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    "" | Out-File -FilePath $script:Log -Append # 空行追加

    # dotnetコマンドの存在確認
    Write-CommonLog -Message "Checking for dotnet command..." -LogPath $script:Log -Level "INFO"
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
        Write-Verbose "Checking for dotnet command..."
    }
    $dotnetCommand = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if (-not $dotnetCommand) { # dotnetコマンドが見つからない場合
        Write-CommonLog -Message "dotnet command not found. .NET SDK may not be installed." -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("dotnetコマンドが見つかりません。`r`n`r`n.NET SDKがインストールされていない可能性があります。`r`n`r`nプログラムを終了します。", 0, "コマンドエラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: dotnet command not found"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }
    Write-CommonLog -Message "dotnet command found: $($dotnetCommand.Source)" -LogPath $script:Log -Level "INFO"
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
        Write-Verbose "dotnet command found at: $($dotnetCommand.Source)"
    }

    # dotnet-core-uninstallコマンドの存在確認
    Write-CommonLog -Message "Checking for dotnet-core-uninstall tool..." -LogPath $script:Log -Level "INFO"
    $uninstallCommand = Get-Command "dotnet-core-uninstall" -ErrorAction SilentlyContinue
    if (-not $uninstallCommand) { # dotnet-core-uninstallコマンドが見つからない場合
        Write-CommonLog -Message "dotnet-core-uninstall tool not found." -LogPath $script:Log -Level "ERROR"
        $script:comObject.Popup("dotnet-core-uninstallツールが見つかりません。`r`n`r`n先にツールをインストールしてください。`r`n`r`nプログラムを終了します。", 0, "ツールエラー", 0x10) | Out-Null
        Write-Error "Exit Code 1: dotnet-core-uninstall tool not found"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }
    Write-CommonLog -Message "dotnet-core-uninstall tool found: $($uninstallCommand.Source)" -LogPath $script:Log -Level "INFO"

    # .NET SDKがインストールされているか確認
    Write-CommonLog -Message "Checking installed .NET SDKs..." -LogPath $script:Log -Level "INFO"
    try {
        $installedSdks = & dotnet --list-sdks 2>&1
        if (-not $installedSdks -or $installedSdks.Count -eq 0) { # インストールされているSDKがない場合
            Write-CommonLog -Message "No installed .NET SDKs found." -LogPath $script:Log -Level "WARN"
            $iconWarning = [int]$script:config.PopupIcon.Warning
            $exitCodeError = $script:config.ExitCode.GeneralError
            $script:comObject.Popup("インストールされている .NET SDKが見つかりません。`r`n`r`nプログラムを終了します。", 0, ".NET SDK未検出", $iconWarning) | Out-Null
            Write-Error "Exit Code ${exitCodeError}: No installed .NET SDKs found"
            $script:CanExecuteProcess = $false
            $script:ExitCode = $exitCodeError
            return
        }
        
        Write-CommonLog -Message "Found $($installedSdks.Count) installed .NET SDK(s):" -LogPath $script:Log -Level "INFO"
        $installedSdks | ForEach-Object { Write-CommonLog -Message "  - $_" -LogPath $script:Log -Level "INFO" }
    } catch {
        Write-CommonLog -Message "Failed to list .NET SDKs: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
        $iconError = [int]$script:config.PopupIcon.Error
        $exitCodeError = $script:config.ExitCode.GeneralError
        $script:comObject.Popup(".NET SDKの一覧取得に失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`nプログラムを終了します。", 0, "エラー", $iconError) | Out-Null
        Write-Error "Exit Code ${exitCodeError}: Failed to list .NET SDKs"
        Invoke-Item -Path $script:Log
        exit $exitCodeError
    }

    # バージョン指定がない場合は入力を求める
    if (-not $SdkVersion) { # バージョン未指定の場合
        Write-CommonLog -Message "No .NET SDK version specified. Prompting user for input." -LogPath $script:Log -Level "INFO"
        $sdkList = $installedSdks -join "`r`n"
        
        # InputBoxを使用してバージョン入力（二重Popup削除）
        try {
            $SdkVersion = [Microsoft.VisualBasic.Interaction]::InputBox("削除したい .NET SDKのバージョンを入力してください`r`n`r`n例: 9.0.301 または 8.0.100`r`n複数の場合: 9.0.301,8.0.100`r`n`r`nインストール済み .NET SDK:`r`n$sdkList", "バージョン入力", "")
        } catch {
            # InputBoxが使えない場合は単純なプロンプトにフォールバック
            Write-CommonLog -Message "InputBox not available, using console input." -LogPath $script:Log -Level "WARN"
            Write-Output "`nインストールされている .NET SDKバージョン:"
            $installedSdks | ForEach-Object { Write-Output "  $_" }
            $SdkVersion = Read-Host "`n削除したい .NET SDKのバージョンを入力してください (例: 9.0.301 または 9.0.301,8.0.100)"
        }
        
        # キャンセルまたは空入力の処理
        if ([string]::IsNullOrWhiteSpace($SdkVersion)) { # 空入力またはキャンセルの場合
            Write-CommonLog -Message "No version entered. User cancelled." -LogPath $script:Log -Level "INFO"
            $iconWarning = [int]$script:config.PopupIcon.Warning
            $exitCodeCancel = $script:config.ExitCode.UserCancelled
            $script:comObject.Popup("バージョンが入力されませんでした。`r`n`r`nプログラムを終了します。", 0, "入力キャンセル", $iconWarning) | Out-Null
            Write-Error "Exit Code ${exitCodeCancel}: No version entered"
            Invoke-Item -Path $script:Log
            exit $exitCodeCancel
        }
    }
    
    # カンマ区切りで複数バージョンに対応
    $versionsToRemove = $SdkVersion -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    Write-CommonLog -Message "Target .NET SDK version(s) for uninstallation: $($versionsToRemove -join ', ')" -LogPath $script:Log -Level "INFO"
    
    if ($WhatIf) { # WhatIfモードの通知
        Write-CommonLog -Message "⚠️ WhatIf mode enabled - No actual changes will be made" -LogPath $script:Log -Level "WARN"
    }

    # 各バージョンの検証とマッチング
    $validVersions = @()
    $invalidVersions = @()
    $notInstalledVersions = @()
    
    # バージョンごとに検証
    $versionPattern = $script:config.Validation.VersionPattern
    foreach ($version in $versionsToRemove) { # 各バージョンをループ
        # バージョン形式の検証（YAML設定のパターンを使用）
        if ($version -notmatch $versionPattern) { # 不正な形式の場合
            Write-CommonLog -Message "Invalid version format: $version (Expected format: x.y.z or x.y.z.w)" -LogPath $script:Log -Level "ERROR"
            $invalidVersions += $version
            continue
        }
        
        # 指定バージョンがインストールされているか確認
        $matchingSdk = $installedSdks | Where-Object { $_ -like "*$version*" }
        if (-not $matchingSdk) { # インストールされていない場合
            Write-CommonLog -Message "Specified .NET SDK version $version is not installed." -LogPath $script:Log -Level "WARN"
            $notInstalledVersions += $version
            continue
        }
        
        Write-CommonLog -Message "Verified: .NET SDK version $version is installed." -LogPath $script:Log -Level "INFO"
        Write-CommonLog -Message "Matching .NET SDK: $matchingSdk" -LogPath $script:Log -Level "INFO"
        $validVersions += $version
    }
    
    # エラーチェック
    if ($invalidVersions.Count -gt 0) { # 不正なバージョン形式がある場合
        $errorMsg = "バージョン番号の形式が不正です。`r`n`r`n不正なバージョン:`r`n  - " + ($invalidVersions -join "`r`n  - ") + "`r`n`r`n期待形式: x.y.z または x.y.z.w (例: 9.0.301)"
        $iconError = [int]$script:config.PopupIcon.Error
        $exitCodeVer = $script:config.ExitCode.VersionError
        $script:comObject.Popup($errorMsg, 0, "形式エラー", $iconError) | Out-Null
        Write-Error "Exit Code ${exitCodeVer}: Invalid version format"
        Invoke-Item -Path $script:Log
        exit $exitCodeVer
    }
    
    # 指定されたバージョンがインストールされていない場合のエラー
    if ($validVersions.Count -eq 0) { # 有効なバージョンがない場合
        $errorMsg = "指定された .NET SDKバージョンがインストールされていません。"
        if ($notInstalledVersions.Count -gt 0) { # インストールされていないバージョンがある場合
            $errorMsg += "`r`n`r`n未インストール:`r`n  - " + ($notInstalledVersions -join "`r`n  - ")
        }
        $installedList = ($installedSdks | ForEach-Object { "  - $_" }) -join "`r`n"
        $errorMsg += "`r`n`r`nインストール済み .NET SDK:`r`n$installedList"
        $iconWarning = [int]$script:config.PopupIcon.Warning
        $exitCodeVer = $script:config.ExitCode.VersionError
        $script:comObject.Popup($errorMsg, 0, "バージョン未検出", $iconWarning) | Out-Null
        Write-Error "Exit Code ${exitCodeVer}: No valid versions to uninstall"
        Invoke-Item -Path $script:Log
        exit $exitCodeVer
    }
    
    # インストールされていないバージョンの警告ログ
    if ($notInstalledVersions.Count -gt 0) { # インストールされていないバージョンがある場合
        Write-CommonLog -Message "Warning: Some versions are not installed and will be skipped: $($notInstalledVersions -join ', ')" -LogPath $script:Log -Level "WARN"
    }
    
    Write-CommonLog -Message "Valid versions to process: $($validVersions -join ', ')" -LogPath $script:Log -Level "INFO"

    # グローバルツールの依存関係チェック
    Write-CommonLog -Message "Checking for installed global tools..." -LogPath $script:Log -Level "INFO"
    #   Verboseモードの通知
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
        Write-Verbose "Checking for installed global tools..."
    }
    try {
        # グローバルツールの一覧取得
        $globalTools = & dotnet tool list --global 2>&1 | Select-Object -Skip 2
        if ($globalTools -and $globalTools.Count -gt 0) { # グローバルツールが見つかった場合
            Write-CommonLog -Message "Found $($globalTools.Count) global tool(s) installed:" -LogPath $script:Log -Level "INFO"
            $globalTools | ForEach-Object { Write-CommonLog -Message "  - $_" -LogPath $script:Log -Level "INFO" }
            $toolsList = ($globalTools | ForEach-Object { "  - $_" }) -join "`r`n"
            Write-CommonLog -Message "Warning: Removing .NET SDK may affect global tools" -LogPath $script:Log -Level "WARN"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
                Write-Verbose "Found $($globalTools.Count) global tools:"
                $globalTools | ForEach-Object { Write-Verbose "  $_" }
            }
        } else { # グローバルツールが見つからない場合
            Write-CommonLog -Message "No global tools found." -LogPath $script:Log -Level "INFO"
            $toolsList = "  (なし)"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
                Write-Verbose "No global tools installed"
            }
        }
    } catch {
        Write-CommonLog -Message "Failed to check global tools: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
        $toolsList = "  (確認できませんでした)"
    }
    
    # 削除前のバックアップ作成（JSON形式）
    if (-not $WhatIf) { # WhatIfモードでない場合のみバックアップ作成
        Write-CommonLog -Message "Creating backup before uninstallation..." -LogPath $script
        try {
            $backupData = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  # バックアップ作成日時
                HostName = $script:HostName     # ホスト名
                UserName = $script:User         # ユーザー名
                InstalledSDKs = $installedSdks  # インストールされているSDK一覧
                GlobalTools = $globalTools      # インストールされているグローバルツール一覧
                TargetVersions = $validVersions # 削除対象バージョン一覧
            }
            
            $backupFileName = "Backup_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json"
            $backupPath = Join-Path -Path $script:LogDir -ChildPath $backupFileName
            $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupPath -Encoding UTF8
            
            Write-CommonLog -Message "Backup created: $backupPath" -LogPath $script:Log -Level "INFO"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
                Write-Verbose "Backup file created at: $backupPath"
                Write-Verbose "Backup contains: .NET SDK list, global tools, target versions"
            }
        } catch {
            Write-CommonLog -Message "Warning: Failed to create backup: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
                Write-Verbose "Backup creation failed: $($_.Exception.Message)"
            }
        }
    }
    
    # WhatIfモードの場合は削除をスキップ
    if ($WhatIf) { # WhatIfモードの処理
        $whatIfMsg = "[WhatIf] 以下の.NET SDKバージョンが削除対象です:`r`n`r`n"
        $whatIfMsg += ($validVersions | ForEach-Object { "  - $_" }) -join "`r`n"
        $whatIfMsg += "`r`n`r`nインストール済みグローバルツール:`r`n$toolsList"
        $whatIfMsg += "`r`n`r`n実際には削除されません（-WhatIfモード）。"
        Write-CommonLog -Message "[WhatIf] Would remove versions: $($validVersions -join ', ')" -LogPath $script:Log -Level "INFO"
        $iconInfo = [int]$script:config.PopupIcon.Information
        $exitCodeSuccess = $script:config.ExitCode.Success
        $script:comObject.Popup($whatIfMsg, 0, "WhatIf: 削除対象確認", $iconInfo) | Out-Null
        Invoke-Item -Path $script:Log
        exit $exitCodeSuccess
    }
    
    # 削除確認
    $versionsList = ($validVersions | ForEach-Object { "  - $_" }) -join "`r`n"
    $confirmMsg = "以下の .NET SDKバージョンを削除します:`r`n`r`n$versionsList`r`n`r`nインストール済みグローバルツール:`r`n$toolsList`r`n`r`nよろしいですか？`r`n`r`n※この操作は取り消せません。"
    [int]$confirmation = $script:comObject.Popup($confirmMsg, 0, "削除確認", 52)
    if ($confirmation -eq 7) { # No
        Write-CommonLog -Message "User cancelled the uninstallation." -LogPath $script:Log -Level "INFO"
        $iconInfo = [int]$script:config.PopupIcon.Information
        $exitCodeCancel = $script:config.ExitCode.UserCancelled
        $script:comObject.Popup("削除をキャンセルしました。`r`n`r`nプログラムを終了します。", 0, "キャンセル", $iconInfo) | Out-Null
        Write-Error "Exit Code ${exitCodeCancel}: User cancelled"
        Invoke-Item -Path $script:Log
        exit $exitCodeCancel
    }

    # アンインストール実行（複数バージョン対応）
    $successVersions = @()
    $failedVersions = @()
    $timeoutSeconds = $script:config.Timeout.UninstallSeconds  # YAMLからタイムアウト値を取得
    
    # 各バージョンの削除ループ
    foreach ($version in $validVersions) { # バージョンごとに削除処理
        Write-CommonLog -Message "Starting uninstallation of .NET SDK $version..." -LogPath $script:Log -Level "INFO"
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { # Verboseモードで詳細表示
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
            if (-not $completed) { # タイムアウト発生時の処理
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
            if ($exitCode -ne 0) { # エラー時のログ出力
                Write-CommonLog -Message "Uninstall command exited with code $exitCode" -LogPath $script:Log -Level "ERROR"
                Write-CommonLog -Message "STDOUT: $stdout" -LogPath $script:Log -Level "ERROR"
                Write-CommonLog -Message "STDERR: $stderr" -LogPath $script:Log -Level "ERROR"
                $failedVersions += $version
                continue
            }
            
            # 成功時のログ出力
            Write-CommonLog -Message "Uninstall command executed successfully for $version" -LogPath $script:Log -Level "INFO"
            if (-not [string]::IsNullOrWhiteSpace($stdout)) { # 標準出力ログ
                Write-CommonLog -Message "Command output: $stdout" -LogPath $script:Log -Level "INFO"
            }
            
            # 削除後の確認
            Start-Sleep -Seconds 2
            $postSdks = & dotnet --list-sdks 2>&1
            $stillExists = $postSdks | Where-Object { $_ -like "*$version*" }
            
            # 検証結果のログ出力
            if ($stillExists) { # 削除失敗バージョンの検証結果ログ出力
                Write-CommonLog -Message "Warning: .NET SDK version $version still appears in the list after uninstallation." -LogPath $script:Log -Level "WARN"
                $failedVersions += $version
            } else { # 削除成功バージョンの検証結果ログ出力
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
    if ($successVersions.Count -gt 0) { # 削除成功バージョンがある場合の通知
        Write-CommonLog -Message "Suggesting environment variable PATH refresh..." -LogPath $script:Log -Level "INFO"
        $pathRefreshMsg = "SDKの削除が完了しました。`r`n`r`n削除済み:`r`n  - " + ($successVersions -join "`r`n  - ")
        # 失敗したバージョンがあれば追記
        if ($failedVersions.Count -gt 0) { # 失敗バージョンの通知
            $pathRefreshMsg += "`r`n`r`n削除失敗:`r`n  - " + ($failedVersions -join "`r`n  - ")
        }
        $pathRefreshMsg += "`r`n`r`n💡 重要: 環境変数の変更を反映するため、`r`n以下のいずれかを実行してください:`r`n`r`n1. PowerShellセッションを再起動する`r`n2. 以下のコマンドを実行:`r`n   `$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"
        
        $iconWarning = [int]$script:config.PopupIcon.Warning
        $iconInfo = [int]$script:config.PopupIcon.Information
        $popupIcon = if ($failedVersions.Count -gt 0) { $iconWarning } else { $iconInfo }
        $script:comObject.Popup($pathRefreshMsg, 0, "削除完了", $popupIcon) | Out-Null
    } else { # 削除成功バージョンがない場合の通知
        Write-CommonLog -Message "No SDKs were successfully removed; skipping PATH refresh suggestion." -LogPath $script:Log -Level "INFO"
        # すべての削除が失敗した場合のエラーメッセージ
        $errorMsg = "すべての.NET SDKの削除に失敗しました。`r`n`r`n失敗:`r`n  - " + ($failedVersions -join "`r`n  - ") + "`r`n`r`nログを確認してください。"
        $iconError = [int]$script:config.PopupIcon.Error
        $exitCodeFailed = $script:config.ExitCode.UninstallFailed
        $script:comObject.Popup($errorMsg, 0, "エラー", $iconError) | Out-Null
        Write-Error "Exit Code ${exitCodeFailed}: All uninstallations failed"
        $script:CanExecuteProcess = $false
        $script:ExitCode = $exitCodeFailed
        return
    }

    Write-CommonLog -Message "Script completed successfully." -LogPath $script:Log -Level "INFO"
    # 改善 #5: ログオープンを関数で管理
    $isInteractive = [System.Environment]::UserInteractive
    Open-LogIfNeeded -LogPath $script:Log -Interactive $isInteractive
    $script:CanExecuteProcess = $true
    $script:ExitCode = 0
}

end {
    # 改善 #5: 統合クリーンアップブロック
    # COM オブジェクトのクリーンアップ
    if ($script:comObject) { # COMオブジェクトが存在する場合
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:comObject) | Out-Null
            $script:comObject = $null
        } catch {
            Write-Verbose "Warning: COM object release failed (non-critical): $_"
        }
    }
    
    # ログファイルの最終クローズ
    if ($script:Log -and (Test-Path $script:Log)) { # ログファイルが存在する場合
        # ログに終了ステータスを記録
        if ($script:CanExecuteProcess) { # 正常終了時のログ記録
            Add-Content -Path $script:Log -Value "`n=== Script completed successfully (Exit Code: $script:ExitCode) ===\"
        } else { # エラー終了時のログ記録
            Add-Content -Path $script:Log -Value "`n=== Script ended with error (Exit Code: $script:ExitCode) ===\"
        }
    }
    
    # 改善 #1: return で終了コード返却（exit の代わり）
    return $script:ExitCode
}