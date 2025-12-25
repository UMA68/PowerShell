<#
.SYNOPSIS
    ファイアウォールを一時解除してnpm uninstall/update/ciを安全に実行します。

.DESCRIPTION
    Node.js送信通信ブロックルールを一時的に無効化し、npm {uninstall|update|ci} を実行後、
    必ず再ブロックします。エラーハンドリング、管理者権限チェック、ログ記録、DryRunを実装。

.PARAMETER Command
    実行するnpmコマンド（uninstall|update|ci）

.PARAMETER Packages
    対象パッケージ（uninstallで必須、updateは省略可。ciは無視）

.PARAMETER Global
    グローバル操作（uninstall/updateで使用。ciは無視）

.PARAMETER DryRun
    実際の変更を行わずに手順を表示（管理者不要）

.PARAMETER RuleName
    使用するファイアウォールルール名（デフォルト: "Block Node.js Outbound"）

.PARAMETER LogPath
    ログファイルパス（デフォルト: Node.js通信ブロック対応\npm_safe.log）

.PARAMETER ExtraArgs
    追加のnpm引数（例: `--legacy-peer-deps`）。`ci`では無視されるかエラーになる可能性あり。

.EXAMPLE
    .\npm_uninstall_safe.ps1 -Command uninstall -Packages "express"

.EXAMPLE
    .\npm_uninstall_safe.ps1 -Command uninstall -Packages "typescript" -Global

.EXAMPLE
    .\npm_uninstall_safe.ps1 -Command update

.EXAMPLE
    .\npm_uninstall_safe.ps1 -Command ci  # ciはインストール側の使用推奨

.NOTES
    Version        : 2.0.0
    Author         : UMA
    Prerequisite   : PowerShell 5.1以降, 管理者権限, Node.js, ファイアウォールルール
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("uninstall","update","ci")]
    [string]$Command = "uninstall",
    
    [Parameter(Mandatory=$false)]
    [string[]]$Packages,
    
    [Parameter(Mandatory=$false)]
    [switch]$Global,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [string[]]$ExtraArgs,
    
    [Parameter(Mandatory=$false)]
    [string]$RuleName = "Block Node.js Outbound",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = (Join-Path $PSScriptRoot "..\npm_safe.log")
)

# 定数定義
$script:EXIT_SUCCESS = 0
$script:EXIT_NO_ADMIN = 1
$script:EXIT_NO_RULE = 2
$script:EXIT_NPM_FAILED = 3
$script:EXIT_FIREWALL_ERROR = 4
$script:EXIT_INVALID_ARGS = 5

# ログヘルパー関数
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
    
    switch ($Level) {
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "WARNING" { Write-Warning $Message }
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        default   { Write-Host $Message -ForegroundColor Cyan }
    }
}

# 管理者権限チェック
function Test-AdminPrivilege {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ファイアウォールルール存在チェック
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
    Write-Log "========================================" "INFO"
    Write-Log "npm $Command 安全実行スクリプト開始" "INFO"
    Write-Log "========================================" "INFO"
    
    # 管理者権限チェック
    if (-not $DryRun -and -not (Test-AdminPrivilege)) {
        Write-Log "エラー: 管理者権限が必要です。PowerShellを管理者として実行してください。" "ERROR"
        exit $script:EXIT_NO_ADMIN
    }
    if (-not $DryRun) { Write-Log "✓ 管理者権限を確認しました" "SUCCESS" } else { Write-Log "[DryRun] 管理者権限チェックをスキップ" "INFO" }
    
    # ファイアウォールルール存在チェック
    if (-not $DryRun -and -not (Test-FirewallRule -DisplayName $RuleName)) {
        Write-Log "エラー: ファイアウォールルール '$RuleName' が見つかりません。" "ERROR"
        Write-Log "以下のコマンドでルールを作成してください:" "ERROR"
        Write-Log 'New-NetFirewallRule -DisplayName "Block Node.js Outbound" -Direction Outbound -Program "C:\\Program Files\\nodejs\\node.exe" -Action Block -Enabled True' "ERROR"
        exit $script:EXIT_NO_RULE
    }
    if (-not $DryRun) { Write-Log "✓ ファイアウォールルールを確認しました" "SUCCESS" } else { Write-Log "[DryRun] ファイアウォールルール存在チェックをスキップ" "INFO" }
    
    # 引数検証
    if ($Command -eq 'uninstall' -and (-not $Packages -or $Packages.Count -eq 0)) {
        Write-Log "エラー: uninstallでは -Packages の指定が必須です。" "ERROR"
        if ($DryRun) { $WhatIfPreference = $true }
        exit $script:EXIT_INVALID_ARGS
    }

    # 初期状態を記録
    if (-not $DryRun) {
        $initialRuleState = Get-FirewallRuleState -DisplayName $RuleName
        Write-Log "ファイアウォール初期状態: $(if ($initialRuleState -eq 'True') { 'ブロック有効' } else { '許可' })" "INFO"
    } else {
        Write-Log "[DryRun] ファイアウォール初期状態の取得をスキップ" "INFO"
    }
    
    # npmコマンド構築
    $flags = @()
    $packageList = if ($Packages) { $Packages -join " " } else { "" }
    $extra = if ($ExtraArgs -and $ExtraArgs.Count -gt 0) { " " + ($ExtraArgs -join " ") } else { "" }
    switch ($Command) {
        "uninstall" {
            if ($Global) { $flags += "-g" }
            $flagString = if ($flags.Count -gt 0) { " " + ($flags -join " ") } else { "" }
            if (-not $Packages -or $Packages.Count -eq 0) {
                Write-Log "警告: パッケージが指定されていません。'npm -v'でテストします。" "WARNING"
                $npmCommand = "npm -v"
            } else {
                $npmCommand = "npm uninstall$flagString $packageList$extra"
            }
        }
        "update" {
            if ($Global) { $flags += "-g" }
            $flagString = if ($flags.Count -gt 0) { " " + ($flags -join " ") } else { "" }
            $npmCommand = "npm update$flagString $packageList$extra"
        }
        "ci" {
            if ($Global) { Write-Log "[注意] ciでは -g は無視されます" "WARNING" }
            if ($Packages -and $Packages.Count -gt 0) { Write-Log "[注意] ciはパッケージ指定を無視します（package-lockに従います）" "WARNING" }
            if ($ExtraArgs -and $ExtraArgs.Count -gt 0) { Write-Log "[注意] ciでは ExtraArgs は無視されるかエラーになる可能性があります" "WARNING" }
            $npmCommand = "npm ci"
        }
    }
    Write-Log "実行コマンド: $npmCommand" "INFO"
    
    # ドライランモード: 実際の変更は行わず、予定操作を表示
    if ($DryRun) {
        Write-Log "[DryRun] 次の操作をシミュレートします:" "INFO"
        Write-Log "[DryRun] ファイアウォール一時解除: Set-NetFirewallRule -DisplayName '$RuleName' -Enabled False" "INFO"
        Write-Log "[DryRun] 実行予定コマンド: $npmCommand" "INFO"
        Write-Log "[DryRun] ファイアウォール再ブロック: Set-NetFirewallRule -DisplayName '$RuleName' -Enabled True" "INFO"
        # WhatIfとして扱い、finallyでの再ブロックもスキップ
        $WhatIfPreference = $true
        $exitCode = $script:EXIT_SUCCESS
    } elseif ($PSCmdlet.ShouldProcess($RuleName, "ファイアウォール一時解除とnpm $Command 実行")) {
        
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
            $output = Invoke-Expression $npmCommand 2>&1
            $exitCode = $LASTEXITCODE
            
            # 出力をログに記録
            $output | ForEach-Object { Write-Log $_.ToString() "INFO" }
            
            if ($exitCode -eq 0) {
                Write-Log "✓ npm $Command が正常に完了しました" "SUCCESS"
            } else {
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
    # 必ずファイアウォールを再ブロック
    if (-not $WhatIfPreference) {
        Write-Log "Node.js の送信通信を再度ブロックします..." "INFO"
        try {
            Set-NetFirewallRule -DisplayName $RuleName -Enabled True -ErrorAction Stop
            Write-Log "✓ ファイアウォールを再ブロックしました" "SUCCESS"
            
            # 最終状態を確認
            $finalRuleState = Get-FirewallRuleState -DisplayName $RuleName
            if ($finalRuleState -eq 'True') {
                Write-Log "✓ ファイアウォール状態確認: ブロック有効" "SUCCESS"
            } else {
                Write-Log "警告: ファイアウォールが有効化されていない可能性があります" "WARNING"
            }
        } catch {
            Write-Log "エラー: ファイアウォールの再ブロックに失敗しました: $($_.Exception.Message)" "ERROR"
            Write-Log "手動で再ブロックしてください: Set-NetFirewallRule -DisplayName '$RuleName' -Enabled True" "ERROR"
        }
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
