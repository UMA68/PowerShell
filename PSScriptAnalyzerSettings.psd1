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
    # 明示的なルール指定により、シグナル対ノイズ比を高く保つ
    IncludeRules = @(
        # 変数とスコープ関連
        'PSUseDeclaredVarsMoreThanAssignments',    # 宣言のみで未使用の変数を検出
        'PSAvoidGlobalVars',                       # グローバル変数の使用を警告
        
        # コーディングスタイル
        'PSUseCorrectCasing',                      # 正しい大文字小文字の使用
        'PSUseConsistentWhitespace',               # 一貫した空白の使用
        'PSUseConsistentIndentation',              # 一貫したインデントの使用
        
        # 関数とパラメータ
        'PSUseApprovedVerbs',                      # 承認された動詞の使用
        'PSUseSingularNouns',                      # 関数名に単数形の名詞を使用
        'PSAvoidUsingPositionalParameters',        # 位置パラメータの回避
        'PSReservedParams',                        # 予約パラメータ名のチェック
        'PSReservedCmdletChar',                    # 予約文字のチェック
        
        # 出力とメッセージ
        'PSAvoidUsingWriteHost',                   # Write-Hostの代わりにWrite-Outputを使用（インタラクティブ用途では除外設定で許容）
        
        # エイリアスとコマンド
        'PSAvoidUsingCmdletAliases',               # エイリアス使用の回避
        'PSAvoidUsingDeprecatedManifestFields',    # 非推奨のマニフェストフィールドの回避
        
        # ベストプラクティス
        'PSAvoidUsingPlainTextForPassword',        # プレーンテキストパスワードの回避
        'PSAvoidUsingConvertToSecureStringWithPlainText',  # プレーンテキストからのSecureString変換を警告
        'PSUseShouldProcessForStateChangingFunctions',    # 状態変更関数でのShouldProcessの使用
        'PSProvideCommentHelp',                    # コメントベースヘルプの提供
        'PSUseOutputTypeCorrectly',                # OutputType属性の適切な使用
        
        # エラーハンドリング
        'PSAvoidUsingEmptyCatchBlock',             # 空のcatchブロックの回避
        'PSUseCmdletCorrectly',                    # Cmdletの正しい使用
        
        # パフォーマンス
        'PSAvoidAssignmentToAutomaticVariable',    # 自動変数への代入を回避
        'PSUsePSCredentialType'                    # PSCredential型の使用
    )
    
    Rules = @{
        # 空白の一貫性ルール
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckOpenBrace = $true              # 開き中括弧の前の空白をチェック
            CheckOpenParen = $true              # 開き括弧の前の空白をチェック
            CheckOperator = $true               # 演算子の前後の空白をチェック
            CheckSeparator = $true              # セパレータの後の空白をチェック
            CheckInnerBrace = $true             # 中括弧内の空白をチェック
            CheckPipe = $true                   # パイプの前後の空白をチェック
            CheckPipeForRedundantWhitespace = $true  # パイプの冗長な空白をチェック
            CheckParameter = $false             # パラメータの空白はチェックしない
        }
        
        # インデントの一貫性ルール
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4                 # インデントサイズ: 4スペース
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'  # パイプラインのインデント
            Kind = 'space'                      # スペースを使用（タブではなく）
        }
        
        # エイリアス回避の詳細設定
        PSAvoidUsingCmdletAliases = @{
            Whitelist = @()                     # 許可するエイリアスのリスト（空）
        }
        
        # コメントヘルプの設定
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $false               # エクスポートされていない関数もチェック
            BlockComment = $true                # ブロックコメント形式を推奨
            VSCodeSnippetCorrection = $true     # VSCodeスニペット形式の修正を有効化
            Placement = 'begin'                 # ヘルプの配置: 関数の先頭
        }
        
        # ShouldProcess の使用
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $true
        }
        
        # 位置パラメータの回避
        PSAvoidUsingPositionalParameters = @{
            CommandAllowList = @()              # 位置パラメータを許可するコマンドのリスト
            Enable = $true
        }
    }
    
    # 除外するルール（必要に応じて追加）
    ExcludeRules = @(
        # ValidateScript内のインデント規則は動的コードブロック内の制限による
        # 機能上の問題がないため除外
        'PSUseConsistentIndentation',
        # インタラクティブなコンソール表示を許容（-ShowInConsole 等の明示オプション時）
        'PSAvoidUsingWriteHost'
    )
    
    # Severity の設定（オプション）
    # Severity = @('Error', 'Warning')  # ErrorとWarningのみ表示する場合
}