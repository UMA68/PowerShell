# make_sandbox_folders.ps1
# DryRun (-WhatIf) 対応版
# SANDBOX 用の検証フォルダ構成を作成します

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$BasePath = 'C:\\SANDBOX\\TEST_FOLDER'
)

Write-Verbose "BasePath: $BasePath"

# 作成するフォルダ一覧
$Directories = @(
    "$BasePath\\リリース元\\LOG",
    "$BasePath\\リリース元\\TYPE_A",
    "$BasePath\\リリース元\\TYPE_B",
    "$BasePath\\リリース元\\TYPE_C",

    "$BasePath\\リリース先\\TYPE_A\\DEV",
    "$BasePath\\リリース先\\TYPE_A\\STG",
    "$BasePath\\リリース先\\TYPE_A\\PROD",

    "$BasePath\\リリース先\\TYPE_B\\DEV",
    "$BasePath\\リリース先\\TYPE_B\\STG",
    "$BasePath\\リリース先\\TYPE_B\\PROD",

    "$BasePath\\リリース先\\TYPE_C\\DEV",
    "$BasePath\\リリース先\\TYPE_C\\STG",
    "$BasePath\\リリース先\\TYPE_C\\PROD"
)

foreach ($dir in $Directories) {
    if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# TYPE_A テストファイル
$TestFiles = @(
    "$BasePath\\リリース元\\TYPE_A\\TEST_A_01.txt",
    "$BasePath\\リリース元\\TYPE_A\\TEST_A_02.txt",
    "$BasePath\\リリース元\\TYPE_A\\TEST_A_03.txt"
)

foreach ($file in $TestFiles) {
    if ($PSCmdlet.ShouldProcess($file, 'Create test file')) {
        if (-not (Test-Path $file)) {
            New-Item -ItemType File -Path $file | Out-Null
        }
    }
}

Write-Host "✅ SANDBOX フォルダ構成の作成処理が完了しました。" -ForegroundColor Green
