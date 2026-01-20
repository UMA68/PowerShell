<#
.SYNOPSIS
    メッセージをコンソールとログファイルに同時出力する関数

.DESCRIPTION
    Write-LogOutput 関数は、指定されたメッセージをコンソールに表示すると同時に、
    ログファイルに追記します。Tee-Object コマンドレットを使用して、
    デュアル出力を実現します。
    
    主な用途：
    - スクリプト実行ログの記録
    - デバッグ情報の出力と保存
    - 処理結果の可視化とアーカイブ

.PARAMETER Message
    出力するメッセージ文字列を指定します（必須）。
    任意の文字列を指定可能で、改行文字も含めることができます。

.PARAMETER LogPath
    ログファイルの完全パスを指定します（必須）。
    ファイルが存在しない場合は自動的に作成されます。
    既存ファイルには追記（Append）されます。

.EXAMPLE
    Write-LogOutput -Message "処理を開始しました" -LogPath "C:\Logs\app.log"
    
    説明:
    "処理を開始しました" というメッセージをコンソールに表示し、
    同時に C:\Logs\app.log ファイルに追記します。

.EXAMPLE
    $logFile = "C:\Temp\debug.log"
    Write-LogOutput -Message "エラーが発生しました" -LogPath $logFile
    
    説明:
    変数を使用してログファイルパスを指定する例。
    複数回呼び出す場合に便利です。

.EXAMPLE
    1..5 | ForEach-Object {
        Write-LogOutput -Message "処理 $_ を実行中" -LogPath "C:\Logs\process.log"
    }
    
    説明:
    ループ処理での使用例。各反復でメッセージがコンソールとログに出力されます。

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    System.String
    コンソールに出力されるメッセージ文字列。

.NOTES
    ファイル名: Log-Output.ps1
    作成者: UMA68
    バージョン: 1.0.0
    
    動作仕様:
    - ログファイルは常に追記モード（Append）で開かれます
    - ログディレクトリが存在しない場合はエラーになります（事前作成が必要）
    - 文字エンコーディングはシステムデフォルト（通常UTF-8）
    
    パフォーマンス:
    - Tee-Object を使用するため、大量の出力では若干のオーバーヘッドがあります
    - リアルタイム出力とファイル書き込みを同時に行います
    
    使用例:
        # ログディレクトリを事前作成
        $logDir = "C:\Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory | Out-Null
        }
        
        # ログファイルパスを定義
        $logPath = Join-Path $logDir "app_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        
        # 関数を使用
        Write-LogOutput -Message "アプリケーション起動" -LogPath $logPath
        Write-LogOutput -Message "設定ファイル読み込み完了" -LogPath $logPath
        Write-LogOutput -Message "処理完了" -LogPath $logPath

.LINK
    Tee-Object
    Out-Default
    Write-Output

#>

function Write-LogOutput {
    # ================================================
    # ログの書き込み関数
    # Write-LogOutput -Message "String" -LogPath "LogFullPath"
    # ================================================
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    Write-Output $Message | Tee-Object -FilePath $LogPath -Append | Out-Default
}


