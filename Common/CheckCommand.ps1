<#
.SYNOPSIS
    指定したコマンドの存在を確認します。

.DESCRIPTION
    Check-Commann関数は指定したコマンドが存在するか確認します。
    もしコマンドが存在しなければ、OSへ戻ります。
    -ComNameオプションで存在確認の対象コマンド名を指定します。

.EXAMPLE
    Check-Command -ComName "コマンド名"

.EXAMPLE
    Check-Command -ComName "nkf32"

.EXAMPLE
    Check-Command -ComName "nkf32.exe"

.PARAMETER ComName
    存在対象のコマンド名を指定。
    コマンドの拡張子が分かるなら、拡張子を指定しても良い。

.FUNCTIONALITY
    コマンドの存在確認

.NOTES
    File Name      : CheckCommand.ps1
    Author         : UMA
    Prerequisite   : PowerShell
    URL            : 
#>
function Check-Command {
    param (
        # オプション必須
        [Parameter(Mandatory=$true)]
        [string]$ComName = "nkf32"  # 指定無しならnkf32を指定
    )
    process{
        # 指定したコマンドの存在を確認する
        $ChkCommand = Get-Command -Name $ComName -ErrorAction SilentlyContinue
        if ($null -eq $ChkCommand) {
            # 見つからなかった場合はエラーを表示して終了する(パスが通っていない場合もエラーになる)
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($comName+"が見つかりません。`r`nパスが通っていることを確認してください。`r`n`起動を終了します。",0,"警告",0x30) | Out-Null
            exit    # おわり
        }
    }
    
}