<#
.SYNOPSIS
    ファイアウォールを一時解除してnpm install/update/ciを安全に実行します。

.DESCRIPTION
    Node.js送信通信ブロックルールを一時的に無効化し、npm {install|update|ci} を実行後、
    必ず再ブロックします。エラーハンドリング、管理者権限チェック、ログ記録、DryRunを実装。

.PARAMETER Command
    実行するnpmコマンド（install|update|ci）

.PARAMETER Packages
    対象パッケージ（install/updateで使用。ciは無視）

.PARAMETER Global
    グローバル操作（install/updateで使用。ciは無視）

.PARAMETER SaveDev
    開発依存としてインストール（installのみ）

.PARAMETER DryRun
    実際の変更を行わずに手順を表示（管理者不要）

.PARAMETER SkipAdminCheck
    管理者権限チェックをスキップ（DryRunとの併用時のみ有効。単独使用時はエラー終了）

.PARAMETER ExtraArgs
    追加のnpm引数（例: `--legacy-peer-deps`）。`ci`では無視されるかエラーになる可能性あり。

.PARAMETER RuleName
    使用するファイアウォールルール名（デフォルト: "Block Node.js Outbound"）

.PARAMETER LogPath
    ログファイルパス（デフォルト: Node.js通信ブロック対応\npm_safe.log）

.EXAMPLE
    .\npm_install_safe.ps1 -Command install -Packages "express"

.EXAMPLE
    .\npm_install_safe.ps1 -Command install -Packages @("jest","eslint") -SaveDev

.EXAMPLE
    .\npm_install_safe.ps1 -Command install -Packages "typescript" -Global

.EXAMPLE
    .\npm_install_safe.ps1 -Command update

.EXAMPLE
    .\npm_install_safe.ps1 -Command ci

.NOTES
    Version        : 2.0.0
    Author         : UMA
    Prerequisite   : PowerShell 5.1以降, 管理者権限, Node.js, ファイアウォールルール
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("install", "update", "ci")]
    [string]$Command = "install",
    
    [Parameter(Mandatory = $false)]
    [string[]]$Packages,
    
    [Parameter(Mandatory = $false)]
    [switch]$Global,
    
    [Parameter(Mandatory = $false)]
    [switch]$SaveDev,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [string[]]$ExtraArgs,
    
    [Parameter(Mandatory = $false)]
    [string]$RuleName = "Block Node.js Outbound",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = (Join-Path (Join-Path $PSScriptRoot "..\LOG") ("npm_safe_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date)))
)

# 定数定義
$script:EXIT_SUCCESS = 0
$script:EXIT_NO_ADMIN = 1
$script:EXIT_NO_RULE = 2
$script:EXIT_NPM_FAILED = 3
$script:EXIT_FIREWALL_ERROR = 4

# ログヘルパー関数
<#
.SYNOPSIS
    ログメッセージをファイルとコンソールに出力します。

.DESCRIPTION
    指定されたログレベルに応じて、メッセージをログファイルに記録し、
    コンソールに色付きで表示します。

.PARAMETER Message
    ログに記録するメッセージ

.PARAMETER Level
    ログレベル（INFO, SUCCESS, WARNING, ERROR）
#>
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]    # ログレベル
        [string]$Level = "INFO" # デフォルトはINFO
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss" # タイムスタンプ生成
    $logMessage = "[$timestamp] [$Level] $Message"      # ログメッセージ構築

    # ログディレクトリが無い場合は作成
    $logDir = Split-Path -Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Add-Content -Path $LogPath -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
    
    switch ($Level) { # コンソール出力
        "SUCCESS" { Write-Information $Message -InformationAction Continue ; Write-Host $Message -ForegroundColor Green }
        "WARNING" { Write-Warning $Message }
        "ERROR" { Write-Information $Message -InformationAction Continue ; Write-Host $Message -ForegroundColor Red }
        default { Write-Information $Message -InformationAction Continue ; Write-Host $Message -ForegroundColor Cyan }
    }
}

# 管理者権限チェック
<#
.SYNOPSIS
    現在のプロセスが管理者権限で実行されているか確認します。

.DESCRIPTION
    現在のWindowsプリンシパルを取得し、管理者ロールに属しているかを判定します。

.OUTPUTS
    Boolean - 管理者権限がある場合True、ない場合False
#>
function Test-AdminPrivilege {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ファイアウォールルール存在チェック
<#
.SYNOPSIS
    指定された表示名のファイアウォールルールが存在するか確認します。

.DESCRIPTION
    Get-NetFirewallRuleコマンドレットを使用して、指定された表示名の
    ファイアウォールルールが存在するかを判定します。

.PARAMETER DisplayName
    確認するファイアウォールルールの表示名

.OUTPUTS
    Boolean - ルールが存在する場合True、存在しない場合False
#>
function Test-FirewallRule {
    param([string]$DisplayName)
    
    try {
        $rule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
        return $null -ne $rule
    } catch {
        return $false
    }
}

# ファイアウォールルール状態取得
<#
.SYNOPSIS
    指定されたファイアウォールルールの有効/無効状態を取得します。

.DESCRIPTION
    Get-NetFirewallRuleコマンドレットを使用して、指定された表示名の
    ファイアウォールルールの有効状態（Enabled）を取得します。

.PARAMETER DisplayName
    状態を取得するファイアウォールルールの表示名

.OUTPUTS
    String - ルールの有効状態（'True'または'False'）、エラー時はnull
#>
function Get-FirewallRuleState {
    param([string]$DisplayName)
    
    try {
        $rule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction Stop
        return $rule.Enabled
    } catch {
        return $null
    }
}

# メイン処理開始
try {
    $isDryRun = $DryRun
    Write-Log "========================================" "INFO"
    Write-Log "npm $Command 安全実行スクリプト開始" "INFO"
    Write-Log "========================================" "INFO"
    
    # SkipAdminCheckの検証: DryRun以外での使用を禁止
    if ($SkipAdminCheck -and -not $DryRun) {
        Write-Log "エラー: -SkipAdminCheck は -DryRun との併用時のみ有効です。単独では使用できません。" "ERROR"
        Write-Log "検証目的の場合は -DryRun を追加してください。" "ERROR"
        exit $script:EXIT_NO_ADMIN
    }
    
    # 管理者権限チェック
    if (-not $DryRun -and -not $SkipAdminCheck -and -not (Test-AdminPrivilege)) { # 管理者権限が必要
        Write-Log "エラー: 管理者権限が必要です。PowerShellを管理者として実行してください。" "ERROR"
        exit $script:EXIT_NO_ADMIN
    }
    if ($DryRun) { # DryRunモードでは権限チェックをスキップ
        Write-Log "[DryRun] 管理者権限チェックをスキップ" "INFO"
    } elseif ($SkipAdminCheck) { # SkipAdminCheck指定時
        Write-Log "[警告] SkipAdminCheckにより管理者権限チェックをスキップします。権限不足で処理が失敗する可能性があります。" "WARNING"
    } else { # 正常に管理者権限あり
        Write-Log "✓ 管理者権限を確認しました" "SUCCESS"
    }
    
    # ファイアウォールルール存在チェック
    if (-not $DryRun -and -not (Test-FirewallRule -DisplayName $RuleName)) { # ルールが存在しない場合
        Write-Log "エラー: ファイアウォールルール '$RuleName' が見つかりません。" "ERROR"
        Write-Log "以下のコマンドでルールを作成してください:" "ERROR"
        Write-Log 'New-NetFirewallRule -DisplayName "Block Node.js Outbound" -Direction Outbound -Program "C:\Program Files\nodejs\node.exe" -Action Block -Enabled True' "ERROR"
        exit $script:EXIT_NO_RULE
    }
    if (-not $DryRun) { Write-Log "✓ ファイアウォールルールを確認しました" "SUCCESS" } else { Write-Log "[DryRun] ファイアウォールルール存在チェックをスキップ" "INFO" }
    
    # 初期状態を記録
    if (-not $DryRun) { # 初期状態を取得
        $initialRuleState = Get-FirewallRuleState -DisplayName $RuleName
        Write-Log "ファイアウォール初期状態: $(if ($initialRuleState -eq 'True') { 'ブロック有効' } else { '許可' })" "INFO"
    } else { # DryRunモードでは取得しない
        Write-Log "[DryRun] ファイアウォール初期状態の取得をスキップ" "INFO"
    }
    
    # npmコマンド構築
    $flags = @()    # フラグ配列初期化
    $packageList = if ($Packages) { $Packages -join " " } else { "" }   # パッケージリスト文字列化
    $extra = if ($ExtraArgs -and $ExtraArgs.Count -gt 0) { " " + ($ExtraArgs -join " ") } else { "" }   # 追加引数文字列化
    switch ($Command) { # npmコマンドごとの処理
        "install" { # install処理
            if ($Global) { $flags += "-g" } # グローバルフラグ
            if ($SaveDev) { $flags += "--save-dev" } # 開発依存フラグ
            $flagString = if ($flags.Count -gt 0) { " " + ($flags -join " ") } else { "" } # フラグ文字列化
            if (-not $Packages -or $Packages.Count -eq 0) { # パッケージ未指定時
                if ($Global -or $SaveDev) { Write-Log "[注意] パッケージ未指定のため -g/--save-dev は無視されます" "WARNING" }
                $npmCommand = "npm install$extra"  # package.jsonの依存関係をインストール
            } else { # パッケージ指定時
                $npmCommand = "npm install$flagString $packageList$extra"
            }
        }
        "update" { # update処理
            if ($Global) { $flags += "-g" } # グローバルフラグ
            if ($SaveDev) { Write-Log "[注意] updateでは --save-dev は無視されます" "WARNING" } # SaveDev無視
            $flagString = if ($flags.Count -gt 0) { " " + ($flags -join " ") } else { "" }  # フラグ文字列化
            $npmCommand = "npm update$flagString $packageList$extra"    # updateコマンド構築
        }
        "ci" { # ci処理
            if ($Global -or $SaveDev) { Write-Log "[注意] ciでは -g/--save-dev は無視されます" "WARNING" }  # 無視
            if ($Packages -and $Packages.Count -gt 0) { Write-Log "[注意] ciはパッケージ指定を無視します（package-lockに従います）" "WARNING" } # 無視
            if ($ExtraArgs -and $ExtraArgs.Count -gt 0) { Write-Log "[注意] ciでは ExtraArgs は無視されるかエラーになる可能性があります" "WARNING" }    # 注意  
            $npmCommand = "npm ci"   # ciコマンド構築
        }
    }
    Write-Log "実行コマンド: $npmCommand" "INFO"
    
    # ドライランモード: 実際の変更は行わず、予定操作を表示
    if ($DryRun) { # DryRunモード
        Write-Log "[DryRun] 次の操作をシミュレートします:" "INFO"
        Write-Log "[DryRun] ファイアウォール一時解除: Set-NetFirewallRule -DisplayName '$RuleName' -Enabled False" "INFO"
        Write-Log "[DryRun] 実行予定コマンド: $npmCommand" "INFO"
        Write-Log "[DryRun] ファイアウォール再ブロック: Set-NetFirewallRule -DisplayName '$RuleName' -Enabled True" "INFO"
        # WhatIfとして扱い、finallyでの再ブロックもスキップ
        $script:OriginalWhatIfPreference = $WhatIfPreference
        $WhatIfPreference = $true
        $exitCode = $script:EXIT_SUCCESS
    } elseif ($PSCmdlet.ShouldProcess($RuleName, "ファイアウォール一時解除とnpm $Command 実行")) {
    
    # 上の分岐でDryRunを処理済み。ここでは通常処理/WhatIf処理。
        
        # ファイアウォールルール無効化
        Write-Log "Node.js の送信通信を一時的に許可します..." "INFO"
        try {
            Set-NetFirewallRule -DisplayName $RuleName -Enabled False -ErrorAction Stop
            Write-Log "✓ ファイアウォールを一時解除しました" "SUCCESS"
        } catch {
            Write-Log "エラー: ファイアウォールルールの変更に失敗しました: $($_.Exception.Message)" "ERROR"
            exit $script:EXIT_FIREWALL_ERROR
        }
        
        # npm 実行
        Write-Log "npm $Command を実行中..." "INFO"
        try {
            $output = Invoke-Expression $npmCommand 2>&1    # npmコマンド実行、出力キャプチャ
            $exitCode = $LASTEXITCODE                       # npmの終了コード取得
            
            # 出力をログに記録
            $output | ForEach-Object { Write-Log $_.ToString() "INFO" }
            
            if ($exitCode -eq 0) { # 正常終了
                Write-Log "✓ npm $Command が正常に完了しました" "SUCCESS"
            } else { # 異常終了
                Write-Log "警告: npm $Command が終了コード $exitCode で終了しました" "WARNING"
            }
        } catch {
            Write-Log "エラー: npm $Command の実行に失敗しました: $($_.Exception.Message)" "ERROR"
            $exitCode = $script:EXIT_NPM_FAILED
        }
        
    } else {
        Write-Log "WhatIfモード: 実際の処理はスキップされました" "INFO"
        $exitCode = $script:EXIT_SUCCESS
    }
    
} catch {
    Write-Log "予期しないエラーが発生しました: $($_.Exception.Message)" "ERROR"
    Write-Log "スタックトレース: $($_.ScriptStackTrace)" "ERROR"
    $exitCode = $script:EXIT_FIREWALL_ERROR
    
} finally {
    # WhatIfPreferenceを元に戻す（セッション全体への影響を防ぐ）
    if ($null -ne $script:OriginalWhatIfPreference) {
        $WhatIfPreference = $script:OriginalWhatIfPreference
    }
    
    # DryRun/WhatIf時は再ブロックをスキップ
    if ($isDryRun) { # DryRunモード
        Write-Log "[DryRun] ファイアウォール再ブロックをスキップしました" "INFO"
    } elseif (-not $WhatIfPreference) { # 通常モード
        Write-Log "Node.js の送信通信を再度ブロックします..." "INFO"
        try {
            Set-NetFirewallRule -DisplayName $RuleName -Enabled True -ErrorAction Stop
            Write-Log "✓ ファイアウォールを再ブロックしました" "SUCCESS"
            
            # 最終状態を確認
            $finalRuleState = Get-FirewallRuleState -DisplayName $RuleName
            if ($finalRuleState -eq 'True') { # 再ブロック成功
                Write-Log "✓ ファイアウォール状態確認: ブロック有効" "SUCCESS"
            } else { # 再ブロック失敗
                Write-Log "警告: ファイアウォールが有効化されていない可能性があります" "WARNING"
            }
        } catch {
            Write-Log "エラー: ファイアウォールの再ブロックに失敗しました: $($_.Exception.Message)" "ERROR"
            Write-Log "手動で再ブロックしてください: Set-NetFirewallRule -DisplayName '$RuleName' -Enabled True" "ERROR"
        }
    } else { # WhatIfモード
        Write-Log "WhatIfモードのためファイアウォール再ブロックをスキップしました" "INFO"
    }
    
    Write-Log "========================================" "INFO"
    Write-Log "処理完了" "INFO"
    Write-Log "========================================" "INFO"
    
    # 終了コードを設定
    if ($null -eq $exitCode) {
        $exitCode = $script:EXIT_SUCCESS
    }
    
    exit $exitCode
}
