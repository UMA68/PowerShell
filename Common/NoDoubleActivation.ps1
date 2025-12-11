<#
.SYNOPSIS
    スクリプトの二重起動を防止します。

.DESCRIPTION
    Test-NoDoubleActivation 関数は、名前付き Mutex を使用してスクリプトの
    二重起動を防止します。既に同じスレッド名で起動している場合、警告を表示して
    $false を返します。
    
    Mutex はプロセス終了時に自動的に解放されます。
    -ShowDialog スイッチを指定すると、二重起動時にダイアログで警告を表示します。

.PARAMETER Thread
    二重起動チェック用のスレッド名（Mutex名）を指定します。必須パラメーター。
    通常は起動する .ps1 ファイル名（拡張子なし）を指定します。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - Mutex 名として無効な文字（\）を含まない

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

.FUNCTIONALITY
    スクリプトの二重起動防止

.NOTES
    File Name      : NoDoubleActivation.ps1
    Author         : UMA68
    Version        : 1.1.0
    Release Date   : 2025-12-11
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.1.0 (2025-12-11)
        - COM オブジェクトの適切なリソース解放を実装
        - Exit から return $false に変更（呼び出し元に制御を返す）
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - ShowDialog スイッチパラメーターを追加
        - 戻り値を追加（$true/$false）
        - グローバル変数を $script: スコープに変更
        - エラーハンドリングを改善（try-catch 実装）
        - ヘルプドキュメント全体を拡張
        - Write-Verbose によるデバッグ情報追加
        - Mutex 名の妥当性チェック追加
    
    v1.0.0 (2025-12-10)
        - 初版リリース

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    System.Threading.Mutex: https://learn.microsoft.com/en-us/dotnet/api/system.threading.mutex
#>

function Test-NoDoubleActivation {
    [CmdletBinding()]
    [OutputType([bool])]
    param( 
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Thread,                # 二重起動チェック用のスレッド名（Mutex名）
        
        [Parameter(Mandatory=$false)]
        [switch]$ShowDialog = $false    # ダイアログ表示オプション
    )
    
    begin {
        # Mutex 名の妥当性チェック
        if ($Thread -match '\\') { # 無効な文字の検出
            Write-Warning "Mutex 名に無効な文字が含まれています: $Thread"
        }
    }
    
    process {
        try {
            # 二重起動の禁止
            # 初期所有権なしで名前付き Mutex を作成
            $mutexName = $Thread
            $createdRef = [ref]$false
            
            Write-Verbose "Mutex を作成中: $mutexName"
            $script:Mutex = New-Object System.Threading.Mutex($false, $mutexName, $createdRef)

            # 即座に所有権を取得できるか試す（タイムアウト 0ms）
            $hasHandle = $script:Mutex.WaitOne(0, $false)
            
            if (-not $hasHandle) { # 所有権を取得できなかった場合（既に起動している）
                # 既に起動している
                $errorMessage = "スクリプト '$Thread' は既に起動しています。"
                Write-Warning $errorMessage
                
                if ($ShowDialog) { # ダイアログ表示が有効な場合
                    # ダイアログで警告を表示
                    $obj = New-Object -ComObject WScript.Shell
                    try {
                        $obj.Popup(
                            "既に起動しています。`r`n起動を終了します。",
                            0,
                            "エラー",
                            0x10  # エラーアイコン
                        ) | Out-Null
                    }
                    finally {
                        # COM オブジェクトを確実に解放
                        if ($null -ne $obj) { # COMオブジェクトが存在する場合
                            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
                            [System.GC]::Collect()
                            [System.GC]::WaitForPendingFinalizers()
                        }
                    }
                }
                
                # Mutex を閉じて false を返す
                $script:Mutex.Close()
                return $false
            }

            # 起動を許可
            Write-Verbose "Mutex を取得しました。スクリプトの起動を許可します。"
            
            # Mutex オブジェクトをスクリプトスコープに保持（プロセス終了までロックを維持）
            Set-Variable -Name "NoDoubleActivation_Mutex" -Value $script:Mutex -Scope Script -Force

            # 終了時に Mutex を確実に解放するためのイベント登録
            if (-not (Get-Variable -Name NoDoubleActivation_Event -Scope Script -ErrorAction SilentlyContinue)) { # イベントが未登録の場合
                Write-Verbose "Mutex クリーンアップイベントを登録中..."
                $cleanupAction = {
                    $v = Get-Variable -Name NoDoubleActivation_Mutex -Scope Script -ErrorAction SilentlyContinue
                    if ($v -and $v.Value) { # Mutex オブジェクトが存在する場合
                        try { 
                            $v.Value.ReleaseMutex() 
                            Write-Verbose "Mutex を解放しました"
                        } 
                        catch {
                            Write-Verbose "Mutex 解放時のエラー: $($_.Exception.Message)"
                        }
                        try { 
                            $v.Value.Close() 
                        } 
                        catch {
                            Write-Verbose "Mutex クローズ時のエラー: $($_.Exception.Message)"
                        }
                    }
                }

                # PowerShell エンジン終了時に実行されるハンドラを登録
                $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupAction
                Set-Variable -Name "NoDoubleActivation_Event" -Value $true -Scope Script -Force
                Write-Verbose "Mutex クリーンアップイベントを登録しました"
            }
            
            return $true
        }
        catch {
            Write-Error "二重起動チェックに失敗しました。詳細: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
}