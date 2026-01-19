<#
.SYNOPSIS
    指定したコマンドの存在を確認します。

.DESCRIPTION
    Test-Command 関数は、指定したコマンドが存在するか確認します。
    コマンドが見つかった場合は $true を返し、見つからない場合は $false を返します。
    
    コマンド検索の範囲:
    - Cmdlet（PowerShell コマンドレット）
    - 関数（PowerShell 関数）
    - フィルタ
    - エイリアス
    - 外部スクリプト/実行可能ファイル（PATH 環境変数で検索）
    
    パラメーター検証時に実行される確認:
    - コマンド名が空白でないか確認
    - ワイルドカード文字（* ? [ ]）を含まないか確認（警告のみ）
    
    オプションで -ShowDialog スイッチを指定すると、コマンドが見つからない場合に
    ダイアログボックスで警告を表示します。

.PARAMETER ComName
    存在確認の対象となるコマンド名を指定します。
    パラメータを省略した場合のデフォルト値は "nkf32" です。
    拡張子付きの指定も可能です（例: "nkf32.exe"）。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ワイルドカード文字（* ? [ ]）を含む場合は警告（検出のみ）
    
    実際の使用時は、確認したいコマンド名を明示的に指定することをお勧めします。

.PARAMETER ShowDialog
    コマンドが見つからない場合、ダイアログボックスで警告を表示するかを指定します。
    デフォルト: $false （ダイアログを表示しない）
    
    $false の場合: Write-Error でコンソールにエラーメッセージを出力
    $true の場合: COM オブジェクト（WScript.Shell）でダイアログを表示

.EXAMPLE
    # コマンドの存在確認（戻り値を直接利用）
    if (Test-Command -ComName "powershell") {
        Write-Host "PowerShell コマンドが見つかりました"
    } else {
        Write-Host "PowerShell コマンドが見つかりません"
    }

.EXAMPLE
    # 拡張子付きでコマンドを指定
    if (Test-Command -ComName "nkf32.exe") {
        Write-Host "nkf32.exe が見つかりました"
    }

.EXAMPLE
    # Verbose で詳細情報を表示（コマンド型とパスを表示）
    Test-Command -ComName "Get-Process" -Verbose
    # 出力: コマンド 'Get-Process' が見つかりました。(型: Cmdlet, パス: Microsoft.PowerShell.Management)

.EXAMPLE
    # コマンドが見つからない場合、ダイアログを表示
    if (!(Test-Command -ComName "invalid-command" -ShowDialog)) {
        Write-Host "コマンドが見つかりません"
    }

.EXAMPLE
    # エラーハンドリング付き
    try {
        if (!(Test-Command -ComName "dotnet")) {
            throw "dotnet コマンドが見つかりません。.NET SDK をインストールしてください。"
        }
    }
    catch {
        Write-Error $_
        exit 1
    }

.OUTPUTS
    [bool] 以下の条件に基づいて返却されます:
    
    $true を返す場合:
    - Get-Command がコマンドを検出した
    - コマンドの種類（Cmdlet、Function、External Script など）は不問
    
    $false を返す場合:
    - Get-Command が CommandNotFoundException をスロー（コマンド未検出）
    - その他の予期しないエラーが発生した場合も $false を返す

.FUNCTIONALITY
    コマンドの存在確認

.NOTES
    File Name      : CheckCommand.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2026-01-14
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.2.0 (2026-01-14)
        - ValidateScript により詳細なパラメーター検証を統一実装
        - コマンド検索範囲（Cmdlet、Function、ExternalScript など）をドキュメント記載
        - Get-Command による各種コマンド型検索を明記
        - ワイルドカード文字検出をドキュメント記載
        - CommandNotFoundException 個別処理をドキュメント記載
        - Verbose 出力でコマンド型とパスを表示することを記載
        - Verbose 使用例を追加
        - .NET/外部ツール確認の実例を追加
        - エラーハンドリング例を追加
        - COM オブジェクト（WScript.Shell）の詳細を記載
    
    v1.1.0 (2025-12-11)
        - COM オブジェクトの適切なリソース解放を実装
        - 戻り値を追加（$true/$false）
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - ShowDialog スイッチパラメーターを追加
        - エラーハンドリングを改善（try-catch実装）
    
    v1.0.0 (2025-12-10)
        - 初版リリース
    
    既知の制限:
    - ワイルドカード文字は警告のみで、パラメーターは受け入れられます
    - 外部スクリプト検出は PATH 環境変数に依存します
    - COM オブジェクト使用時（-ShowDialog）はマーシャリングコスト増加
    - 予期しないエラー（アクセス権など）も $false を返すため、詳細はエラーストリームを確認
    
    セキュリティに関する注意:
    - 動的にコマンド名を構築する場合は入力検証を実施してください
    - ワイルドカード文字による予期しない展開に注意してください

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
                $trimmedValue = $_.Trim()
                if ([string]::IsNullOrWhiteSpace($trimmedValue)) {
                    throw "コマンド名が空白のみです。"
                }
                if ($trimmedValue -match '[\*\?\[\]]') {
                    Write-Warning "コマンド名にワイルドカード文字が含まれています: $trimmedValue"
                }
                $true
            })]
        [string]$ComName,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDialog = $false    # ダイアログ表示オプション
    )
    
    process {
        try {
            # 前後の空白を削除
            $trimmedComName = $ComName.Trim()
            
            # 指定したコマンドの存在を確認
            $command = Get-Command -Name $trimmedComName -ErrorAction Stop
            
            Write-Verbose "コマンド '$trimmedComName' が見つかりました。(型: $($command.CommandType), パス: $($command.Source))"
            return $true
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            # コマンドが見つからない場合
            $errorMessage = "コマンド '$trimmedComName' が見つかりません。パスが通っていることを確認してください。"
            
            if ($ShowDialog) {
                # ダイアログで警告を表示
                $obj = New-Object -ComObject WScript.Shell
                try {
                    $obj.Popup(
                        "コマンド '$trimmedComName' が見つかりません。`r`nパスが通っていることを確認してください。",
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