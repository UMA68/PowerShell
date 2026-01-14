<#
.SYNOPSIS
    指定したPowerShellモジュールがインストールされているか確認します。

.DESCRIPTION
    Test-ModuleInstalled関数は指定したモジュールがインストールされているかを確認します。
    モジュールが見つかった場合は $true を返し、見つからない場合は $false を返します。
    
    オプションで最小バージョンを指定でき、モジュールバージョンを検査できます。
    -ShowDialog スイッチを指定すると、モジュールが見つからない場合に
    ダイアログボックスで警告を表示します。

.PARAMETER ModuleName
    確認対象のモジュール名を指定します。必須パラメーター。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ワイルドカード文字（*, ?, [, ]）を含む場合は警告

.PARAMETER MinimumVersion
    最小バージョンを指定します。指定した場合、モジュールバージョンを検査します。
    例: -MinimumVersion "0.4.7"

.PARAMETER ShowDialog
    モジュールが見つからない場合、ダイアログボックスで警告を表示するかを指定します。
    デフォルト: $false （ダイアログを表示しない）

.EXAMPLE
    # モジュールの存在確認（結果をコンソールに表示）
    Test-ModuleInstalled -ModuleName "PowerShell-Yaml"
    if ($?) { Write-Host "モジュールが見つかりました" }

.EXAMPLE
    # モジュールの最小バージョンを指定
    Test-ModuleInstalled -ModuleName "SqlServer" -MinimumVersion "22.1.1"

.EXAMPLE
    # モジュールが見つからない場合、ダイアログを表示
    Test-ModuleInstalled -ModuleName "PowerShell-Yaml" -ShowDialog

.EXAMPLE
    # 結果を変数に格納
    $result = Test-ModuleInstalled -ModuleName "SqlServer" -MinimumVersion "22.1.1"
    if ($result) {
        Write-Host "モジュールが見つかりました"
    } else {
        Write-Host "モジュールが見つかりません。インストールしてください。"
    }

.OUTPUTS
    [bool] モジュールが見つかった場合は $true、見つからない場合は $false を返します。

.FUNCTIONALITY
    PowerShellモジュールの存在とバージョンを確認

.NOTES
    File Name      : FindModule.ps1
    Author         : UMA68
    Version        : 1.1.0
    Release Date   : 2025-12-11
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.1.0 (2025-12-11)
        - COM オブジェクトの適切なリソース解放を実装
        - 戻り値を追加（$true/$false）してダイアログ表示を票分け
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - MinimumVersion パラメーターを追加（バージョン検査機能）
        - ShowDialog スイッチパラメーターを追加
        - Get-Module のネイティブフィルターを使用（性能向上）
        - メッセージを日本語に統一
        - エラーハンドリングを改善（try-catch実装）
        - ヘルプドキュメント全体を拡張
        - スコープ変数管理に対応
    
    v1.0.0 (2025-12-10)
        - 初版リリース

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    Get-Module: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-module
#>

function Test-ModuleInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,            # 確認対象のモジュール名
        
        [Parameter(Mandatory = $false)]
        [version]$MinimumVersion,       # 最小バージョン（オプション）
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDialog = $false    # コマンドが見つからない場合
    )
    
    begin {
        # 入力値の検証
        if ($ModuleName -match '[\*\?\[\]]') { # ワイルドカード文字の検出
            Write-Warning "モジュール名にワイルドカード文字が含まれています: $ModuleName"
        }
    }
    
    process {
        try {
            # 指定したモジュールの存在を確認（ネイティブフィルター使用）
            $modules = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue
            
            if ($null -eq $modules -or $modules.Count -eq 0) {
                throw "モジュール '$ModuleName' がインストールされていません。"
            }
            
            # 複数バージョンがある場合、最新バージョンを取得
            $latestModule = $modules | Sort-Object -Property Version -Descending | Select-Object -First 1
            
            # 最小バージョンを指定した場合、検査
            if ($PSBoundParameters.ContainsKey('MinimumVersion')) {
                if ($latestModule.Version -lt $MinimumVersion) {
                    throw "モジュール '$ModuleName' のバージョンが不足しています。必要バージョン: $MinimumVersion、現在: $($latestModule.Version)"
                }
            }
            
            Write-Verbose "モジュール '$ModuleName' (バージョン: $($latestModule.Version)) が見つかりました。"
            return $true
        }
        catch {
            # モジュールが見つからない場合、またはバージョン不足の場合
            $errorMessage = $_.Exception.Message
            
            if ($ShowDialog) {
                # ダイアログで警告を表示
                $obj = New-Object -ComObject WScript.Shell
                try {
                    $dialogMessage = if ($errorMessage -match 'バージョンが不足') {
                        $errorMessage
                    } else {
                        "モジュール '$ModuleName' が見つかりません。`r`nインストールしてください。"
                    }
                    $obj.Popup($dialogMessage, 0, "警告", 0x30) | Out-Null
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
    }
}