<#
.SYNOPSIS
    指定したPowerShellモジュールがインストールされているか確認します。

.DESCRIPTION
    Test-ModuleInstalled 関数は、指定したモジュールがインストールされているかを確認します。
    モジュールが見つかった場合は $true を返し、見つからない場合は $false を返します。
    
    複数バージョンが存在する場合:
    - 最新バージョンを自動選択（バージョン降順ソート）
    - MinimumVersion 指定時は最新版のバージョンを検査
    
    オプションで最小バージョンを指定でき、モジュールバージョンを検査できます。
    -ShowDialog スイッチを指定すると、モジュールが見つからない場合またはバージョン不足時に
    ダイアログボックスで警告を表示します。

.PARAMETER ModuleName
    確認対象のモジュール名を指定します。必須パラメーター。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ワイルドカード文字（* ? [ ]）を含む場合は警告（検出のみ）
    
    複数の同名モジュールがある場合は最新バージョンが選択されます。

.PARAMETER MinimumVersion
    最小バージョンを指定します。指定した場合、モジュールの最新バージョンがこの値以上であることを確認します。
    
    型: [version] - PowerShell バージョン型（例: 0.4.7、22.1.1）
    
    複数バージョン存在時の動作:
    - 検出されたすべてのバージョンから最新版を選択
    - 最新版が MinimumVersion 以上であれば $true を返す
    - 最新版が MinimumVersion 未満であれば $false を返す（バージョン不足）
    
    例: -MinimumVersion "0.4.7"

.PARAMETER ShowDialog
    モジュールが見つからない場合またはバージョン不足時に、ダイアログボックスで警告を表示するかを指定します。
    デフォルト: $false （ダイアログを表示しない）
    
    ダイアログのメッセージ:
    - モジュール未検出: "モジュール '{ModuleName}' が見つかりません。インストールしてください。"
    - バージョン不足: "モジュール '{ModuleName}' のバージョンが不足しています。必要: {MinimumVersion}、現在: {CurrentVersion}"

.EXAMPLE
    # モジュールの存在確認（戻り値を直接利用）
    if (Test-ModuleInstalled -ModuleName "PowerShell-Yaml") {
        Write-Host "PowerShell-Yaml がインストール済みです"
    } else {
        Write-Host "PowerShell-Yaml をインストールしてください"
    }

.EXAMPLE
    # モジュールの最小バージョンを指定
    if (Test-ModuleInstalled -ModuleName "SqlServer" -MinimumVersion "22.1.1") {
        Write-Host "要件を満たす SqlServer がインストール済みです"
    }

.EXAMPLE
    # 複数バージョン存在時の動作確認
    # ModuleName のすべてのバージョンを取得し、最新版が表示される
    Test-ModuleInstalled -ModuleName "Az.Accounts" -Verbose
    # 出力: モジュール 'Az.Accounts' (バージョン: 3.0.0) が見つかりました。

.EXAMPLE
    # モジュールが見つからない場合、ダイアログを表示
    if (!(Test-ModuleInstalled -ModuleName "PowerShell-Yaml" -ShowDialog)) {
        exit 1
    }

.EXAMPLE
    # 結果を変数に格納（最小バージョンチェック付き）
    $result = Test-ModuleInstalled -ModuleName "SqlServer" -MinimumVersion "22.1.1" -ShowDialog
    if (!$result) {
        Write-Host "モジュールが見つかりません。インストールしてください。"
        exit 1
    }

.OUTPUTS
    [bool] 以下の条件に基づいて返却されます:
    
    $true を返す場合:
    - モジュールがインストール済みである
    - MinimumVersion が指定されていない場合
    
    $true を返す場合（バージョン検査付き）:
    - モジュールがインストール済みである
    - 複数バージョン存在時は最新版が選択される
    - 最新版のバージョンが MinimumVersion 以上である
    
    $false を返す場合:
    - モジュールがインストールされていない
    - MinimumVersion が指定されており、最新版のバージョンが要件未満である

.FUNCTIONALITY
    PowerShellモジュールの存在とバージョンを確認

.NOTES
    File Name      : FindModule.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2026-01-14
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.2.0 (2026-01-14)
        - 複数バージョン検出時に最新版を自動選択する仕様をドキュメント記載
        - MinimumVersion のバージョン比較ロジック（-lt）をドキュメント記載
        - MinimumVersion パラメータの型を [version] として明記
        - ShowDialog ダイアログのメッセージを詳細ドキュメント記載
        - $true/$false の詳細な返却条件をドキュメント記載
        - 複数バージョン動作の例を追加
        - バージョン不足時のエラーメッセージ例を追加
        - Get-Module ネイティブフィルター使用を明記
        - COM オブジェクト（WScript.Shell）のリソース解放を明記
    
    v1.1.0 (2025-12-11)
        - COM オブジェクトの適切なリソース解放を実装
        - 戻り値を追加（$true/$false）
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - MinimumVersion パラメーターを追加（バージョン検査機能）
        - ShowDialog スイッチパラメーターを追加
        - Get-Module のネイティブフィルターを使用（性能向上）
        - エラーハンドリングを改善（try-catch実装）
    
    v1.0.0 (2025-12-10)
        - 初版リリース
    
    既知の制限:
    - ワイルドカード文字は警告のみで、パラメーターは受け入れられます
    - 複数バージョン存在時は必ず最新版が選択されます（ユーザー選択不可）
    - COM オブジェクト使用時（-ShowDialog）はマーシャリングコスト増加
    
    パフォーマンス:
    - Get-Module -ListAvailable は初回実行時にモジュール検索でやや遅延あり
    - 複数モジュル確認時はドット記法での複数呼び出しを検討

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