<#
.SYNOPSIS
    スクリプトの二重起動を禁止します。

.DESCRIPTION
    Test-NoDoubleActivation関数はスクリプトがすでに起動しているかどうかを確認します。
    もし起動していれば、OSへ戻ります。
    -Threadオプションで二重起動を禁止するスレッド名(拡張子なしファイル名)を指定します。

.EXAMPLE
    Test-NoDoubleActivation -Thread スレッド名

.EXAMPLE
    Test-NoDoubleActivation -Thread "InstMain"

.PARAMETER Thread
    チェック対象のスレッド名。
   起動する.ps1のファイル名(拡張子を取り去ったファイル名)を指定すると良い。

.FUNCTIONALITY
    二重起動の禁止

.NOTES
    File Name      : NoDoubleActivation.ps1
    Author         : UMA
    Prerequisite   : PowerShell
    URL            :
#>
function Test-NoDoubleActivation{
    param( 
        # オプション必須
        [Parameter(Mandatory=$true)]
        [string]$Thread
        )
    Process{
        # 二重起動の禁止
        # 変更点:
        # - 初期所有(true)で作成するとこのプロセスが最初に所有者となり
        #   直後の WaitOne は常に true を返してしまうため、別プロセスの検出ができない。
        # - そこでまず所有権を取らずに名前付きミューテックスを作成(open)し、
        #   WaitOne(0) で即時取得を試みる方式に変更する。
        $mutexName = $Thread
        $createdRef = [ref]$false
        # 所有しないで名前付きミューテックスを作成（存在しなければ作成される）
        $mutex = New-Object System.Threading.Mutex($false, $mutexName, $createdRef)

        # すぐに所有権を取得できるか試す（タイムアウト 0）
        $hasHandle = $mutex.WaitOne(0, $false)
        if (-not $hasHandle) {
            $Msg = "既に起動しています。起動を終了します。"
            Write-Host $Msg -ForegroundColor Red
            $obj = New-Object -ComObject WScript.Shell
            $obj.popup($Msg, 0, "エラー", 0x10)  # 0x10:エラーアイコン
            $mutex.Close()
            Exit
        }

        # ミューテックスオブジェクトをグローバルに保持してプロセス終了までロックを維持する
        Set-Variable -Name "NoDoubleActivation_Mutex" -Value $mutex -Scope Global -Force

        # 終了時にミューテックスを確実に解放するためのイベント登録
        if (-not (Get-Variable -Name NoDoubleActivation_Event -Scope Global -ErrorAction SilentlyContinue)) {
            $cleanupAction = {
                $v = Get-Variable -Name NoDoubleActivation_Mutex -Scope Global -ErrorAction SilentlyContinue
                if ($v) {
                    try { $v.Value.ReleaseMutex() } catch {}
                    try { $v.Value.Close() } catch {}
                }
            }

            # PowerShell エンジン終了時に実行されるハンドラを登録
            $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupAction
            Set-Variable -Name "NoDoubleActivation_Event" -Value $true -Scope Global -Force
        }
    }
}