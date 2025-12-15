#!/usr/bin/env pwsh
<#
.SYNOPSIS
    getILSpyCmd.ps1 v1.3.0 改善内容検証スクリプト

.DESCRIPTION
    - Exit 文が完全に削除されたか
    - -NoKeyWait パラメータが正しく実装されたか
    - CanExecuteProcess フラグが正しく使用されているか
    - End ブロックが改善されているか
#>

param(
    [string]$ScriptPath = "c:\Users\徳永光浩\GitHub\PowerShell\ILSpyCmdの入手\Script\getILSpyCmd.ps1"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "getILSpyCmd.ps1 v1.3.0 検証スクリプト" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ファイルが存在するか確認
if (-not (Test-Path $ScriptPath)) {
    Write-Host "エラー: スクリプトが見つかりません: $ScriptPath" -ForegroundColor Red
    exit 1
}

$scriptContent = Get-Content $ScriptPath -Raw

# 検証項目
$checks = @{
    "Exit 文が削除されている" = {
        $matches = [regex]::Matches($scriptContent, '\bexit\s+\d+\b')
        if ($matches.Count -eq 0) {
            Write-Host "✅ 合格: Exit 文が0個（完全に削除）" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: Exit 文が $($matches.Count) 個見つかった" -ForegroundColor Red
            $matches | ForEach-Object { Write-Host "  → $_" }
            return $false
        }
    }
    
    "-NoKeyWait パラメータが存在" = {
        if ($scriptContent -match '\[switch\]\$NoKeyWait') {
            Write-Host "✅ 合格: -NoKeyWait パラメータが定義されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: -NoKeyWait パラメータが見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "CanExecuteProcess フラグが初期化されている" = {
        if ($scriptContent -match '\$script:CanExecuteProcess\s*=\s*\$true') {
            Write-Host "✅ 合格: CanExecuteProcess フラグが初期化されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: CanExecuteProcess 初期化が見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "ExitCode フラグが初期化されている" = {
        if ($scriptContent -match '\$script:ExitCode\s*=\s*0') {
            Write-Host "✅ 合格: ExitCode フラグが初期化されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: ExitCode 初期化が見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "if (-not $NoKeyWait) で条件付けされているPopup" = {
        $popupMatches = [regex]::Matches($scriptContent, 'if\s+\(\s*-not\s+\$NoKeyWait\s*\).*?\.Popup', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($popupMatches.Count -gt 5) {
            Write-Host "✅ 合格: $($popupMatches.Count) 個のポップアップが条件付けされている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: ポップアップの条件付けが少ない（$($popupMatches.Count) 個）" -ForegroundColor Yellow
            return $false
        }
    }
    
    "End ブロックで $script:CanExecuteProcess を確認" = {
        $endMatch = [regex]::Match($scriptContent, 'end\s*\{(.*?)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($endMatch.Success -and $endMatch.Groups[1].Value -match '\$script:CanExecuteProcess') {
            Write-Host "✅ 合格: End ブロックで CanExecuteProcess を確認している" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: End ブロックで CanExecuteProcess を確認していない" -ForegroundColor Red
            return $false
        }
    }
    
    "End ブロックで exit を使用している" = {
        $endMatch = [regex]::Match($scriptContent, 'end\s*\{(.*?)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if ($endMatch.Success -and $endMatch.Groups[1].Value -match 'exit\s+\$script:ExitCode') {
            Write-Host "✅ 合格: End ブロックで 'exit `$script:ExitCode' を使用している" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: End ブロックの終了コード設定パターンを確認してください" -ForegroundColor Yellow
            return $false
        }
    }
    
    "Exception Type ログが追加されている" = {
        $matches = [regex]::Matches($scriptContent, 'Exception Type:.*?GetType\(\)\.FullName')
        if ($matches.Count -gt 3) {
            Write-Host "✅ 合格: $($matches.Count) 個の例外タイプログが追加されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: 例外タイプログが少ない（$($matches.Count) 個）" -ForegroundColor Yellow
            return $false
        }
    }
    
    "Return 文でスクリプトから抜ける" = {
        $returnCount = [regex]::Matches($scriptContent, '^\s*return\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline).Count
        if ($returnCount -gt 5) {
            Write-Host "✅ 合格: $($returnCount) 個の return ステートメントが使用されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: Return が少ない（$($returnCount) 個）" -ForegroundColor Red
            return $false
        }
    }
}

# 検証実行
$results = @()
$checks.GetEnumerator() | ForEach-Object {
    Write-Host ""
    Write-Host "【検証】$($_.Name)" -ForegroundColor Yellow
    $result = & $_.Value
    $results += @{ Name = $_.Name; Result = $result }
}

# 結果まとめ
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "検証結果" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passCount = ($results | Where-Object { $_.Result -eq $true }).Count
$totalCount = $results.Count

Write-Host "合格: $passCount / $totalCount" -ForegroundColor Green
Write-Host ""

if ($passCount -eq $totalCount) {
    Write-Host "✅ すべての検証に合格しました！" -ForegroundColor Green
    Write-Host "v1.3.0 の改善が正常に実装されています。" -ForegroundColor Green
} else {
    Write-Host "⚠️ いくつかの項目で警告または失敗があります。" -ForegroundColor Yellow
}

# 詳細情報
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "スクリプト統計情報" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$lines = $scriptContent -split "`n"
Write-Host "総行数: $($lines.Count)" -ForegroundColor Cyan
Write-Host "Param ブロック行数: $(($lines | Where-Object { $_ -match 'param|switch|string' }).Count)" -ForegroundColor Cyan
Write-Host "Try-Catch ブロック数: $(([regex]::Matches($scriptContent, 'try\s*\{', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count)" -ForegroundColor Cyan

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "推奨アクション" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($passCount -eq $totalCount) {
    Write-Host "1. スクリプトを実行してパラメータが正常に動作するか確認" -ForegroundColor Green
    Write-Host "   - 対話モード: .\getILSpyCmd.ps1" -ForegroundColor Green
    Write-Host "   - 非対話モード: .\getILSpyCmd.ps1 -NoKeyWait" -ForegroundColor Green
    Write-Host "2. ログファイルに適切な情報が記録されているか確認" -ForegroundColor Green
    Write-Host "3. 終了コードが正常に返却されているか確認" -ForegroundColor Green
} else {
    Write-Host "1. 失敗した項目を修正してください" -ForegroundColor Red
    Write-Host "2. 修正後、再度検証スクリプトを実行してください" -ForegroundColor Red
}

Write-Host ""
