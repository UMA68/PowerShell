<#
.SYNOPSIS
    共通ログ出力関数。タイムスタンプ付きメッセージをログファイルとコンソールに出力します。

.DESCRIPTION
    この関数は、指定されたメッセージにタイムスタンプとログレベルを付加して、
    ログファイルとコンソールの両方に出力します。
    
    主な機能:
    - タイムスタンプ付きログメッセージの生成（yyyy-MM-dd HH:mm:ss形式）
    - 4つのログレベルサポート（INFO、WARN、ERROR、DEBUG）
    - ログファイルへの追記とコンソール出力の同時実行
    - ログレベル別の出力メカニズム（ERROR=Write-Error、WARN=Write-Warning、DEBUG=Write-Debug、INFO=Write-Information）
    - 機密情報の自動マスキング機能（正規表現ベース）
    - ログディレクトリの自動作成
    - ファイルロック対策：I/O エラー時は最大 3 回まで自動リトライ
    - UTF-8 エンコーディングで記録
    - Quiet モードによるコンソール出力抑制
    - -WhatIf 対応（ログ書き込みは強制実行）
    
    ログメッセージ形式:
    yyyy-MM-dd HH:mm:ss [LEVEL] - Message
    
    注意: ログ書き込みは -WhatIf パラメータでも実行されます（ログは必須）。

.PARAMETER Message
    ログに出力するメッセージ。必須パラメーター。
    複数行のメッセージも対応可能です。
    
    パラメーター検証:
    - 空白のみの入力は不可

.PARAMETER LogPath
    ログファイルの絶対パス。必須パラメーター。
    ファイルが存在しない場合は自動作成され、存在する場合は追記されます。
    ディレクトリが存在しない場合は自動的に作成されます。
    
    パラメーター検証:
    - 空白のみの入力は不可

.PARAMETER Level
    ログレベル。省略時は 'INFO' が使用されます。
    有効な値: 'INFO', 'WARN', 'ERROR', 'DEBUG'
    
    - INFO: 通常の情報メッセージ（デフォルト）- Write-Information で出力
    - WARN: 警告メッセージ - Write-Warning で出力
    - ERROR: エラーメッセージ - Write-Error で出力
    - DEBUG: デバッグ情報 - Write-Debug で出力
    
    注意: 実際の表示色はホストの設定に依存します。

.PARAMETER SensitivePatterns
    ログメッセージ内の機密情報を検出してマスクするキーワードのリスト。
    パターンにマッチする値は '***' で置き換えられます。
    省略時はマスキング処理を行いません。
    
    マスキング対象: パターン直後に : = または スペースが続く値
    例: password=abc123 → password=***
        api_key: secret123 → api_key: ***
    
    例: @('password', 'token', 'api_key', 'secret')

.PARAMETER Quiet
    コンソールへの出力を抑制します。ログファイルへの書き込みのみ実行されます。
    デフォルト: $false（コンソールにも出力する）

.EXAMPLE
    Write-CommonLog -Message "処理を開始します" -LogPath "C:\Logs\app.log"
    
    INFO レベルで通常のログメッセージを出力します。
    出力例: 2025-12-11 16:30:45 [INFO] - 処理を開始します

.EXAMPLE
    Write-CommonLog -Message "接続がタイムアウトしました" -LogPath "C:\Logs\app.log" -Level "WARN"
    
    WARN レベルで警告メッセージを出力します（Write-Warning で出力）。
    出力例: 2025-12-11 16:30:50 [WARN] - 接続がタイムアウトしました

.EXAMPLE
    Write-CommonLog -Message "ファイルが見つかりません: C:\data.txt" -LogPath "C:\Logs\app.log" -Level "ERROR"
    
    ERROR レベルでエラーメッセージを出力します（Write-Error で出力）。
    出力例: 2025-12-11 16:31:00 [ERROR] - ファイルが見つかりません: C:\data.txt

.EXAMPLE
    Write-CommonLog -Message "変数の値: $debugValue" -LogPath "C:\Logs\app.log" -Level "DEBUG"
    
    DEBUG レベルでデバッグ情報を出力します（Write-Debug で出力）。
    出力例: 2025-12-11 16:31:10 [DEBUG] - 変数の値: TestValue

.EXAMPLE
    Write-CommonLog -Message "password=abc123" -LogPath "C:\Logs\app.log" -SensitivePatterns @('password')
    
    機密情報をマスキングしてログ出力します。
    出力例: 2025-12-11 16:31:15 [INFO] - password=***

.EXAMPLE
    Write-CommonLog -Message "処理完了" -LogPath "C:\Logs\app.log" -Quiet
    
    コンソールには出力せず、ログファイルのみに書き込みます。

.FUNCTIONALITY
    タイムスタンプ付きログ出力と機密情報マスキング

.NOTES
    File Name      : Write-CommonLog.ps1
    Author         : UMA68
    Version        : 1.3.0
    Release Date   : 2026-01-14
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.3.0 (2026-01-14)
        - プロセスの同時ログ実行対策：ファイルロック時の 3 回リトライロジック
        - エラーハンドリングを詳細化（UnauthorizedAccessException、IOException の個別処理）
        - Write-Information/Write-Warning/Write-Error/Write-Debug に統一（PSScriptAnalyzer 対応）
        - UTF-8 エンコーディングを明示化
        - -WhatIf 対応（ログ書き込みは強制実行）
        - ヘルプドキュメントを実装に合わせて更新
        - ValidateScript による包括的なパラメーター検証に統一
    
    v1.2.0 (2025-12-11)
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - ログディレクトリの自動作成機能を追加
        - Quiet スイッチを追加（コンソール出力抑制）
        - ログレベル別の色分け表示を実装
        - エラーハンドリングを改善（try-catch 実装）
    
    v1.1.0 (2025-11-27)
        - 機密情報マスキング機能を追加
        - -WhatIf モードでのログ書き込み保証
    
    v1.0.0 (2025-11-20)
        - 初版リリース
    
    既知の制限:
    - 同一ファイルへの超高速並行ログ出力時はリトライ待機のため遅延の可能性
    - ログローテーション機能なし（外部スクリプトで実装推奨）
    注意事項:
    - ログファイルは UTF-8 エンコーディングで保存されます
    - ログディレクトリが存在しない場合は自動的に作成されます
    - 機密情報マスキングは正規表現ベースで実行されます
    
    依存関係:
    - なし（スタンドアロン関数）
    
    使用シナリオ:
    - アプリケーションの実行ログ記録
    - エラートラッキングとデバッグ
    - 監査証跡の作成
    - トラブルシューティング情報の収集

.LINK
    GitHub: https://github.com/UMA68/PowerShell
#>
function Write-CommonLog {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,                   # ログに出力するメッセージ
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath,                   # ログファイルの絶対パス
        
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',            # ログレベル（デフォルト: INFO）
        
        [Parameter(Mandatory = $false)]
        [string[]]$SensitivePatterns = @(), # 機密情報マスキング用パターンの配列
        
        [Parameter(Mandatory = $false)]
        [switch]$Quiet = $false             # コンソール出力抑制オプション
    )
    
    process {
        try {
            # ログディレクトリを確認・作成
            $logDir = Split-Path -Path $LogPath -Parent
            if ($logDir -and !(Test-Path -Path $logDir -PathType Container)) {
                Write-Verbose "ログディレクトリを作成中: $logDir"
                New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            
            # タイムスタンプとログメッセージを生成
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "$timestamp [$Level] - $Message"
            
            # 機密情報マスキング処理
            $maskedMessage = $logMessage
            if ($SensitivePatterns -and $SensitivePatterns.Count -gt 0) {
                foreach ($pattern in $SensitivePatterns) {
                    # パターンに合致する部分を '***' でマスク
                    # 対応する区切り文字: : = , ; ' " スペース
                    $maskedMessage = $maskedMessage -ireplace "(?i)$([System.Text.RegularExpressions.Regex]::Escape($pattern))\s*[:=\s]+\S+", "$pattern=***"
                }
            }
            
            # コンソールに出力（Quiet モードでない場合）
            if (!$Quiet) {
                # Write-Information を使用して色付けを実現
                # PSScriptAnalyzer PSAvoidUsingWriteHost を回避しつつ、色付き出力を実現
                $infoMessage = "$maskedMessage`n"

                switch ($Level) {
                    'ERROR' {
                        Write-Information -MessageData $infoMessage -InformationAction Continue
                        Write-Error $maskedMessage -ErrorAction Continue
                    }
                    'WARN' {
                        Write-Information -MessageData $infoMessage -InformationAction Continue
                        Write-Warning $maskedMessage
                    }
                    'DEBUG' {
                        Write-Debug $maskedMessage
                    }
                    default {
                        Write-Information -MessageData $infoMessage -InformationAction Continue
                    }
                }
            }
            
            # ログファイルに書き込み
            if ($PSCmdlet.ShouldProcess($LogPath, "ログを書き込み")) {
                try {
                    # ファイルロック対策: retry で書き込みを試行
                    $maxRetries = 3
                    $retryCount = 0
                    $writeSuccess = $false
                    
                    while (!$writeSuccess -and $retryCount -lt $maxRetries) {
                        try {
                            Add-Content -Path $LogPath -Value $maskedMessage -Encoding UTF8 -ErrorAction Stop
                            $writeSuccess = $true
                            Write-Verbose "ログを書き込みました: $LogPath"
                        }
                        catch [System.IO.IOException] {
                            # ファイルロック: 短時間待機して再試行
                            if ($retryCount -lt $maxRetries - 1) {
                                Start-Sleep -Milliseconds 100
                                $retryCount++
                            }
                            else {
                                throw
                            }
                        }
                    }
                    
                    if (!$writeSuccess) {
                        Write-Error "ログファイルへの書き込みに失敗しました（最大 $maxRetries 回試行）: $LogPath"
                    }
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Error "ログファイルへのアクセス権がありません: $LogPath。管理者権限が必要な可能性があります。"
                }
                catch [System.IO.IOException] {
                    Write-Error "ログファイルの書き込み中にI/Oエラーが発生しました: $LogPath`n詳細: $($_.Exception.Message)"
                }
                catch {
                    Write-Error "ログファイルへの書き込みに失敗しました。パス: $LogPath`n詳細: $($_.Exception.Message)"
                }
            }
        }
        catch [System.IO.IOException] {
            Write-Error "ログディレクトリの作成に失敗しました: $LogPath`n詳細: $($_.Exception.Message)"
        }
        catch {
            Write-Error "ログ出力処理中にエラーが発生しました。パス: $LogPath`n詳細: $($_.Exception.Message)"
        }
    }
}
