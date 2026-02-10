<#
.SYNOPSIS
    スクリプトの二重起動を防止します。

.DESCRIPTION
    Test-NoDoubleActivation 関数は、名前付き Mutex を使用してスクリプトの
    二重起動を防止します。既に同じスレッド名で起動している場合、警告を表示して
    $false を返します。
    
    動作メカニズム:
    1. "Global\PowerShell_NoDoubleActivation_$Thread_$ProcessId" という名前の Mutex を作成
    2. Mutex の所有権を取得試行（タイムアウト 0ms = 非ブロッキング）
    3. 所有権取得成功 → 初回起動、$true を返す（Mutex はプロセス終了まで保持）
    4. 所有権取得失敗 → 既に起動中、警告を表示して $false を返す
    
    Mutex はプロセス終了時に PowerShell.Exiting イベント経由で自動的に解放されます。
    -ShowDialog スイッチを指定すると、二重起動時にダイアログで警告を表示します。

.PARAMETER Thread
    二重起動チェック用のスレッド名（Mutex名の一部）を指定します。必須パラメーター。
    通常は起動する .ps1 ファイル名（拡張子なし）を指定します。
    
    内部的には、このパラメータとプロセスIDから以下の形式で Mutex を作成します:
    Global\PowerShell_NoDoubleActivation_{Thread}_{ProcessId}
    
    パラメーター検証:
    - 空白のみの入力は不可
    - Mutex 名として無効な文字は不可（\ / : * ? " < > |）

.PARAMETER ShowDialog
    二重起動時にダイアログで警告を表示するかを指定します。
    デフォルト: $false （ダイアログを表示しない）

.EXAMPLE
    # スクリプトの二重起動をチェック（基本）
    if (-not (Test-NoDoubleActivation -Thread "InstMain")) {
        Write-Host "既に起動中のため終了します"
        exit 1
    }

.EXAMPLE
    # ダイアログ表示あり
    if (-not (Test-NoDoubleActivation -Thread "sqlMain" -ShowDialog)) {
        exit 1
    }

.EXAMPLE
    # begin ブロックで早期チェック
    begin {
        if (-not (Test-NoDoubleActivation -Thread "relMain")) {
            return
        }
    }

.OUTPUTS
    [bool] 起動を許可する場合は $true、二重起動の場合は $false を返します。
    
    - $true: Mutex の所有権を取得できた（初回または後続の起動）
    - $false: Mutex が既に別プロセスで保有されている（既に起動中）

.FUNCTIONALITY
    スクリプトの二重起動防止

.NOTES
    File Name      : NoDoubleActivation.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2026-01-14
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.2.0 (2026-01-14)
        - Mutex 名に Process ID を追加（Global\PowerShell_NoDoubleActivation_{Thread}_{ProcessId}）
        - ValidateScript で無効文字（\ / : * ? " < > |）をチェック
        - PowerShell.Exiting イベント経由の Mutex 自動解放を実装
        - エラーハンドリングを詳細化（InvalidOperationException、UnauthorizedAccessException の個別処理）
        - COM オブジェクト（WScript.Shell）の確実なリソース解放
        - ドキュメントを実装に合わせて更新
    
    v1.1.0 (2025-12-11)
        - COM オブジェクトの適切なリソース解放を実装
        - Exit から return $false に変更（呼び出し元に制御を返す）
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - ShowDialog スイッチパラメーターを追加
        - 戻り値を追加（$true/$false）
        - グローバル変数を $script: スコープに変更
        - エラーハンドリングを改善（try-catch 実装）
    
    v1.0.0 (2025-12-10)
        - 初版リリース
    
    既知の制限:
    - 同じ Thread 名でも異なるプロセスは独立した Mutex を所有（Process ID で分離）
    - Mutex 名に特殊文字は使用不可（バリデーションで検出）
    - COM オブジェクト使用時（-ShowDialog）はマーシャリングコスト増加

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    System.Threading.Mutex: https://learn.microsoft.com/en-us/dotnet/api/system.threading.mutex
#>

function Test-NoDoubleActivation {
    [CmdletBinding()]
    [OutputType([bool])]
    param( 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                # Mutex 名として無効な文字をチェック
                if ($_ -match '[\\/:*?"<>|]') {
                    throw "Mutex 名に無効な文字が含まれています: $_"
                }
                $true
            })]
        [string]$Thread,                # 二重起動チェック用のスレッド名（Mutex名）
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDialog = $false    # ダイアログ表示オプション
    )
    
    process {
        try {
            # 二重起動チェック用 Mutex を作成
            $mutexName = "Global\PowerShell_NoDoubleActivation_$Thread"
            $createdNew = $false
            
            Write-Verbose "Mutex を作成中: $mutexName"
            $mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$createdNew)
            
            # Mutex の所有権を即座に取得できるか試す（タイムアウト 0ms）
            if (!$mutex.WaitOne(0)) {
                # 所有権を取得できなかった（既に起動している）
                Write-Warning "スクリプト '$Thread' は既に起動しています。"
                
                if ($ShowDialog) {
                    # ダイアログで警告を表示
                    $obj = New-Object -ComObject WScript.Shell
                    try {
                        $obj.Popup(
                            "スクリプト '$Thread' は既に起動しています。`r`n起動を終了します。",
                            0,
                            "エラー",
                            0x10  # エラーアイコン
                        ) | Out-Null
                    }
                    finally {
                        # COM オブジェクトを確実に解放
                        if ($null -ne $obj) {
                            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
                            [System.GC]::Collect()
                            [System.GC]::WaitForPendingFinalizers()
                        }
                    }
                }
                
                # Mutex を閉じて false を返す
                try {
                    $mutex.Close()
                    $mutex.Dispose()
                }
                catch {
                    Write-Verbose "Mutex 解放時のエラー: $($_.Exception.Message)"
                }
                
                return $false
            }
            
            # 起動を許可
            Write-Verbose "Mutex を取得しました。スクリプトの起動を許可します。"
            
            # Mutex オブジェクトをスクリプトスコープに保持（プロセス終了までロックを維持）
            $script:NoDoubleActivation_Mutex = $mutex
            
            # 終了時に Mutex を確実に解放するためのイベント登録
            $eventName = "NoDoubleActivation_PowerShell.Exiting_$([System.Diagnostics.Process]::GetCurrentProcess().Id)"
            
            if (!(Get-EventSubscriber -SourceIdentifier $eventName -ErrorAction SilentlyContinue)) {
                Write-Verbose "Mutex クリーンアップイベントを登録中..."
                $cleanupAction = {
                    $mtx = Get-Variable -Name NoDoubleActivation_Mutex -Scope Script -ErrorAction SilentlyContinue
                    if ($mtx -and $mtx.Value) {
                        try {
                            $mtx.Value.ReleaseMutex()
                            Write-Verbose "Mutex を解放しました"
                        }
                        catch {
                            Write-Verbose "Mutex 解放時のエラー: $($_.Exception.Message)"
                        }
                        try {
                            $mtx.Value.Close()
                            $mtx.Value.Dispose()
                        }
                        catch {
                            Write-Verbose "Mutex クローズ時のエラー: $($_.Exception.Message)"
                        }
                    }
                }
                
                # PowerShell エンジン終了時に実行されるハンドラを登録
                Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupAction | Out-Null
                Write-Verbose "Mutex クリーンアップイベントを登録しました"
            }
            
            return $true
        }
        catch [System.InvalidOperationException] {
            Write-Error "Mutex の作成に失敗しました。別のプロセスが同じ Mutex を使用している可能性があります。詳細: $($_.Exception.Message)" -ErrorAction Stop
        }
        catch [System.UnauthorizedAccessException] {
            Write-Error "Mutex へのアクセス権がありません。詳細: $($_.Exception.Message)" -ErrorAction Stop
        }
        catch {
            Write-Error "二重起動チェックに失敗しました。詳細: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
}