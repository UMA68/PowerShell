<#
.SYNOPSIS
    指定したコマンドの存在を確認します。

.DESCRIPTION
    Test-Command関数は指定したコマンドが存在するか確認します。
    コマンドが見つかった場合は $true を返し、見つからない場合は $false を返します。
    -ComName パラメーターで存在確認の対象コマンド名を指定します。
    
    オプションで -ShowDialog スイッチを指定すると、コマンドが見つからない場合に
    ダイアログボックスで警告を表示します。

.PARAMETER ComName
    存在確認の対象となるコマンド名を指定します。デフォルト: "nkf32"
    拡張子付きの指定も可能です。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ワイルドカード文字（*, ?, [, ]）を含む場合は警告

.PARAMETER ShowDialog
    コマンドが見つからない場合、ダイアログボックスで警告を表示するか指定します。
    デフォルト: $false （ダイアログを表示しない）

.EXAMPLE
    # コマンドの存在確認（結果をコンソールに表示）
    Test-Command -ComName "nkf32"
    if ($?) { Write-Host "nkf32 が見つかりました" }

.EXAMPLE
    # コマンドの存在確認（ダイアログで警告を表示）
    Test-Command -ComName "nkf32" -ShowDialog

.EXAMPLE
    # 結果を変数に格納
    $result = Test-Command -ComName "nkf32.exe"
    if ($result) {
        Write-Host "コマンドが見つかりました"
    } else {
        Write-Host "コマンドが見つかりません"
    }

.OUTPUTS
    [bool] コマンドが見つかった場合は $true、見つからない場合は $false を返します。

.FUNCTIONALITY
    コマンドの存在確認

.NOTES
    File Name      : CheckCommand.ps1
    Author         : UMA68
    Version        : 1.1.0
    Release Date   : 2025-12-11
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.1.0 (2025-12-11)
        - COM オブジェクトの適切なリソース解放を実装
        - 戻り値を追加（$true/$false）して Exit コマンドを削除
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - ShowDialog スイッチパラメーターを追加
        - エラーハンドリングを改善
        - ヘルプドキュメント全体を拡張
        - スコープ変数管理に対応
    
    v1.0.0 (2025-12-10)
        - 初版リリース

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    Get-Command: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-command
#>
function Test-Command {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($_ -match '[\*\?\[\]]') {
                    Write-Warning "コマンド名にワイルドカード文字が含まれています: $_"
                }
                $true
            })]
        [string]$ComName = "nkf32",     # 存在確認対象のコマンド名
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDialog = $false    # ダイアログ表示オプション
    )
    
    process {
        try {
            # 指定したコマンドの存在を確認
            $command = Get-Command -Name $ComName -ErrorAction Stop
            
            Write-Verbose "コマンド '$ComName' が見つかりました。(型: $($command.CommandType), パス: $($command.Source))"
            return $true
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            # コマンドが見つからない場合
            $errorMessage = "コマンド '$ComName' が見つかりません。パスが通っていることを確認してください。"
            
            if ($ShowDialog) {
                # ダイアログで警告を表示
                $obj = New-Object -ComObject WScript.Shell
                try {
                    $obj.Popup(
                        "コマンド '$ComName' が見つかりません。`r`nパスが通っていることを確認してください。",
                        0,
                        "警告",
                        0x30
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
            else {
                # コンソールにエラーを表示
                Write-Error $errorMessage -ErrorAction Continue
            }
            
            return $false
        }
        catch {
            # その他の予期しないエラー
            Write-Error "コマンド確認中に予期しないエラーが発生しました: $($_.Exception.Message)" -ErrorAction Continue
            return $false
        }
    }
}