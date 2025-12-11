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
    - ログレベル別の色分け表示（ERROR=赤、WARN=黄、DEBUG=灰）
    - 機密情報の自動マスキング機能
    - ログディレクトリの自動作成
    - Quiet モードによるコンソール出力抑制
    
    ログメッセージ形式:
    yyyy-MM-dd HH:mm:ss [LEVEL] - Message

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
    
    - INFO: 通常の情報メッセージ（デフォルト、白色表示）
    - WARN: 警告メッセージ（黄色表示）
    - ERROR: エラーメッセージ（赤色表示）
    - DEBUG: デバッグ情報（灰色表示）

.PARAMETER SensitivePatterns
    ログメッセージ内の機密情報を検出してマスクするキーワードのリスト。
    パターンにマッチする値は '***' で置き換えられます。
    省略時はマスキング処理を行いません。
    
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
    
    WARN レベルで警告メッセージを出力します（黄色表示）。
    出力例: 2025-12-11 16:30:50 [WARN] - 接続がタイムアウトしました

.EXAMPLE
    Write-CommonLog -Message "ファイルが見つかりません: C:\data.txt" -LogPath "C:\Logs\app.log" -Level "ERROR"
    
    ERROR レベルでエラーメッセージを出力します（赤色表示）。
    出力例: 2025-12-11 16:31:00 [ERROR] - ファイルが見つかりません: C:\data.txt

.EXAMPLE
    Write-CommonLog -Message "変数の値: $debugValue" -LogPath "C:\Logs\app.log" -Level "DEBUG"
    
    DEBUG レベルでデバッグ情報を出力します（灰色表示）。
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
    Version        : 1.2.0
    Release Date   : 2025-12-11
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.2.0 (2025-12-11)
        - 到達不可能なコード（Mutex イベント登録）を削除
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - ログディレクトリの自動作成機能を追加
        - Quiet スイッチを追加（コンソール出力抑制）
        - ログレベル別の色分け表示を実装
        - エラーハンドリングを改善（try-catch 実装）
        - スコープ変数管理に対応（$script: プレフィックス）
        - Write-Verbose によるデバッグ情報追加
        - Author を "UMA68" に統一
        - 単一責務の原則を遵守（Mutex 管理を削除）
    
    v1.1.0 (2025-11-27)
        - 機密情報マスキング機能を追加
        - -WhatIf モードでのログ書き込み保証
    
    v1.0.0 (2025-11-20)
        - 初版リリース
    
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,                   # ログに出力するメッセージ
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath,                   # ログファイルの絶対パス
        
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',            # ログレベル（デフォルト: INFO）
        
        [Parameter(Mandatory=$false)]
        [string[]]$SensitivePatterns = @(), # 機密情報マスキング用パターンの配列
        
        [Parameter(Mandatory=$false)]
        [switch]$Quiet = $false             # コンソール出力抑制オプション
    )
    
    begin {
        # ログディレクトリを確認・作成
        $script:LogDir = Split-Path -Path $LogPath -Parent
        if ($script:LogDir -and -not (Test-Path -Path $script:LogDir)) { # ディレクトリが存在しない場合
            Write-Verbose "ログディレクトリが存在しません。作成中: $script:LogDir"
            try {
                New-Item -Path $script:LogDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "ログディレクトリを作成しました: $script:LogDir"
            }
            catch {
                Write-Error "ログディレクトリの作成に失敗しました: $script:LogDir`n詳細: $($_.Exception.Message)"
                return
            }
        }
    }
    
    process {
        try {
            # タイムスタンプとログメッセージを生成
            $script:Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $script:LogMessage = "$script:Timestamp [$Level] - $Message"
            
            # 機密情報マスキング処理
            $script:MaskedMessage = $script:LogMessage
            if ($SensitivePatterns -and $SensitivePatterns.Count -gt 0) { # マスキングパターンが指定されている場合
                foreach ($pattern in $SensitivePatterns) { # 機密情報パターンごとにマスキング
                    # パターンに合致する部分を '***' でマスク（値の部分をマスク）
                    # 例: "password=abc123" → "password=***"
                    $script:MaskedMessage = $script:MaskedMessage -ireplace "($pattern\s*[:=\s]+)[^\s,;`"']+", "`$1***"
                }
            }
            
            # コンソールに出力（Quiet モードでない場合）
            if (-not $Quiet) { # Quiet モードでない場合
                switch ($Level) {
                    'ERROR' { Write-Host $script:MaskedMessage -ForegroundColor Red }
                    'WARN'  { Write-Host $script:MaskedMessage -ForegroundColor Yellow }
                    'DEBUG' { Write-Host $script:MaskedMessage -ForegroundColor Gray }
                    default { Write-Host $script:MaskedMessage }
                }
            }
            
            # ログファイルに書き込み（-WhatIfモードでも必ず書き込む）
            Add-Content -Path $LogPath -Value $script:MaskedMessage -Encoding UTF8 -ErrorAction Stop -WhatIf:$false
            Write-Verbose "ログを書き込みました: $LogPath"
        }
        catch {
            Write-Error "ログ出力に失敗しました。パス: $LogPath`n詳細: $($_.Exception.Message)"
        }
    }
}
