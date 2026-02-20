#Requires -Version 7.0
<#
.SYNOPSIS
    Pester5 テストを実行するためのバッチスクリプト
.DESCRIPTION
    Pester 5.6.1 をロードして、指定されたテストファイルまたはディレクトリを実行します。
.PARAMETER Path
    テストファイルまたはテストディレクトリのパス (必須)
.PARAMETER Verbose
    詳細出力を有効にします
.PARAMETER EnableExit
    終了コードを設定します（デフォルト: $false）
.EXAMPLE
    # 単一のテストファイルを実行
    .\Run-Pester5.ps1 -Path .\Tests\Common\Get-ScriptPaths.Tests.ps1 -Verbose

    # テストディレクトリ全体を実行
    .\Run-Pester5.ps1 -Path .\Tests\Pester5 -Verbose
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$EnableExit
)

# 既存の Pester モジュールをアンロード
Remove-Module Pester -ErrorAction SilentlyContinue

# Pester 5.6.1 をロード
try {
    Import-Module Pester -RequiredVersion 5.6.1 -Force
    Write-Host "✓ Pester 5.6.1 loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to import Pester 5.6.1: $_" -ForegroundColor Red
    exit 1
}

# テストパスが存在するか確認
if (-not (Test-Path $Path)) {
    Write-Host "✗ Test path not found: $Path" -ForegroundColor Red
    exit 1
}

Write-Host "Running Pester5 tests..." -ForegroundColor Cyan
Write-Host "Path: $Path" -ForegroundColor Gray

# テストを実行
$pesterParams = @{
    Path = $Path
}

# PowerShell の共通パラメータ -Verbose が使用された場合は渡す
if ($VerbosePreference -eq 'Continue') {
    $pesterParams['Verbose'] = $true
}

if ($EnableExit) {
    $pesterParams['EnableExit'] = $true
}

Invoke-Pester @pesterParams

$exitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 0 }
exit $exitCode
