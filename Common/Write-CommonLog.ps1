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
    - PowerShell終了時のMutexクリーンアップ処理
    
    ログメッセージ形式:
    yyyy-MM-dd HH:mm:ss [LEVEL] - Message

.PARAMETER Message
    ログに出力するメッセージ。必須パラメーター。
    複数行のメッセージも対応可能です。

.PARAMETER LogPath
    ログファイルの絶対パス。必須パラメーター。
    ファイルが存在しない場合は自動作成され、存在する場合は追記されます。

.PARAMETER Level
    ログレベル。省略時は 'INFO' が使用されます。
    有効な値: 'INFO', 'WARN', 'ERROR', 'DEBUG'
    
    - INFO: 通常の情報メッセージ（デフォルト）
    - WARN: 警告メッセージ
    - ERROR: エラーメッセージ
    - DEBUG: デバッグ情報（詳細トラブルシューティング用）

.EXAMPLE
    Write-CommonLog -Message "処理を開始します" -LogPath "C:\Logs\app.log"
    
    INFO レベルで通常のログメッセージを出力します。
    出力例: 2025-11-27 16:30:45 [INFO] - 処理を開始します

.EXAMPLE
    Write-CommonLog -Message "接続がタイムアウトしました" -LogPath "C:\Logs\app.log" -Level "WARN"
    
    WARN レベルで警告メッセージを出力します。
    出力例: 2025-11-27 16:30:50 [WARN] - 接続がタイムアウトしました

.EXAMPLE
    Write-CommonLog -Message "ファイルが見つかりません: C:\data.txt" -LogPath "C:\Logs\app.log" -Level "ERROR"
    
    ERROR レベルでエラーメッセージを出力します。
    出力例: 2025-11-27 16:31:00 [ERROR] - ファイルが見つかりません: C:\data.txt

.EXAMPLE
    Write-CommonLog -Message "変数の値: $debugValue" -LogPath "C:\Logs\app.log" -Level "DEBUG"
    
    DEBUG レベルでデバッグ情報を出力します。
    出力例: 2025-11-27 16:31:10 [DEBUG] - 変数の値: TestValue

.NOTES
    File Name      : Write-CommonLog.ps1
    Author         : UMA
    Prerequisite   : PowerShell 5.1 以上
    Version        : 1.1.0
    
    注意事項:
    - この関数は PowerShell 終了時に自動的に Mutex リソースをクリーンアップします
    - NoDoubleActivation_Mutex グローバル変数が存在する場合、終了時に解放されます
    - ログファイルは UTF-8 エンコーディングで保存されます
    - Tee-Object を使用しているため、コンソールとファイルへ同時出力されます
    
    依存関係:
    - NoDoubleActivation_Mutex: オプション（二重起動防止機能で使用される場合）
    
    使用シナリオ:
    - アプリケーションの実行ログ記録
    - エラートラッキングとデバッグ
    - 監査証跡の作成
    - トラブルシューティング情報の収集

.LINK
    https://github.com/UMA68/PowerShell
#>
function Write-CommonLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$LogPath,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] - $Message"
    
    # コンソールに出力（パイプラインに流さない）
    Write-Host $logMessage
    
    # -WhatIfモードでも必ずログファイルに書き込む
    Add-Content -Path $LogPath -Value $logMessage -Encoding UTF8 -WhatIf:$false

    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if (Get-Variable -Name NoDoubleActivation_Mutex -Scope Global -ErrorAction SilentlyContinue) {
            $global:NoDoubleActivation_Mutex.ReleaseMutex()
            $global:NoDoubleActivation_Mutex.Close()
        }
    } -SupportEvent -MessageData "NoDoubleActivation_Event"
}
