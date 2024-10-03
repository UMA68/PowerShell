<#
.SYNOPSIS
    スクリプトの二重起動を禁止します。

.DESCRIPTION
    Check-NoDoubleActivation関数はスクリプトがすでに起動しているかどうかを確認します。
    もし起動していれば、OSへ戻ります。
    -Threadオプションで二重起動を禁止するスレッド名(拡張子なしファイル名)を指定します。

.EXAMPLE
    Check-NoDoubleActivation -Thread スレッド名

.EXAMPLE
    Check-NoDoubleActivation -Thread "InstMain"

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
function Check-NoDoubleActivation{
    param( 
        # オプション必須
        [Parameter(Mandatory=$true)]
        [string]$Thread
        )
    Process{
        # 二重起動の禁止
        $mutex = New-Object Threading.Mutex($true, $Thread)
        if (-not $mutex.WaitOne(0, $false)) {
            $Msg = "既に起動しています。起動を終了します。"
            Write-Host $Msg -ForegroundColor Red
            $obj = New-Object -ComObject WScript.Shell
            $obj.popup($_.Exception.Message + $Msg, 0, "エラー", 0x10)  # 0x10:エラーアイコン
                $mutex.Close()
            Exit
        }
    }
}