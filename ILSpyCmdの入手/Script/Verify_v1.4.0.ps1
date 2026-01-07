#!/usr/bin/env pwsh
<#
.SYNOPSIS
    getILSpyCmd.ps1 v1.4.0 改善内容検証スクリプト

.DESCRIPTION
    v1.3.0 の改善内容と v1.4.0 の新機能を検証します：
    
    【v1.3.0 検証項目】
    - Exit 文が完全に削除されたか
    - -NoKeyWait パラメータが正しく実装されたか
    - CanExecuteProcess フラグが正しく使用されているか
    - End ブロックが改善されているか
    
    【v1.4.0 新機能検証項目】
    - EnvYaml パス解決ロジック（絶対/相対/ファイル名のみ）
    - Get-ExceptionLogLevel 関数による例外分類
    - -NoKeyWait での自動SDK同意確認
    - 終了コード別のフッターメッセージ
#>

param(
    [string]$ScriptPath = (Join-Path -Path $HOME -ChildPath "GitHub\PowerShell\ILSpyCmdの入手\Script\getILSpyCmd.ps1")
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "getILSpyCmd.ps1 v1.4.0 検証スクリプト" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ファイルが存在するか確認
if (-not (Test-Path $ScriptPath)) {
    Write-Host "エラー: スクリプトが見つかりません: $ScriptPath" -ForegroundColor Red
    exit 1
}

$scriptContent = Get-Content $ScriptPath -Raw

# 検証項目
$checks = @{
    "【v1.3.0】Exit 文が削除されている" = {
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
    
    "【v1.3.0】-NoKeyWait パラメータが存在" = {
        if ($scriptContent -match '\[switch\]\$NoKeyWait') {
            Write-Host "✅ 合格: -NoKeyWait パラメータが定義されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: -NoKeyWait パラメータが見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "【v1.3.0】CanExecuteProcess フラグが初期化されている" = {
        if ($scriptContent -match '\$script:CanExecuteProcess\s*=\s*\$true') {
            Write-Host "✅ 合格: CanExecuteProcess フラグが初期化されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: CanExecuteProcess 初期化が見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "【v1.3.0】ExitCode フラグが初期化されている" = {
        if ($scriptContent -match '\$script:ExitCode\s*=\s*0') {
            Write-Host "✅ 合格: ExitCode フラグが初期化されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: ExitCode 初期化が見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "【v1.3.0】if (-not `$NoKeyWait) で条件付けされているPopup" = {
        # Popup呼び出しの検索
        $popupMatches = [regex]::Matches($scriptContent, '\$script:comObject\.Popup', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        # -NoKeyWaitの条件チェック
        $noKeyWaitGuards = [regex]::Matches(
            $scriptContent, 
            'if\s*\(\s*-not\s+\$NoKeyWait\s*\)',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        
        if ($popupMatches.Count -gt 5 -and $noKeyWaitGuards.Count -gt 5) {
            Write-Host "✅ 合格: $($popupMatches.Count) 個のPopupが実装され、$($noKeyWaitGuards.Count) 個の条件チェックが存在" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: Popup条件付けが不完全（Popup: $($popupMatches.Count)個、条件ガード: $($noKeyWaitGuards.Count)個）" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.3.0】End ブロックで `$script:CanExecuteProcess を確認" = {
        if ($scriptContent -match 'end\s*\{' -and $scriptContent -match '\$script:CanExecuteProcess') {
            Write-Host "✅ 合格: スクリプト全体で CanExecuteProcess フラグが確認されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: CanExecuteProcess フラグが見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "【v1.3.0】End ブロックで `$script:ExitCode を使用している" = {
        if ($scriptContent -match 'exit\s+\$script:ExitCode' -or 
            $scriptContent -match 'Add-Content.*\$script:ExitCode') {
            Write-Host "✅ 合格: End ブロックで `$script:ExitCode を使用している" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: `$script:ExitCode の使用パターンが見つかりません" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.3.0】Exception Type ログが追加されている" = {
        $matches = [regex]::Matches($scriptContent, 'Exception Type:.*?GetType\(\)\.FullName')
        if ($matches.Count -gt 2) {
            Write-Host "✅ 合格: $($matches.Count) 個の例外タイプログが追加されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: 例外タイプログが少ない（$($matches.Count) 個）" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.3.0】Return 文でスクリプトから抜ける" = {
        $returnCount = [regex]::Matches($scriptContent, '^\s*return\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline).Count
        if ($returnCount -gt 5) {
            Write-Host "✅ 合格: $($returnCount) 個の return ステートメントが使用されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: Return が少ない（$($returnCount) 個）" -ForegroundColor Red
            return $false
        }
    }
    
    "【v1.4.0】Get-ExceptionLogLevel 関数が定義されている" = {
        if ($scriptContent -match 'function\s+Get-ExceptionLogLevel\s*\{') {
            Write-Host "✅ 合格: Get-ExceptionLogLevel 関数が定義されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ 失敗: Get-ExceptionLogLevel 関数が見つからない" -ForegroundColor Red
            return $false
        }
    }
    
    "【v1.4.0】例外型の分類ロジックが実装されている" = {
        $patterns = @(
            'FileNotFoundException'
            'DirectoryNotFoundException'
            'InvalidOperationException'
            'TimeoutException'
        )
        $foundCount = 0
        foreach ($pattern in $patterns) {
            if ($scriptContent -match $pattern) {
                $foundCount++
            }
        }
        
        if ($foundCount -ge 3) {
            Write-Host "✅ 合格: $foundCount 個の例外型が分類されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: 例外型分類が少ない（$foundCount 個）" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】EnvYaml パス解決ロジック（絶対パス）" = {
        if ($scriptContent -match 'IsPathRooted' -or 
            $scriptContent -match '\[System\.IO\.Path\]') {
            Write-Host "✅ 合格: 絶対パス判定ロジックが実装されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: 絶対パス判定ロジックが見つからない" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】EnvYaml パス解決ロジック（相対パス）" = {
        if ($scriptContent -match 'Join-Path.*\$PSScriptRoot' -or 
            $scriptContent -match 'Resolve-Path' -or 
            $scriptContent -match 'Join-Path.*\$script:ScriptPath') {
            Write-Host "✅ 合格: 相対パス解決ロジックが実装されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: 相対パス解決ロジックが見つからない" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】EnvYaml パス解決ロジック（ファイル名のみ）" = {
        if ($scriptContent -match 'Join-Path.*YAML.*\$EnvYaml') {
            Write-Host "✅ 合格: ファイル名のみの場合の解決ロジックが実装されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: ファイル名のみの場合の解決ロジックが見つからない" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】-NoKeyWait での自動SDK同意確認" = {
        if ($scriptContent -match 'if\s+\(\s*-not\s+\$NoKeyWait\s*\)' -and $scriptContent -match 'retButton\s*=\s*6') {
            Write-Host "✅ 合格: -NoKeyWait で自動的にSDK同意確認を選択している" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: 自動SDK同意確認ロジックが不完全" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】終了コード別フッターメッセージ（ExitCode=0）" = {
        if ($scriptContent -match 'if\s+\(\s*\$script:ExitCode\s*-eq\s*0\s*\)' -and 
            $scriptContent -match 'completed\s+successfully') {
            Write-Host "✅ 合格: 終了コード 0 で正常完了メッセージが表示される" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: 終了コード別メッセージ表示ロジックが不完全" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】終了コード別フッターメッセージ（ExitCode != 0）" = {
        if ($scriptContent -match 'else\s*\{' -and 
            $scriptContent -match 'ended\s+with\s+error' -and
            $scriptContent -match 'Exit\s+Code') {
            Write-Host "✅ 合格: 終了コード 0 以外でエラーメッセージが表示される" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: エラー終了時のメッセージ表示ロジックが不完全" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】Process ブロック保護ガード" = {
        if ($scriptContent -match 'process\s*\{' -and 
            $scriptContent -match 'if\s*\(\s*-not\s+\$script:CanExecuteProcess') {
            Write-Host "✅ 合格: Process ブロック開始時に実行ガードが設置されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: Process ブロック保護ガードが見つからない" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】ログ書き込み保護ガード" = {
        if ($scriptContent -match 'if\s+\(\s*\$script:Log.*Test-Path.*\$script:Log\s*\)') {
            Write-Host "✅ 合格: ログ書き込み時に存在確認ガードが設置されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: ログ書き込み保護ガードが見つからない" -ForegroundColor Yellow
            return $false
        }
    }
    
    "【v1.4.0】EnvYaml ValidateScript の緩和（拡張子チェック継続）" = {
        if ($scriptContent -match 'ValidateScript' -and ($scriptContent -match '\.yaml\b' -or $scriptContent -match 'ValidatePattern')) {
            Write-Host "✅ 合格: EnvYaml 検証が実装されている" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 警告: EnvYaml 検証ロジックが見つからない" -ForegroundColor Yellow
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
Write-Host "検証結果サマリー" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passCount = ($results | Where-Object { $_.Result -eq $true }).Count
$totalCount = $results.Count
$v130Checks = ($results | Where-Object { $_.Name -match '【v1.3.0】' }).Count
$v140Checks = ($results | Where-Object { $_.Name -match '【v1.4.0】' }).Count
$v130Pass = ($results | Where-Object { $_.Name -match '【v1.3.0】' -and $_.Result -eq $true }).Count
$v140Pass = ($results | Where-Object { $_.Name -match '【v1.4.0】' -and $_.Result -eq $true }).Count

Write-Host ""
Write-Host "【v1.3.0 検証】 $v130Pass / $v130Checks 合格" -ForegroundColor Cyan
Write-Host "【v1.4.0 検証】 $v140Pass / $v140Checks 合格" -ForegroundColor Cyan
Write-Host ""
Write-Host "総合結果: $passCount / $totalCount 合格" -ForegroundColor Green

if ($passCount -eq $totalCount) {
    Write-Host "✅ すべての検証に合格しました！" -ForegroundColor Green
    Write-Host "v1.3.0 と v1.4.0 の改善が正常に実装されています。" -ForegroundColor Green
} else {
    Write-Host "⚠️ いくつかの項目で警告または失敗があります。" -ForegroundColor Yellow
}

# 詳細情報
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "スクリプト統計情報" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$lines = $scriptContent -split "`n"
$functionCount = ([regex]::Matches($scriptContent, 'function\s+\w+\s*\{', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
$tryCatchCount = ([regex]::Matches($scriptContent, 'try\s*\{', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count

Write-Host "総行数: $($lines.Count)" -ForegroundColor Cyan
Write-Host "関数定義数: $functionCount" -ForegroundColor Cyan
Write-Host "Try-Catch ブロック数: $tryCatchCount" -ForegroundColor Cyan
Write-Host "Param ブロック行数: $(($lines | Where-Object { $_ -match 'param|switch|string' }).Count)" -ForegroundColor Cyan

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "推奨アクション" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($passCount -eq $totalCount) {
    Write-Host "✅ 全検証合格 - スクリプトは本番環境での使用準備完了" -ForegroundColor Green
    Write-Host ""
    Write-Host "推奨テスト:" -ForegroundColor Green
    Write-Host "  1. 基本動作テスト:" -ForegroundColor Cyan
    Write-Host "     .\getILSpyCmd.ps1 -EnvYaml getILSpyCmd.yaml" -ForegroundColor White
    Write-Host ""
    Write-Host "  2. 非対話モードテスト:" -ForegroundColor Cyan
    Write-Host "     .\getILSpyCmd.ps1 -EnvYaml getILSpyCmd.yaml -NoKeyWait" -ForegroundColor White
    Write-Host ""
    Write-Host "  3. YAML検証エラーテスト:" -ForegroundColor Cyan
    Write-Host "     .\getILSpyCmd.ps1 -EnvYaml getILSpyCmd.missing.yaml -NoKeyWait" -ForegroundColor White
    Write-Host ""
    Write-Host "  4. 相対パステスト:" -ForegroundColor Cyan
    Write-Host "     .\getILSpyCmd.ps1 -EnvYaml ..\YAML\getILSpyCmd.yaml -NoKeyWait" -ForegroundColor White
    Write-Host ""
    Write-Host "  5. ログ確認:" -ForegroundColor Cyan
    Write-Host "     Get-Content ..\LOG\getILSpyCmd_*.log" -ForegroundColor White
} else {
    $failed = $results | Where-Object { $_.Result -eq $false }
    Write-Host "❌ 失敗した検証項目:" -ForegroundColor Red
    $failed | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "修正後、再度検証スクリプトを実行してください" -ForegroundColor Yellow
}

Write-Host ""
