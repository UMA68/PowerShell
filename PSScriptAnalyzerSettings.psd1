<#
.SYNOPSIS
    PSScriptAnalyzer の設定ファイル

.DESCRIPTION
    このリポジトリ全体で使用する PowerShell コード品質チェックのルールを定義します。
    
.USAGE
    # リポジトリ全体を再帰的にチェック
    Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
    
    # 特定のファイルをチェック
    Invoke-ScriptAnalyzer -Path .\Script\YourScript.ps1 -Settings .\PSScriptAnalyzerSettings.psd1
    
    # 特定のフォルダーをチェック
    Invoke-ScriptAnalyzer -Path .\Common\ -Recurse -Settings .\PSScriptAnalyzerSettings.psd1

.NOTES
    File Name      : PSScriptAnalyzerSettings.psd1
    Prerequisite   : PSScriptAnalyzer モジュール
                     Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
    
    参考資料:
    - SCOPE_GUIDELINES.md: スコープガイドライン（品質保証セクション）
    - https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview
#>

@{
    # Prefer explicit includes to keep signal high
    IncludeRules = @(
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidGlobalVars',
        'PSUseCorrectCasing',
        'PSUseConsistentWhitespace',
        'PSUseApprovedVerbs',
        'PSAvoidUsingWriteHost'
    )

    Rules = @{
        PSUseConsistentWhitespace = @{
            CheckOpenBrace = $true
            CheckSeparator = $true
            CheckInnerWhitespace = $true
            CheckPipelineLineTermination = $true
        }
    }
}