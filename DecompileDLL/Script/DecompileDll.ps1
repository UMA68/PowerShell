[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'UI出力として色付きメッセージが必要')]
<#
.SYNOPSIS
    新旧DLLファイルを逆コンパイルし、差分を比較します。

.DESCRIPTION
    指定されたフォルダ内の新旧DLLファイルをILSpyCmdで逆コンパイルし、
    WinMerge/VS Code等を使用して差分を視覚的に比較するスクリプトです。
    
    ユーザーフレンドリーなUI出力のためWrite-Hostを使用しています。
    色付き出力とキー待機などUIパターンが必要なため、PSAvoidUsingWriteHostルールは除外されています。
    
    主な機能:
    - 複数DLLの一括逆コンパイル（順次または並列処理）
    - 自動リトライ機能（最大3回、タイムアウト制御付き）
    - ETA付き進捗状況表示
    - 詳細なエラーレポートとスキップ理由の記録
    - OS自動判定によるWinMergeパス解決
    - YAML設定による柔軟な設定管理
    - 共通ログ機能による堅牢なログ管理（Write-CommonLog使用）
    - 完全な非対話実行対応（-NoKeyWaitオプション）

.PARAMETER EnvYaml
    使用するYAML設定ファイル名。デフォルトは"Decompile.yaml"。
    YAMLフォルダー内に配置する必要があります。
    
    カスタム設定例:
    - リトライ回数、タイムアウト時間
    - フォルダー名、終了コード
    - 表示色、WinMergeパス

.PARAMETER CleanOutput
    実行前に出力フォルダーの内容をクリアします。
    前回の逆コンパイル結果を削除したい場合に使用します。
    
    注意: -Forceと組み合わせない場合、確認プロンプトが表示されます。

.PARAMETER ShowConfig
    YAML設定ファイルの内容を表示して終了します。
    設定確認用です。実際の処理は実行されません。

.PARAMETER DiffTool
    使用する差分比較ツールを指定します。
    選択肢:
    - WinMerge (デフォルト): WinMergeで比較
    - VSCode: VS Codeで比較
    - Custom: パスのみ表示（手動比較）
    
    注意: 並列処理モードでは自動起動されません。

.PARAMETER Parallel
    複数のDLLを並列で逆コンパイルします。
    
    利点:
    - 処理時間を大幅に短縮（最大でスレッド数倍の高速化）
    
    制限事項:
    - 差分ツールは自動起動しません（手動で比較）
    - CPU負荷が高くなります
    
    推奨: 4個以上のDLLを処理する場合

.PARAMETER ThrottleLimit
    並列処理時の最大スレッド数。デフォルトは4。
    1-10の範囲で指定可能です。
    
    推奨値:
    - 小規模（4-10個）: 4スレッド
    - 大規模（11個以上）: 8スレッド

.PARAMETER Force
    確認プロンプトをスキップして強制的に実行します。
    CleanOutputと組み合わせる場合に便利です。
    
    用途: バッチ処理、自動化スクリプト

.PARAMETER NoKeyWait
    キー入力待機をスキップして、スクリプトが自動終了します。
    タスクスケジューラーや自動化ツールからの実行に適しています。
    
    用途: バッチ処理、スケジューラー実行、CI/CD パイプライン

.PARAMETER WhatIf
    実際には処理を実行せず、実行される内容を表示します。
    事前確認やテスト実行に使用します。

.EXAMPLE
    .\DecompileDll.ps1
    
    デフォルト設定で実行します。
    - 順次処理
    - WinMergeで比較
    - デフォルトYAML設定

.EXAMPLE
    .\DecompileDll.ps1 -Verbose
    
    詳細ログを表示しながら実行します。
    各DLLの処理状況、YAML設定値などが表示されます。

.EXAMPLE
    .\DecompileDll.ps1 -CleanOutput -Force
    
    確認なしで出力フォルダーをクリアして実行します。
    前回の結果を完全に削除してから新しい処理を開始します。

.EXAMPLE
    .\DecompileDll.ps1 -Parallel -ThrottleLimit 8
    
    最大8スレッドで並列処理を実行します。
    多数のDLLを高速に処理したい場合に推奨です。

.EXAMPLE
    .\DecompileDll.ps1 -NoKeyWait -Force
    
    スケジューラー実行用です。確認プロンプトやキー待機をスキップします。
    完全な非対話実行が可能です。
    
    注意: 処理完了後、手動で差分を比較してください。

.EXAMPLE
    .\DecompileDll.ps1 -DiffTool VSCode
    
    VS Codeを使用して差分を表示します。
    VS Codeがインストールされ、PATHに含まれている必要があります。

.EXAMPLE
    .\DecompileDll.ps1 -EnvYaml "CustomConfig.yaml" -ShowConfig
    
    カスタム設定ファイルの内容を表示して終了します。
    設定値の確認に使用します。

.EXAMPLE
    .\DecompileDll.ps1 -WhatIf -Verbose
    
    実際には実行せず、詳細な処理内容を確認します。
    テスト実行や動作確認に便利です。

.EXAMPLE
    .\DecompileDll.ps1 -Parallel -CleanOutput -Force -DiffTool Custom
    
    高度な使用例:
    - 並列処理で高速実行
    - 出力フォルダーを自動クリア
    - 差分は手動で比較

.OUTPUTS
    終了コード:
    0 - Success: 正常終了
    1 - GeneralError: 一般エラー（YAML読込失敗など）
    3 - OSNotSupported: OS非対応（Windows 10/11以外）
    4 - FileNotFound: ファイル/フォルダーが見つからない
    5 - DecompileFailed: 逆コンパイル失敗
    
    出力ファイル:
    ログファイル:       Log\DecompileDll_yyyyMMdd-HHmmss.log
    エラーレポート:     Log\DecompileErrors_yyyyMMdd-HHmmss.txt（エラー発生時のみ）

.NOTES
    File Name      : DecompileDll.ps1
    Version        : 2.1.0
    Author         : UMA
    Prerequisite   : PowerShell 7.x, ILSpyCmd, WinMerge/VS Code, powershell-yaml module
    
    前提条件:
    1. PowerShell 7.x 以降
    2. ILSpyCmdがインストールされていること
       インストール: dotnet tool install ilspycmd -g
    3. WinMerge または VS Code がインストールされていること
    4. powershell-yamlモジュールがインストールされていること
       インストール: Install-Module powershell-yaml -Scope CurrentUser
    5. Dlls\OldとDlls\Newフォルダーに比較対象のDLLが配置されていること
    
    主要機能:
    - 並列処理: 複数DLLを同時に処理して高速化
    - リトライ機能: 失敗時に自動的に最大3回リトライ
    - タイムアウト制御: 大容量DLLにも対応（デフォルト300秒）
    - ETA表示: 予想完了時刻をリアルタイム表示
    - 詳細レポート: エラーとスキップの詳細情報を記録
    - 共通ログ機能: Write-CommonLogを使用し、ファイルロック時のリトライ機能とスレッドセーフなログ出力を実現
    - 完全な非対話実行対応: -NoKeyWaitオプションでスケジューラー・CI/CD統合が可能
    
    パフォーマンス目安:
    - 順次処理: 1個あたり約10秒
    - 並列処理（4スレッド）: 4個を約12秒で処理
    - 並列処理（8スレッド）: 8個を約15秒で処理
    
    変更履歴:
    v2.1.0 (2026-01-26)
        - Write-CommonLogへの移行完了
        - ローカルのWrite-Log関数を削除
        - 並列処理でのログ出力をWrite-CommonLogに統一
        - ファイルロック時のリトライ機能を活用
    
    v2.0.0
        - 初版リリース

.LINK
    https://github.com/UMA68/PowerShell
    
.LINK
    README.md - 詳細なドキュメント
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ # YAMLファイル名の検証
            # ファイル名としての有効性を検証（.yaml または .yml 拡張子必須）
            if ($_ -notmatch '\.(yaml|yml)$') { # 拡張子チェック
                throw "YAMLファイルは .yaml または .yml 拡張子である必要があります: $_"
            }
            if ($_ -match '[\\/:"*?<>|]') { # ファイル名に使用できない文字をチェック
                throw "ファイル名に使用できない文字が含まれています: $_"
            }
            if ([string]::IsNullOrWhiteSpace($_)) { # ファイル名が空白または空文字かどうかをチェック
                throw "ファイル名は空にできません"
            }
            if ($_.Length -gt 255) { # ファイル名長の制限
                throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
            }
            $true
        })]
    [string]$EnvYaml = "Decompile.yaml",    # YAML設定ファイル
    
    [Parameter(Mandatory = $false)]
    [switch]$CleanOutput,                   # 出力フォルダーをクリア
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowConfig,                    # 設定内容表示フラグ
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("WinMerge", "VSCode", "Custom")]
    [string]$DiffTool = "WinMerge",         # 差分ツール
    
    [Parameter(Mandatory = $false)]
    [switch]$Parallel,                      # 並列処理フラグ
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$ThrottleLimit = 4,                # 並列処理時の最大スレッド数
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,                         # 強制実行フラグ（確認プロンプトをスキップ）
    
    [Parameter(Mandatory = $false)]
    [switch]$NoKeyWait                      # キー入力待機をスキップ（スケジューラー実行用）
)

begin {
    #region 定数定義
    # ILSpyCmd引数
    $script:ILSPY_NESTED_DIR = "--nested-directories"
    $script:ILSPY_PROJECT_FLAG = "-p"
    $script:ILSPY_OUTPUT_FLAG = "-o"
    
    # 進捗バー
    $script:PROGRESS_ACTIVITY_SEQUENTIAL = "逆コンパイル中"
    $script:PROGRESS_ACTIVITY_PARALLEL = "逆コンパイル中 (並列)"
    
    # エラーメッセージ
    $script:MSG_NO_OLD_DLL = "古いDLLファイルが見つかりません。`r`n`r`n{0}`r`nにDLLファイルを配置してください。"
    $script:MSG_NO_ILSPYCMD = "「ILSpyCmd.exe」が存在しません。インストールしてください。`r`n`r`n「ILSpyCmdインストール」スクリプトを実行してインストールすることもできます。"
    #endregion
    
    # カスタムログ初期化
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path   # スクリプトの実行パスを取得
    $script:UpperPath = Split-Path -Parent $script:ScriptPath             # スクリプトの親パスを取得  
    $script:LogDir = Join-Path -Path $script:UpperPath -ChildPath "Log"   # ログフォルダーパス
    
    if (-not (Test-Path $script:LogDir)) { # ログフォルダーが存在しない場合は作成
        New-Item -Path $script:LogDir -ItemType Directory -Force | Out-Null
    }
    
    $script:timestamp = Get-Date -Format "yyyyMMdd-HHmmss"                     # タイムスタンプ（グローバルで保持）
    $script:logPath = Join-Path $script:LogDir "DecompileDll_$script:timestamp.log"   # ログファイルパス
    
    # Common フォルダから Write-CommonLog をインポート
    $commonLogPath = Join-Path (Split-Path -Parent (Split-Path -Parent $script:ScriptPath)) "Common\Write-CommonLog.ps1"
    if (-not (Test-Path $commonLogPath)) {
        Show-ErrorPopup "Write-CommonLog.ps1が見つかりません。`r`n`r`n$commonLogPath`r`nを確認してください。"
        exit 1
    }
    . $commonLogPath
    
    # ログ開始
    Write-CommonLog -Message "────────────────────────────────────────" -LogPath $script:logPath -Level "INFO"
    Write-CommonLog -Message "DLL逆コンパイルスクリプトを開始" -LogPath $script:logPath -Level "INFO"
    Write-CommonLog -Message "YAML設定ファイル: $EnvYaml" -LogPath $script:logPath -Level "INFO"
    Write-Host "ログファイル: $script:logPath" -ForegroundColor Cyan
    
    # ShowConfig パラメーターが指定された場合は設定を表示して終了
    if ($ShowConfig) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "         YAML設定内容" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        $config | Format-Custom | Out-Host
        Write-Host "========================================`n" -ForegroundColor Cyan
        Write-CommonLog -Message "ShowConfigオプションにより設定を表示して終了" -LogPath $script:logPath -Level "INFO"
        exit $script:exitSuccess
    }
    
    # 処理時間計測開始
    $script:startTime = Get-Date
    
    # エラー表示用ヘルパー関数
    function Show-ErrorPopup {
        <#
    .SYNOPSIS
        エラーメッセージをポップアップ表示します
    
    .DESCRIPTION
        Windows Script Shellを使用してエラーポップアップを表示します。
        COMオブジェクトはtry-finallyで確実に解放します。
    
    .PARAMETER Message
        表示するエラーメッセージ
    
    .EXAMPLE
        Show-ErrorPopup "エラーが発生しました"
    
    .NOTES
        COMオブジェクトリークを防止するためtry-finallyで管理
    #>

        param([string]$Message)
        $shell = $null
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shell.Popup($Message, 0, "エラー", 0x30) | Out-Null
        } finally {
            if ($shell) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
            }
        }
    }
    
    # リトライ付き逆コンパイル関数
    function Invoke-DecompileWithRetry {
        <#
    .SYNOPSIS
    ${1:Short description}
    
    .DESCRIPTION
    ${2:Long description}
    
    .PARAMETER DllPath
    ${3:Parameter description}
    
    .PARAMETER OutputPath
    ${4:Parameter description}
    
    .PARAMETER DllType
    ${5:Parameter description}
    
    .PARAMETER MaxAttempts
    ${6:Parameter description}
    
    .PARAMETER DelaySeconds
    ${7:Parameter description}
    
    .PARAMETER TimeoutSeconds
    ${8:Parameter description}
    
    .EXAMPLE
    ${9:An example}
    
    .NOTES
    ${10:General notes}
    #>

        param(
            [string]$DllPath,                   # DLLファイルパス
            [string]$OutputPath,                # 出力フォルダー
            [string]$DllType,                   # "Old" or "New"
            [int]$MaxAttempts,                  # 最大試行回数
            [int]$DelaySeconds,                 # リトライ間隔秒数
            [int]$TimeoutSeconds                # タイムアウト秒数
        )
        
        $attempt = 0        # 試行回数
        $success = $false   # 成功フラグ
        $lastError = $null  # 最後のエラーメッセージ
        
        while ($attempt -lt $MaxAttempts -and -not $success) { # リトライループ
            $attempt++  # 試行回数をインクリメント
            
            try {
                $ilspyArgs = @( # ILSpyCmd引数リスト
                    $script:ILSPY_NESTED_DIR                # ネストディレクトリ対応
                    $script:ILSPY_PROJECT_FLAG              # プロジェクトフォルダー
                    $script:ILSPY_OUTPUT_FLAG, $OutputPath  # 出力フォルダー
                    $DllPath
                )
                
                # タイムアウト付きプロセス実行
                $job = Start-Job -ScriptBlock { # ジョブスクリプトブロック
                    param($FilePath, [string[]]$ArgList)
                    $process = Start-Process -FilePath $FilePath `
                        -ArgumentList $ArgList `
                        -NoNewWindow -Wait -PassThru -ErrorAction Stop
                    return $process.ExitCode
                } -ArgumentList "ILSpyCmd", $ilspyArgs  # ジョブ開始
                
                $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds    # ジョブ完了待機
                
                if ($completed) { # 正常終了
                    $exitCode = Receive-Job -Job $job   # 終了コード取得
                    Remove-Job -Job $job -Force         # ジョブ削除
                    
                    if ($exitCode -eq 0) { # 成功した場合
                        $success = $true
                        Write-CommonLog -Message "[$(Split-Path -Leaf $DllPath)] $DllType 逆コンパイル成功 (試行: $attempt/$MaxAttempts)" -LogPath $script:logPath -Level "INFO"
                    } else { # 失敗した場合
                        $lastError = "ILSpyCmd終了コード: $exitCode"
                        if ($attempt -lt $MaxAttempts) { # リトライ可能な場合
                            Write-CommonLog -Message "[$(Split-Path -Leaf $DllPath)] $DllType 失敗 (試行: $attempt/$MaxAttempts) - ${DelaySeconds}秒後にリトライ" -LogPath $script:logPath -Level "WARN"
                            Start-Sleep -Seconds $DelaySeconds
                        }
                    }
                } else { # タイムアウト
                    Remove-Job -Job $job -Force
                    $lastError = "タイムアウト (${TimeoutSeconds}秒)"
                    if ($attempt -lt $MaxAttempts) { # リトライ可能な場合
                        Write-CommonLog -Message "[$(Split-Path -Leaf $DllPath)] $DllType タイムアウト (試行: $attempt/$MaxAttempts) - ${DelaySeconds}秒後にリトライ" -LogPath $script:logPath -Level "WARN"
                        Start-Sleep -Seconds $DelaySeconds
                    }
                }
            } catch {
                $lastError = $_.Exception.Message
                if ($attempt -lt $MaxAttempts) { # リトライ可能な場合
                    Write-CommonLog -Message "[$(Split-Path -Leaf $DllPath)] $DllType 例外 (試行: $attempt/$MaxAttempts): $lastError" -LogPath $script:logPath -Level "WARN"
                    Start-Sleep -Seconds $DelaySeconds
                }
            }
        }
        
        return @{ # 結果ハッシュテーブルを返す
            Success = $success  # true/false
            Attempts = $attempt # 試行回数
            Error = $lastError  # 最後のエラーメッセージ
        }
    }

    # スクリプトの実行環境を取得（既にBeginで初期化済み）
    $script:YamlPath = Join-Path -Path $script:UpperPath -ChildPath "YAML\$EnvYaml"       # YAML設定ファイル

    $oldDllFolder = Join-Path -Path $script:UpperPath -ChildPath "Dlls\Old"        # 古いDLLフォルダー
    $newDllFolder = Join-Path -Path $script:UpperPath -ChildPath "Dlls\New"        # 新しいDLLフォルダー
    $outputFolder = Join-Path -Path $UpperPath -ChildPath "Dlls\Decompiled" # 出力フォルダー
    
    Write-Verbose "スクリプトパス: $scriptPath"
    Write-Verbose "YAML設定ファイル: $YamlPath"
    Write-Verbose "出力フォルダー: $outputFolder"
    
    # powershell-yamlモジュールの確認(終了コードは固定値)
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) { # モジュールが存在しない場合
        Show-ErrorPopup "powershell-yamlモジュールがインストールされていません。`r`n`r`n以下のコマンドを実行してインストールしてください:`r`nInstall-Module powershell-yaml -Scope CurrentUser"
        exit 4  # YAML読み込み前なので固定値
    }
    Import-Module powershell-yaml -ErrorAction Stop

    # YAMLファイルの存在チェック(終了コードは固定値)
    if (-not (Test-Path $YamlPath)) { # YAML設定ファイルが存在しない場合
        Show-ErrorPopup "YAML設定ファイルが見つかりません。`r`n`r`n$YamlPath`r`nを確認してください。"
        exit 4  # YAML読み込み前なので固定値
    }
    
    # YAMLファイルの読み込み
    try {
        $config = Get-Content -Path $YamlPath -Raw -ErrorAction Stop | ConvertFrom-Yaml -Ordered
        Write-Verbose "YAML設定を読み込みました"
        Write-CommonLog -Message "YAML設定を読み込みました: $YamlPath" -LogPath $script:logPath -Level "INFO"
    } catch {
        $errorMsg = "YAMLファイルの読み込みに失敗しました: $($_.Exception.Message)"
        Write-CommonLog -Message $errorMsg -LogPath $script:logPath -Level "ERROR"
        Show-ErrorPopup "YAMLファイルの読み込みに失敗しました。`r`n`r`n$($_.Exception.Message)"
        exit 1
    }
    
    # YAML設定値の取得(デフォルト値あり) - スクリプトスコープで定義
    $script:folderOld = if ($config.Folders.Old) { $config.Folders.Old } else { "old" }
    $script:folderNew = if ($config.Folders.New) { $config.Folders.New } else { "new" }
    $script:win11MinBuild = if ($config.OSDetection.Win11MinBuild) { $config.OSDetection.Win11MinBuild } else { 22000 }
    $script:win10MinBuild = if ($config.OSDetection.Win10MinBuild) { $config.OSDetection.Win10MinBuild } else { 10240 }
    $script:exitSuccess = if ($null -ne $config.ExitCodes.Success) { $config.ExitCodes.Success } else { 0 }
    $script:exitGeneralError = if ($null -ne $config.ExitCodes.GeneralError) { $config.ExitCodes.GeneralError } else { 1 }
    $script:exitOSNotSupported = if ($null -ne $config.ExitCodes.OSNotSupported) { $config.ExitCodes.OSNotSupported } else { 3 }
    $script:exitFileNotFound = if ($null -ne $config.ExitCodes.FileNotFound) { $config.ExitCodes.FileNotFound } else { 4 }
    $script:exitDecompileFailed = if ($null -ne $config.ExitCodes.DecompileFailed) { $config.ExitCodes.DecompileFailed } else { 5 }
    
    # 色設定の読み込み（YAML設定を優先、フォールバックのみ設定）
    $script:colorInfo = if ($config.Colors.Info) { $config.Colors.Info } else { "Cyan" }
    $script:colorSuccess = if ($config.Colors.Success) { $config.Colors.Success } else { "Green" }
    $script:colorWarning = if ($config.Colors.Warning) { $config.Colors.Warning } else { "Yellow" }
    $script:colorError = if ($config.Colors.Error) { $config.Colors.Error } else { "Red" }
    
    # リトライ設定の読み込み（デフォルト値あり）
    $script:retryMaxAttempts = if ($config.Retry.MaxAttempts) { $config.Retry.MaxAttempts } else { 3 }
    $script:retryDelaySeconds = if ($config.Retry.DelaySeconds) { $config.Retry.DelaySeconds } else { 2 }
    $script:retryTimeoutSeconds = if ($config.Retry.TimeoutSeconds) { $config.Retry.TimeoutSeconds } else { 300 }
    
    Write-Verbose "YAML設定値を読み込みました: Folders(Old=$script:folderOld, New=$script:folderNew), Colors(Info=$script:colorInfo, Success=$script:colorSuccess)"
    Write-Verbose "リトライ設定: MaxAttempts=$script:retryMaxAttempts, Delay=$script:retryDelaySeconds秒, Timeout=$script:retryTimeoutSeconds秒"
    
    # YAML構造の検証
    if (-not $config.InstWinMerge) { # InstWinMergeセクションがない場合
        Show-ErrorPopup "YAMLに'InstWinMerge'セクションがありません。`r`n設定ファイルを確認してください。"
        exit $script:exitGeneralError
    }

    # OSバージョンの判定（BuildNumberベース - ローカライズに依存しない）
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $osBuild = [int]$osInfo.BuildNumber
    
    Write-Verbose "OS: $($osInfo.Caption) (Build: $osBuild)"
    
    if ($osBuild -ge $win11MinBuild) { # Windows 11 (YAML設定のビルド番号以降)
        # Windows 11 (YAML設定のビルド番号以降)
        $winMergePath = $config.InstWinMerge.Win11 -replace '\$HOME', $HOME
        Write-Verbose "Windows 11を検出しました (Build: $osBuild >= $win11MinBuild)"
    } elseif ($osBuild -ge $win10MinBuild) { # Windows 10 (YAML設定のビルド番号以降)
        # Windows 10 (YAML設定のビルド番号以降)
        $winMergePath = $config.InstWinMerge.Win10
        Write-Verbose "Windows 10を検出しました (Build: $osBuild >= $win10MinBuild)"
    } else { # 対応OS以外
        Show-ErrorPopup "このスクリプトはWindows 10またはWindows 11でのみ動作します。`r`n現在のビルド: $osBuild (Win10最小: $win10MinBuild)`r`n異なるバージョンで使用する場合はYAMLのOSDetection設定を調整してください。"
        exit $script:exitOSNotSupported
    }
    
    Write-Verbose "WinMergeパス: $winMergePath"

    # ILSpyCmd(逆コンパイルコマンド)の存在チェック
    $ilspyCmd = Get-Command "ILSpyCmd" -ErrorAction SilentlyContinue
    if (-not $ilspyCmd) { # ILSpyCmdが見つからない場合
        Show-ErrorPopup $script:MSG_NO_ILSPYCMD
        exit $script:exitFileNotFound
    }
    Write-Verbose "ILSpyCmd場所: $($ilspyCmd.Source)"
    
    # 必要なフォルダーの存在確認
    if (-not (Test-Path $oldDllFolder)) { # Oldフォルダーが存在しない場合
        Show-ErrorPopup "Oldフォルダーが存在しません。`r`n`r`n$oldDllFolder`r`nを作成してDLLファイルを配置してください。"
        exit $script:exitFileNotFound
    }
    
    if (-not (Test-Path $newDllFolder)) { # Newフォルダーが存在しない場合
        Show-ErrorPopup "Newフォルダーが存在しません。`r`n`r`n$newDllFolder`r`nを作成してDLLファイルを配置してください。"
        exit $script:exitFileNotFound
    }
    
    # 出力フォルダーの作成(存在しない場合)
    if (-not (Test-Path $outputFolder)) { # 出力フォルダーが存在しない場合
        try {
            New-Item -Path $outputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "出力フォルダーを作成しました: $outputFolder"
        } catch {
            Show-ErrorPopup "出力フォルダーの作成に失敗しました。`r`n`r`n$($_.Exception.Message)"
            exit $script:exitGeneralError
        }
    }
    
    # CleanOutput オプション: 出力フォルダーのクリーンアップ
    if ($CleanOutput) { # 出力フォルダーのクリア
        Write-Verbose "出力フォルダーのクリアを実行します。"
        $oldOutputPath = Join-Path $outputFolder $folderOld
        $newOutputPath = Join-Path $outputFolder $folderNew
        
        $shouldClean = $Force -or $PSCmdlet.ShouldProcess("$oldOutputPath, $newOutputPath", "出力フォルダーのクリア")
        
        if ($shouldClean) { # クリア実行
            if (Test-Path $oldOutputPath) { # 古いDLL出力フォルダーのクリア
                try {
                    Remove-Item -Path $oldOutputPath -Recurse -Force -ErrorAction Stop
                    Write-Host "出力フォルダー($folderOld)をクリアしました: $oldOutputPath" -ForegroundColor Green
                } catch {
                    Write-Warning "出力フォルダー($folderOld)のクリアに失敗しました: $($_.Exception.Message)"
                }
            }
            
            if (Test-Path $newOutputPath) { # 新しいDLL出力フォルダーのクリア
                try {
                    Remove-Item -Path $newOutputPath -Recurse -Force -ErrorAction Stop
                    Write-Host "出力フォルダー($folderNew)をクリアしました: $newOutputPath" -ForegroundColor Green
                } catch {
                    Write-Warning "出力フォルダー($folderNew)のクリアに失敗しました: $($_.Exception.Message)"
                }
            }
        }
    }
}
process {
    # 一括逆コンパイル
    Write-Verbose "古いDLLフォルダーをスキャン: $oldDllFolder"
    $oldDlls = Get-ChildItem $oldDllFolder -Filter *.dll -ErrorAction SilentlyContinue
    
    if (-not $oldDlls) { # DLLファイルが存在しない場合
        Show-ErrorPopup ($script:MSG_NO_OLD_DLL -f $oldDllFolder)
        exit $script:exitFileNotFound
    }
    
    $totalCount = $oldDlls.Count    # 総DLLファイル数
    $successCount = 0               # 成功カウント
    $failCount = 0                  # 失敗カウント
    $skipCount = 0                  # スキップカウント
    $script:errorList = @()         # エラー詳細のリスト
    $script:skipReasons = @()       # スキップ理由のリスト
    
    # 完了予定時刻（ETA）計算用
    $processStartTime = Get-Date
    
    Write-Host "逆コンパイル対象: $totalCount 個のDLLファイル" -ForegroundColor Cyan
    if ($Parallel) { # 並列処理モード
        Write-Host "並列処理モード: 最大 $ThrottleLimit スレッド" -ForegroundColor Cyan
        Write-CommonLog -Message "逆コンパイル開始: $totalCount 個のDLLファイル (並列処理: $ThrottleLimit スレッド)" -LogPath $script:logPath -Level "INFO"
    } else { # 順次処理モード
        Write-CommonLog -Message "逆コンパイル開始: $totalCount 個のDLLファイル (順次処理)" -LogPath $script:logPath -Level "INFO"
    }
    
    # 並列処理用の同期変数
    $syncHash = [hashtable]::Synchronized(@{ # 同期ハッシュテーブル
            TotalCount = $totalCount    # 総ファイル数
            SuccessCount = 0            # 成功カウント
            FailCount = 0               # 失敗カウント
            SkipCount = 0               # スキップカウント
            ErrorList = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())     # エラー詳細リスト
            SkipReasons = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())   # スキップ理由リスト
            CurrentCount = 0                # 現在の処理数
            LogPath = $script:logPath       # ログパス
            StartTime = $processStartTime   # 開始時間
        })
    
    # 並列処理または順次処理
    if ($Parallel) { # 並列処理
        # 並列処理
        $oldDlls | ForEach-Object -Parallel { # 並列スクリプトブロック
            $oldDll = $_                                                # 現在のDLLファイル
            $baseName = $oldDll.BaseName                                # DLLのベース名取得 (拡張子なし)
            
            # 親スコープの変数をインポート
            $newDllFolder = $using:newDllFolder                         # 新しいDLLフォルダー
            $outputFolder = $using:outputFolder                         # 出力フォルダー
            $folderOld = $using:script:folderOld                        # 古いDLLフォルダー名
            $folderNew = $using:script:folderNew                        # 新しいDLLフォルダー名
            $syncHash = $using:syncHash                                 # 同期ハッシュテーブル
            $totalCount = $using:totalCount                             # 総ファイル数
            $WhatIfPreference = $using:WhatIfPreference                 # WhatIf設定
            $retryMaxAttempts = $using:script:retryMaxAttempts          # リトライ最大試行回数
            $retryDelaySeconds = $using:script:retryDelaySeconds        # リトライ間隔（秒）
            $retryTimeoutSeconds = $using:script:retryTimeoutSeconds    # タイムアウト（秒）
            
            # ログヘルパー関数（スレッドセーフなログ出力）
            function Write-ThreadSafeLog {
                param([string]$Message, [string]$Level = "INFO")
                $logPath = $syncHash.LogPath
                # Write-CommonLogのロジックをこのスコープ内で直接実装
                # ファイルロック時のリトライはWrite-CommonLogと同じ手法で実装
                $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $logMessage = "$timeStamp [$Level] - $Message"
                $retryCount = 0
                $maxRetry = 3
                while ($retryCount -lt $maxRetry) {
                    try {
                        Add-Content -Path $logPath -Value $logMessage -Encoding UTF8 -ErrorAction Stop
                        break
                    } catch {
                        $retryCount++
                        if ($retryCount -lt $maxRetry) {
                            Start-Sleep -Milliseconds 100
                        } else {
                            # リトライ失敗時は無視（並列処理のため過度なエラー処理は避ける）
                            break
                        }
                    }
                }
            }
            
            # リトライ付き逆コンパイル関数（並列処理用）
            function Invoke-DecompileWithRetryParallel {
                <#
            .SYNOPSIS
            ${1:Short description}
            
            .DESCRIPTION
            ${2:Long description}
            
            .PARAMETER DllPath
            ${3:Parameter description}
            
            .PARAMETER OutputPath
            ${4:Parameter description}
            
            .PARAMETER DllType
            ${5:Parameter description}
            
            .PARAMETER MaxAttempts
            ${6:Parameter description}
            
            .PARAMETER DelaySeconds
            ${7:Parameter description}
            
            .PARAMETER TimeoutSeconds
            ${8:Parameter description}
            
            .EXAMPLE
            ${9:An example}
            
            .NOTES
            ${10:General notes}
            #>

                param(
                    [string]$DllPath,       # DLLパス
                    [string]$OutputPath,    # 出力パス
                    [string]$DllType,       # "Old" or "New"
                    [int]$MaxAttempts,      # 最大試行回数
                    [int]$DelaySeconds,     # リトライ間隔（秒）
                    [int]$TimeoutSeconds    # タイムアウト（秒）
                )
                
                $attempt = 0        # 試行回数
                $success = $false   # 成功フラグ
                $lastError = $null  # 最終エラーメッセージ
                
                while ($attempt -lt $MaxAttempts -and -not $success) { # リトライループ
                    $attempt++
                    
                    try {
                        $ilspyArgs = @( # ILSpyCmd引数リスト
                            $using:script:ILSPY_NESTED_DIR                  # ILSpyネストディレクトリ
                            $using:script:ILSPY_PROJECT_FLAG                # ILSpyプロジェクトフラグ
                            $using:script:ILSPY_OUTPUT_FLAG, $OutputPath    # 出力パス
                            $DllPath                                        # DLLパス        
                        )
                        
                        # タイムアウト付きプロセス実行
                        $job = Start-Job -ScriptBlock { # ジョブスクリプトブロック
                            param($FilePath, [string[]]$ArgList)
                            $process = Start-Process -FilePath $FilePath `
                                -ArgumentList $ArgList `
                                -NoNewWindow -Wait -PassThru -ErrorAction Stop
                            return $process.ExitCode
                        } -ArgumentList "ILSpyCmd", $ilspyArgs # 引数渡し
                        
                        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
                        
                        if ($completed) { # ジョブ完了
                            $exitCode = Receive-Job -Job $job
                            Remove-Job -Job $job -Force
                            
                            if ($exitCode -eq 0) { # 成功
                                $success = $true
                            } else { # 失敗
                                $lastError = "ILSpyCmd終了コード: $exitCode"
                                if ($attempt -lt $MaxAttempts) { # リトライ可能
                                    Write-ThreadSafeLog "[$(Split-Path -Leaf $DllPath)] $DllType 失敗 (試行: $attempt/$MaxAttempts) - ${DelaySeconds}秒後にリトライ" "WARN"
                                    Start-Sleep -Seconds $DelaySeconds
                                }
                            }
                        } else { # タイムアウト
                            # タイムアウト
                            Remove-Job -Job $job -Force
                            $lastError = "タイムアウト (${TimeoutSeconds}秒)"
                            if ($attempt -lt $MaxAttempts) { # リトライ可能
                                Write-ThreadSafeLog "[$(Split-Path -Leaf $DllPath)] $DllType タイムアウト (試行: $attempt/$MaxAttempts) - ${DelaySeconds}秒後にリトライ" "WARN"
                                Start-Sleep -Seconds $DelaySeconds
                            }
                        }
                    } catch {
                        $lastError = $_.Exception.Message
                        if ($attempt -lt $MaxAttempts) { # リトライ可能
                            Write-ThreadSafeLog "[$(Split-Path -Leaf $DllPath)] $DllType 例外 (試行: $attempt/$MaxAttempts): $lastError" "WARN"
                            Start-Sleep -Seconds $DelaySeconds
                        }
                    }
                }
                
                return @{ # 結果ハッシュテーブルを返す
                    Success = $success  # 成功フラグ
                    Attempts = $attempt # 試行回数
                    Error = $lastError  # 最終エラーメッセージ
                }
            }
            
            # 新しいDLLを検索
            $newDll = Get-ChildItem $newDllFolder -Filter "$baseName.dll" -ErrorAction SilentlyContinue
            
            if (-not $newDll) { # 完全一致が見つからない場合
                # 部分一致で最新のDLLを取得
                $newDll = Get-ChildItem $newDllFolder -Filter "$baseName*.dll" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime | Select-Object -Last 1
                    if ($newDll) { # 部分一致が見つかった場合
                        Write-Warning "完全一致なし。'$($newDll.Name)'を使用します（最新）"
                    }
            }
            
                # 進捗更新
                $syncHash.CurrentCount = [System.Threading.Interlocked]::Increment([ref]$syncHash.CurrentCount)  # 現在の処理数をインクリメント
                $currentCount = $syncHash.CurrentCount
                $progress = [Math]::Round(($currentCount / $totalCount) * 100, 2)                       # 進捗率計算
                Write-Progress -Activity $using:script:PROGRESS_ACTIVITY_PARALLEL -Status "$baseName ($currentCount/$totalCount)" -PercentComplete $progress -Id $oldDll.GetHashCode()  # 進捗バー更新

                # 逆コンパイル
                if ($newDll) { # 新しいDLLが見つかった場合
                    if (-not $WhatIfPreference) { # WhatIfモードでない場合
                        # 古いDLLの逆コンパイル（リトライあり）
                        $oldOutput = Join-Path $outputFolder "$folderOld\$baseName"
                        $oldResult = Invoke-DecompileWithRetryParallel -DllPath $oldDll.FullName `
                            -OutputPath $oldOutput `
                            -DllType "Old" `
                            -MaxAttempts $retryMaxAttempts `
                            -DelaySeconds $retryDelaySeconds `
                            -TimeoutSeconds $retryTimeoutSeconds
                    
                        if (-not $oldResult.Success) { # 古いDLLの逆コンパイル失敗
                            $syncHash.FailCount = [System.Threading.Interlocked]::Increment([ref]$syncHash.FailCount)
                            Write-ThreadSafeLog "[$($oldDll.Name)] Old逆コンパイル最終失敗: $($oldResult.Error) (試行回数: $($oldResult.Attempts))" "ERROR"
                            $syncHash.ErrorList.Add([PSCustomObject]@{ # エラー詳細を追加
                                    DllName = $oldDll.Name                  # DLL名
                                    Type = "Old"                            # エラータイプ
                                    Error = "$($oldResult.Error) (試行: $($oldResult.Attempts)回)"  # エラーメッセージと試行回数
                                }) | Out-Null
                        }
                    
                        # 新しいDLLの逆コンパイル（リトライあり）
                        $newOutput = Join-Path $outputFolder "$folderNew\$baseName"
                        $newResult = Invoke-DecompileWithRetryParallel -DllPath $newDll.FullName `
                            -OutputPath $newOutput `
                            -DllType "New" `
                            -MaxAttempts $retryMaxAttempts `
                            -DelaySeconds $retryDelaySeconds `
                            -TimeoutSeconds $retryTimeoutSeconds
                    
                        if (-not $newResult.Success) { # 新しいDLLの逆コンパイル失敗
                            $syncHash.FailCount = [System.Threading.Interlocked]::Increment([ref]$syncHash.FailCount) # 失敗カウント増加
                            Write-ThreadSafeLog "[$($newDll.Name)] New逆コンパイル最終失敗: $($newResult.Error) (試行回数: $($newResult.Attempts))" "ERROR" # エラーログ出力
                            $syncHash.ErrorList.Add([PSCustomObject]@{ # エラー詳細を追加
                                    DllName = $newDll.Name                # DLL名
                                    Type = "New"                          # エラータイプ
                                    Error = "$($newResult.Error) (試行: $($newResult.Attempts)回)"  # エラーメッセージと試行回数
                                }) | Out-Null
                        }
                    
                        # 両方成功した場合のみ成功カウント
                        if ($oldResult.Success -and $newResult.Success) { # 両方成功
                            $syncHash.SuccessCount = [System.Threading.Interlocked]::Increment([ref]$syncHash.SuccessCount)  # 成功カウント増加
                            Write-ThreadSafeLog "[$($oldDll.Name)] 逆コンパイル成功 (Old: $($oldResult.Attempts)回, New: $($newResult.Attempts)回)" "SUCCESS"   # 成功ログ出力
                        }
                    }
                } else { # 新しいDLLが見つからない場合
                    $syncHash.SkipCount = [System.Threading.Interlocked]::Increment([ref]$syncHash.SkipCount)  # スキップカウント増加
                    $skipReason = if (-not $newDll) { "対応する新しいDLLが見つかりません" } else { "WhatIfモードのためスキップ" }   # スキップ理由設定
                    Write-ThreadSafeLog "[$($oldDll.Name)] スキップ: $skipReason" "WARNING" # スキップログ出力
                    $syncHash.SkipReasons.Add([PSCustomObject]@{ # スキップ理由リストに追加
                            DllName = $oldDll.Name  # DLL名
                            Reason = $skipReason    # スキップ理由
                        }) | Out-Null
                }
            } -ThrottleLimit $ThrottleLimit # スレッド数制限
        
            # 並列処理結果を集計
            $successCount = $syncHash.SuccessCount      # 成功カウント
            $failCount = $syncHash.FailCount            # 失敗カウント
            $skipCount = $syncHash.SkipCount            # スキップカウント
            $script:errorList = $syncHash.ErrorList     # エラー詳細リスト
            $script:skipReasons = $syncHash.SkipReasons # スキップ理由リスト
        
    } else { # 順次処理
        # 順次処理（既存のコード）
        $currentCount = 0
        foreach ($oldDll in $oldDlls) { # 古い各DLLファイルを処理
            $baseName = $oldDll.BaseName                            # DLLのベース名取得 (拡張子なし)
            $newDll = Get-ChildItem $newDllFolder -Filter "$baseName.dll" -ErrorAction SilentlyContinue  # 新しいDLLを完全一致で検索
        
            if (-not $newDll) { # 完全一致が見つからない場合
                # 部分一致で最新のDLLを取得
                $newDll = Get-ChildItem $newDllFolder -Filter "$baseName*.dll" -ErrorAction SilentlyContinue | 
                    Select-Object -Last 1
            if ($newDll) { # 部分一致が見つかった場合
                Write-Warning "完全一致なし。'$($newDll.Name)'を使用します（最新）"
            }
        }

        $currentCount++
        $progress = [Math]::Round(($currentCount / $totalCount) * 100, 2)   # 進捗率計算
        
        # 完了予定時刻（ETA）の計算
        $elapsed = (Get-Date) - $processStartTime   # 経過時間計算
        if ($currentCount -gt 1) { # 2つ以上処理済みの場合に完了予定(ETA)計算
            $avgTimePerItem = $elapsed.TotalSeconds / ($currentCount - 1)   # 平均処理時間計算
            $remainingItems = $totalCount - $currentCount                   # 残りアイテム数計算  
            $etaSeconds = [Math]::Round($avgTimePerItem * $remainingItems)  # 完了予定(ETA)秒数計算
            $etaTimeSpan = [TimeSpan]::FromSeconds($etaSeconds)             # TimeSpanオブジェクト作成
            $etaDisplay = "完了予定(ETA): {0:hh\:mm\:ss}" -f $etaTimeSpan   # 完了予定(ETA)表示文字列作成
        } else { # 1つ目のアイテム処理中は計算不可
            $etaDisplay = "完了予定(ETA): 計算中..."
        }
        
        # 進捗バー更新
        Write-Progress -Activity $script:PROGRESS_ACTIVITY_SEQUENTIAL `
            -Status "$baseName ($currentCount/$totalCount) - $etaDisplay" `
            -PercentComplete $progress `
            -SecondsRemaining $(if ($currentCount -gt 1) { $etaSeconds } else { -1 })
        
        Write-Verbose "処理中: $baseName"                 # 処理中DLL表示   

        if ($newDll -and $PSCmdlet.ShouldProcess("$($oldDll.Name) と $($newDll.Name)", "逆コンパイル")) { # 新しいDLLが見つかり、WhatIfモードでない場合
            # 古いDLLの逆コンパイル（リトライあり）
            $oldOutput = Join-Path $outputFolder "$script:folderOld\$baseName"      # 古いDLLの出力パス
            
            $oldResult = Invoke-DecompileWithRetry -DllPath $oldDll.FullName `
                -OutputPath $oldOutput `
                -DllType "Old" `
                -MaxAttempts $script:retryMaxAttempts `
                -DelaySeconds $script:retryDelaySeconds `
                -TimeoutSeconds $script:retryTimeoutSeconds  
            
            if (-not $oldResult.Success) { # 古いDLLの逆コンパイル失敗
                $failCount++
                Write-Warning "[$($oldDll.Name)] Old逆コンパイル最終失敗: $($oldResult.Error) (試行回数: $($oldResult.Attempts))"
                Write-CommonLog -Message "[$($oldDll.Name)] Old逆コンパイル最終失敗: $($oldResult.Error) (試行: $($oldResult.Attempts)回)" -LogPath $script:logPath -Level "ERROR"
                $script:errorList += [PSCustomObject]@{ # エラーリストに追加
                    DllName = $oldDll.Name  # DLL名
                    Type = "Old"            # エラータイプ
                    Error = "$($oldResult.Error) (試行: $($oldResult.Attempts)回)"  # エラーメッセージ  
                }
            } else { # 古いDLLの逆コンパイル成功
                Write-Verbose "✓ $($oldDll.Name) (Old) 逆コンパイル成功 (試行: $($oldResult.Attempts)回)"
            }
            
            # 新しいDLLの逆コンパイル（リトライあり）
            $newOutput = Join-Path $outputFolder "$script:folderNew\$baseName"    # 新しいDLLの出力パス
            
            $newResult = Invoke-DecompileWithRetry -DllPath $newDll.FullName `
                -OutputPath $newOutput `
                -DllType "New" `
                -MaxAttempts $script:retryMaxAttempts `
                -DelaySeconds $script:retryDelaySeconds `
                -TimeoutSeconds $script:retryTimeoutSeconds  
            
            if (-not $newResult.Success) { # 新しいDLLの逆コンパイル失敗
                $failCount++
                Write-Warning "[$($newDll.Name)] New逆コンパイル最終失敗: $($newResult.Error) (試行回数: $($newResult.Attempts))"
                Write-CommonLog -Message "[$($newDll.Name)] New逆コンパイル最終失敗: $($newResult.Error) (試行: $($newResult.Attempts)回)" -LogPath $script:logPath -Level "ERROR"
                $script:errorList += [PSCustomObject]@{ # エラーリストに追加
                    DllName = $newDll.Name  # DLL名
                    Type = "New"            # エラータイプ
                    Error = "$($newResult.Error) (試行: $($newResult.Attempts)回)"  # エラーメッセージ
                }
            } else { # 新しいDLLの逆コンパイル成功
                Write-Verbose "✓ $($newDll.Name) (New) 逆コンパイル成功 (試行: $($newResult.Attempts)回)"
            }
            
            # 両方成功した場合のみ成功カウント
            if ($oldResult.Success -and $newResult.Success) { # 両方の逆コンパイル成功
                $successCount++
                Write-CommonLog -Message "[$($oldDll.Name)] 逆コンパイル成功 (Old: $($oldResult.Attempts)回, New: $($newResult.Attempts)回)" -LogPath $script:logPath -Level "INFO"
            }
        } else { # 新しいDLLが見つからない、またはWhatIfモードの場合
            # スキップ理由を記録
            $skipReason = if (-not $newDll) { # 新しいDLLが見つからない場合
                "対応する新しいDLLが見つかりません"
            } else { # WhatIfモードの場合
                "WhatIfモードのためスキップ"
            }
            Write-Warning "'$($oldDll.Name)' をスキップ: $skipReason"
            Write-CommonLog -Message "[$($oldDll.Name)] スキップ: $skipReason" -LogPath $script:logPath -Level "WARN"
            $script:skipReasons += [PSCustomObject]@{ # スキップ理由リストに追加
                DllName = $oldDll.Name  # DLL名
                Reason = $skipReason    # スキップ理由
            }
            $skipCount++
        }
    }
    $script:errorList = $script:errorList   # エラー詳細リスト
    }
}
end {
    Write-Progress -Activity $script:PROGRESS_ACTIVITY_SEQUENTIAL -Completed
    
    # 処理統計の表示
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "           処理サマリー" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "処理DLL数:      $totalCount" -ForegroundColor Cyan
    Write-Host "成功:           $successCount" -ForegroundColor Green
    Write-Host "失敗:           $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Cyan' })
    Write-Host "スキップ:       $skipCount" -ForegroundColor $(if ($skipCount -gt 0) { 'Yellow' } else { 'Cyan' })
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # 処理統計をログに記録
    Write-CommonLog -Message "──────── 処理結果 ────────" -LogPath $script:logPath -Level "INFO"
    Write-CommonLog -Message "処理DLL数: $totalCount" -LogPath $script:logPath -Level "INFO"
    Write-CommonLog -Message "成功: $successCount" -LogPath $script:logPath -Level "INFO"
    if ($failCount -gt 0) { # 失敗がある場合
        Write-CommonLog -Message "失敗: $failCount" -LogPath $script:logPath -Level "ERROR"
    } else { # 失敗がない場合
        Write-CommonLog -Message "失敗: $failCount" -LogPath $script:logPath -Level "INFO"
    }
    if ($skipCount -gt 0) { # スキップがある場合
        Write-CommonLog -Message "スキップ: $skipCount" -LogPath $script:logPath -Level "WARN"
    } else { # スキップがない場合
        Write-CommonLog -Message "スキップ: $skipCount" -LogPath $script:logPath -Level "INFO"
    }
    
    # エラーレポートの表示(エラーがある場合)
    if ($script:errorList.Count -gt 0) { # エラーがある場合
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "         エラー詳細" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        foreach ($errorItem in $errorList) { # エラー詳細の表示
            Write-Host "DLL: $($errorItem.DllName) [$($errorItem.Type)]" -ForegroundColor Red
            Write-Host "  エラー: $($errorItem.Error)" -ForegroundColor Red
        }
        Write-Host "========================================`n" -ForegroundColor Red
        
        # エラーレポートをファイルに保存
        $errorReportPath = Join-Path $script:LogDir "DecompileErrors_$script:timestamp.txt"
        $script:errorList | Format-Table -AutoSize | Out-File -FilePath $errorReportPath -Encoding UTF8
        Write-Host "エラーレポートを保存しました: $errorReportPath" -ForegroundColor Green
        Write-Host "" -ForegroundColor Green
    }
    
    # スキップレポートの表示(スキップがある場合)
    if ($script:skipReasons.Count -gt 0) { # スキップがある場合
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "       スキップ詳細" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        foreach ($skipItem in $script:skipReasons) { # スキップ詳細の表示
            Write-Host "DLL: $($skipItem.DllName)" -ForegroundColor Yellow  # スキップDLL名
            Write-Host "  理由: $($skipItem.Reason)" -ForegroundColor Yellow  # スキップ理由
        }
        Write-Host "========================================`n" -ForegroundColor Yellow
    }
    
    # 処理時間の計算と表示
    $endTime = Get-Date
    $elapsedTime = $endTime - $script:startTime # 経過時間計算
    Write-Host "処理時間: $($elapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host ""
    Write-CommonLog -Message "処理時間: $($elapsedTime.ToString('hh\:mm\:ss'))" -LogPath $script:logPath -Level "INFO"
    
    # WinMergeの実行準備
    $oldFile = Join-Path $outputFolder $script:folderOld
    $newFile = Join-Path $outputFolder $script:folderNew
    
    Write-Verbose "比較元: $oldFile"
    Write-Verbose "比較先: $newFile"
    
    # 並列処理の場合は差分ツールを自動起動しない（複数の比較が発生するため）
    if ($Parallel) { # 並列処理モードの場合
        Write-Host "`n並列処理モードのため、差分ツールは自動起動しません。" -ForegroundColor Yellow
        Write-Host "手動で以下のパスを比較してください:" -ForegroundColor Yellow
        Write-Host "Old: $oldFile" -ForegroundColor Cyan
        Write-Host "New: $newFile" -ForegroundColor Cyan
        Write-CommonLog -Message "並列処理完了 - 差分ツール手動起動が必要" -LogPath $script:logPath -Level "INFO"
        exit $script:exitSuccess
    }
    
    # 差分ツールの選択と起動（順次処理のみ）
    if ($DiffTool -eq "VSCode") { # VSCodeモードの場合
        Write-Host "`nVSCodeを起動しています..." -ForegroundColor Cyan
        Write-CommonLog -Message "VSCodeで差分比較を起動" -LogPath $script:logPath -Level "INFO"
        if ($PSCmdlet.ShouldProcess("VSCode", "差分比較起動")) { # VSCode起動
            try {
                Start-Process -FilePath "code" -ArgumentList "--diff", "`"$oldFile`"", "`"$newFile`"" -ErrorAction Stop
                Write-Host "VSCodeを起動しました。" -ForegroundColor Green
                Write-CommonLog -Message "VSCode起動成功" -LogPath $script:logPath -Level "INFO"
            } catch {
                Write-Warning "VSCodeの起動に失敗しました: $($_.Exception.Message)"
                Write-CommonLog -Message "VSCode起動失敗: $($_.Exception.Message)" -LogPath $script:logPath -Level "ERROR"
                Write-Warning "VSCodeがインストールされているか、PATHに追加されているか確認してください。"
            }
        }
    } elseif ($DiffTool -eq "Custom") { # カスタム差分ツールモードの場合
        Write-Host "`nカスタム差分ツールモード: 手動で以下のパスを比較してください" -ForegroundColor Yellow
        Write-CommonLog -Message "カスタム差分ツールモード" -LogPath $script:logPath -Level "INFO"
        Write-Host "Old: $oldFile" -ForegroundColor Cyan
        Write-Host "New: $newFile" -ForegroundColor Cyan
    } else { # WinMergeモード（デフォルト）
        # WinMerge (デフォルト)
        # WinMergeの実行パスの確認
        $ExecWinMerge = Join-Path -Path $winMergePath -ChildPath "WinMergeU.exe"
        if (-not (Test-Path -Path $ExecWinMerge)) { # WinMergeが見つからない場合
            Show-ErrorPopup "WinMergeが見つかりませんでした。`r`n`r`n$ExecWinMerge`r`nを確認してください。"
            exit $script:exitFileNotFound
        }
        
        Write-Verbose "WinMerge実行ファイル: $ExecWinMerge"
    
        # WinMergeの実行
        Write-Host "`nWinMergeを起動しています..." -ForegroundColor Cyan
        Write-CommonLog -Message "WinMergeで差分比較を起動" -LogPath $script:logPath -Level "INFO"
        if ($PSCmdlet.ShouldProcess($ExecWinMerge, "WinMerge起動")) { # WinMerge起動
            try {
                $winMergeArgs = @( # WinMerge引数リスト
                    "/r",           # 再帰的に比較
                    "/u",           # ユニコードモード
                    "/dl", "Old",   # ラベル設定
                    "/dr", "New",   # ラベル設定
                    "`"$oldFile`"", # 比較元フォルダー
                    "`"$newFile`""  # 比較先フォルダー
                )
                
                Start-Process -FilePath $ExecWinMerge -ArgumentList $winMergeArgs -ErrorAction Stop
                Write-Host "WinMergeを起動しました。" -ForegroundColor Green
                Write-CommonLog -Message "WinMerge起動成功" -LogPath $script:logPath -Level "INFO"
            } catch {
                Write-CommonLog -Message "WinMerge起動失敗: $($_.Exception.Message)" -LogPath $script:logPath -Level "ERROR"
                Show-ErrorPopup "WinMergeの実行に失敗しました。`r`n`r`n$($_.Exception.Message)"
                exit $script:exitGeneralError
            }
        }
    }
    
    # 処理の完了メッセージ
    Write-Host "`n処理が完了しました。" -ForegroundColor Green
    if (-not $WhatIfPreference) { # WhatIfモードでない場合
        if ($DiffTool -ne "Custom") { # カスタム差分ツールモードでない場合
            Write-Host "差分比較ツールで差分を確認してください。" -ForegroundColor Green
        }
    }
    
    # ログ完了
    if ($failCount -gt 0) { # 失敗があった場合
        Write-CommonLog -Message "DLL逆コンパイルスクリプトを終了（一部失敗）" -LogPath $script:logPath -Level "WARN"
    } else { # 失敗がなかった場合
        Write-CommonLog -Message "DLL逆コンパイルスクリプトを正常終了" -LogPath $script:logPath -Level "INFO"
    }
    Write-CommonLog -Message "────────────────────────────────────────" -LogPath $script:logPath -Level "INFO"
    
    # 失敗があった場合は適切な終了コードを返す
    if ($failCount -gt 0) { # 失敗があった場合
        Write-Warning "一部のDLL処理に失敗しました。詳細はログを確認してください。"
    }
    
    # ショートカットから実行された場合の一時停止（-NoKeyWaitオプションで制御可能）
    # 親プロセスがexplorer.exeの場合（ショートカットからの実行）に待機
    if (-not $NoKeyWait) {
        $parentProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $PID" | 
            ForEach-Object { Get-Process -Id $_.ParentProcessId -ErrorAction SilentlyContinue }    # 親プロセス取得
        
        if ($parentProcess -and $parentProcess.ProcessName -eq 'explorer') { # 親プロセスがexplorer.exeの場合（ショートカットからの実行）
            Write-Host "`n続行するには何かキーを押してください..." -ForegroundColor $script:colorInfo
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') # キー入力待機
        }
    }
    
    # 終了コードを設定
    if ($failCount -gt 0) { # 失敗があった場合
        exit $script:exitDecompileFailed
    }
}
