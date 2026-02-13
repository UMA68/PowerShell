<#
.SYNOPSIS
    ILSpyCmd (.NET逆コンパイルツール) を自動的にインストールします。

.DESCRIPTION
    このスクリプトは、ILSpyCmdとその前提条件である.NET SDKを自動的にインストールします。
    v1.4.0では、非対話モード、例外分類、柔軟なパラメータ検証機能を追加しました。
    
    主な機能:
    - ILSpyCmdのインストール状態確認とバージョン比較
    - 管理者権限の確認と要求
    - ネットワーク接続の検証（NuGet.org）
    - .NET SDKの存在確認と自動インストール
    - インストーラーファイルの検証（サイズ、読み取り可能性）
    - インストールタイムアウト処理（10分）
    - インストール失敗時のロールバック機能
    - YAMLファイルからの設定読み込みと検証（相対・絶対パス対応）
    - 詳細なログ出力（INFO、WARN、ERROR、DEBUG）
    - 例外タイプに基づくログレベル自動分類（v1.4.0）
    - 非対話モード対応（-NoKeyWait）（v1.3.0）
    - 安全なエラーハンドリング（exit文完全排除、end ブロック保証）（v1.3.0）

    終了コード:
    - 0: 正常終了
    - 1: 一般エラー（ファイル未検出、スクリプトエラーなど）
    - 2: YAML検証エラー（必須フィールド不足）
    - 3: 権限不足（管理者権限が必要）
    - 4: ネットワークエラー（NuGet.orgに接続不可）
    - 5: インストーラー検証エラー（ファイル破損の可能性）
    - 6: タイムアウトエラー（インストールが10分を超過）

.PARAMETER EnvYaml
    使用するYAML設定ファイル名またはパス。デフォルトは "getILSpyCmd.yaml" です。
    
    指定方法（v1.4.0で強化）:
    - ファイル名のみ: "custom.yaml" → YAMLフォルダ直下を想定
    - 相対パス: "../Config/custom.yaml" → スクリプト位置から解決
    - 絶対パス: "C:\Config\getILSpyCmd.yaml" → そのまま使用
    - 拡張子: ".yaml" または ".yml" のみ許可（v1.4.0）
    - パス長: 260文字以内を推奨（Windowsの一般的な制限に配慮）
    
    必須YAMLフィールド:
    - Project: プロジェクト名
    - Version: スクリプトバージョン
    - LOG.FILENAME: ログファイル名
    - LOG.EXTENSION: ログ拡張子
    - DotnetSdk.SdkFolder: SDKインストーラー格納フォルダ名
    - DotnetSdk.Installer: SDKインストーラーファイル名
    - DotnetSdk.Version: インストールするSDKバージョン
    
    オプションYAMLフィールド:
    - ILSpyCmd.ExpectedVersion: 期待するILSpyCmdバージョン
    - Module.Powershell-Yaml.Version: 特定バージョンのYAMLモジュールを指定

.PARAMETER NoKeyWait
    非対話モードで実行します（v1.3.0で追加）。
    このフラグを指定すると、すべてのポップアップダイアログが抑止され、
    ログファイルも自動的に開きません。
    スケジューラータスクやCI/CDパイプラインでの使用に適しています。
    SDK未導入時のインストール確認は自動的に「はい」として承認されます（v1.4.0）。

.EXAMPLE
    .\getILSpyCmd.ps1
    デフォルト設定（getILSpyCmd.yaml）でILSpyCmdをインストールします。
    対話的にポップアップが表示され、ログファイルが自動的に開きます。

.EXAMPLE
    .\getILSpyCmd.ps1 -EnvYaml "custom.yaml"
    カスタムYAML設定ファイル（YAMLフォルダ内のcustom.yaml）を使用します。

.EXAMPLE
    .\getILSpyCmd.ps1 -EnvYaml "../Config/prod.yaml"
    相対パスでYAML設定ファイルを指定します（スクリプト位置から解決）。

.EXAMPLE
    .\getILSpyCmd.ps1 -EnvYaml "C:\Infrastructure\ILSpyCmd\config.yaml"
    絶対パスでYAML設定ファイルを指定します。

.EXAMPLE
    .\getILSpyCmd.ps1 -NoKeyWait
    非対話モードで実行します。ポップアップなし、ログファイル自動オープンなし。
    スケジューラータスクやバッチ処理での使用に最適です。

.EXAMPLE
    .\getILSpyCmd.ps1 -EnvYaml "production.yaml" -NoKeyWait
    カスタムYAMLを使用し、非対話モードで実行します。

.NOTES
    File Name      : getILSpyCmd.ps1
    Author         : UMA
    Prerequisite   : PowerShell 7.x, powershell-yaml module
    Version        : 1.4.0
    Last Updated   : 2026-01-19
    
    前提条件:
    - PowerShell 7.x 以上（7.3.9以上推奨）
    - powershell-yamlモジュールがインストールされていること
    - Write-CommonLog.ps1が Common フォルダに存在すること
    - getILSpyCmd.yaml が YAML フォルダに存在すること（または指定パス）
    - .NET SDKインストーラーが指定フォルダに存在すること
    - インターネット接続（NuGet.orgへのアクセス確認）
    - 管理者権限（.NET SDKインストール時に必要）
    
    動作詳細:
    1. パラメータ検証と相対パス解決（v1.4.0）
    2. YAML設定ファイルの読み込みと必須フィールド検証
    3. ILSpyCmdのインストール状態確認とバージョン比較
    4. 管理者権限チェック（SDK未インストール時）
    5. ネットワーク接続確認（NuGet.orgへPing/HTTP）
    6. .NET SDKの存在確認と必要に応じてインストール
    7. インストーラーファイルの整合性検証
    8. タイムアウト付きSDKインストール（最大10分）
    9. 環境変数PATH更新と反映確認
    10. ILSpyCmdのグローバルツールとしてのインストール
    11. インストール失敗時の自動ロールバック提案
    12. 例外タイプに基づくログレベル分類（v1.4.0）
    13. end ブロックでのクリーンアップ保証（COM解放、終了コード設定）
    
    改善履歴:
    v1.4.0 (2026-01-07) - 例外タイプのログレベル分類化、パラメータ検証強化
    v1.3.0 (2025-01-15) - exit文完全排除、-NoKeyWaitパラメータ追加
    v1.2.0 (2024-12)    - ネットワーク確認、インストーラー検証強化
    v1.1.0 (2024-11)    - YAML設定対応、ログ機能強化
    v1.0.0 (2024-10)    - 初版リリース

.LINK
    https://github.com/UMA68/PowerShell
    ./ILSpyCmdの入手/Readme.md
    ./ILSpyCmdの入手/Script/Verify_v1.4.0.ps1
#>
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ # YAMLファイル名の妥当性検証
            # パス（相対・絶対・ファイル名のみ）いずれも許容。拡張子のみ検証。
            if ($_ -notmatch '\.(yaml|yml)$') { # 拡張子チェック
                throw "YAMLファイルは .yaml または .yml 拡張子である必要があります: $_"
            }
            if ([string]::IsNullOrWhiteSpace($_)) { # 空文字チェック
                throw "YAMLパスは空にできません"
            }
            if ($_.Length -gt 260) { # 一般的なWindowsパス長制限に配慮
                throw "YAMLパスが長すぎます（目安260文字超）: $($_.Length)文字"
            }
            $true
        })]
    [string]$EnvYaml = "getILSpyCmd.yaml",   # デフォルトのYAMLファイル名
    
    [Parameter(Mandatory = $false)]
    [switch]$NoKeyWait = $false      # 非対話環境でキー待機を無効化
)

begin {
    $script:CanExecuteProcess = $true
    $script:ExitCode = 0
    
    # ヘルパー関数: 例外タイプに基づくログレベル決定 (#3改善)
    function Get-ExceptionLogLevel {
        <#
        .SYNOPSIS
            例外タイプからログレベルを返すヘルパー。

        .DESCRIPTION
            例外種類に応じて 'ERROR' または 'WARN' を返し、ログ分類に利用する。

        .PARAMETER Exception
            評価対象の例外。

        .OUTPUTS
            [string]
        #>
        param([Exception]$Exception)
        $exceptionType = $Exception.GetType().FullName
        switch -regex ($exceptionType) { # 正規表現マッチング
            'FileNotFoundException' { return 'ERROR' }          # ファイル未検出
            'DirectoryNotFoundException' { return 'ERROR' }     # ディレクトリ未検出
            'UnauthorizedAccessException' { return 'ERROR' }    # 権限不足
            'ParsingException' { return 'ERROR' }               # 解析エラー
            'InvalidOperationException' { return 'ERROR' }      # 無効な操作
            'TimeoutException' { return 'WARN' }                # タイムアウト
            'WebException' { return 'ERROR' }                   # Web例外
            'IOException' { return 'ERROR' }                    # 入出力例外
            'ArgumentException' { return 'ERROR' }              # 引数例外
            default { return 'ERROR' }                          # その他
        }
    }
    
    # パラメータ検証 #4: EnvYaml パラメータの相対パス対応とデフォルト構築
    $script:EnvYamlResolved = $EnvYaml
    if (-not [System.IO.Path]::IsPathRooted($script:EnvYamlResolved)) { # 相対パスの場合
        if ($script:EnvYamlResolved -notmatch '[/\\]') { # ファイル名のみの場合
            # ファイル名のみ → YAML フォルダ配下を想定
            $script:EnvYamlResolved = Join-Path -Path "YAML" -ChildPath $script:EnvYamlResolved
        }
    }
    
    # スクリプトの実行環境を取得
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path   # スクリプトの実行パスを取得
    $script:UpperPath = Split-Path -Parent $script:ScriptPath                     # スクリプトの親パスを取得
    $script:PowerShellDir = Split-Path -Parent $script:UpperPath                  # スクリプトの親パスの親パスを取得
    $script:YamlDir = Join-Path -Path $script:UpperPath -ChildPath "YAML"         # YAMLフォルダのパスを取得
    
    # YAML ファイルパスの解決（相対パス対応）
    if ([System.IO.Path]::IsPathRooted($script:EnvYamlResolved)) { # 絶対パスの場合
        # 絶対パス → そのまま使用
        $script:YamlPath = $script:EnvYamlResolved
    } else { # 相対パス → スクリプトディレクトリを基準に解決
        # 相対パス → スクリプトディレクトリを基準に解決
        $script:YamlPath = Join-Path -Path $script:ScriptPath -ChildPath ".." | Join-Path -ChildPath $script:EnvYamlResolved | Resolve-Path -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
        if (-not $script:YamlPath) { # 解決できなかった場合
            # デフォルトパスを使用
            $script:YamlPath = Join-Path -Path $script:YamlDir -ChildPath $EnvYaml
        }
    }
    $script:LogDir = Join-Path -Path $script:UpperPath -ChildPath "Log"           # ログフォルダのパスを取得
    $script:ComPath = Join-Path -Path $script:PowerShellDir -ChildPath "Common"   # 共通スクリプトのパス
    
    # COMオブジェクトの作成（スクリプト全体で使用）
    $script:comObject = $null
    try {
        $script:comObject = New-Object -ComObject WScript.Shell
    } catch {
        Write-Error "COMオブジェクトの作成に失敗しました: $_"
        Write-Error "Exception Type: $($_.Exception.GetType().FullName)"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }

    # 共通スクリプトのインポート
    $commonLogPath = Join-Path -Path $script:ComPath -ChildPath "Write-CommonLog.ps1"
    try {
        . $commonLogPath -ErrorAction Stop
    }catch {
        if (-not $NoKeyWait) { # ポップアップ表示
            $script:comObject.Popup("共通スクリプト (Write-CommonLog.ps1) を読み込めませんでした。処理を終了します。`r`n`r`nエラー: $($_.Exception.Message)", 0, "スクリプトエラー", 0x10) | Out-Null
        }
        Write-Error "Exit Code 1: Common script import failed - $($_.Exception.Message)"
        # 改善 #3: 例外タイプに基づくログレベル決定
        $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
        Write-Error "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }

    # YAMLファイルの存在チェック
    if (-not (Test-Path -Path $script:YamlPath)) { # YAMLファイルが存在しない場合
        if (-not $NoKeyWait) { # ポップアップ表示
            $script:comObject.Popup("YAMLファイルが存在しません。`r`n`r`nパス: $($script:YamlPath)", 0, "ファイルエラー", 0x10) | Out-Null
        }
        Write-Error "Exit Code 1: YAML file not found - $($script:YamlPath)"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }
    
    # YAMLファイルの読み込み（まず基本的なYAML読み込みのみ）
    try {
        Import-Module -Name "powershell-yaml" -ErrorAction Stop
        $script:Yaml = Get-Content -Path $script:YamlPath -Raw -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    } catch {
        if (-not $NoKeyWait) { # ポップアップ表示
            $script:comObject.Popup("YAMLファイルの読み込みに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)", 0, "YAML読み込みエラー", 0x10) | Out-Null
        }
        Write-Error "Exit Code 1: YAML parse failed - $($_.Exception.Message)"
        # 改善 #3: 例外タイプに基づくログレベル決定
        $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
        Write-Error "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }
    
    # YAMLファイルにバージョン指定があれば、指定バージョンで再インポート
    if ($script:Yaml.Module.'Powershell-Yaml'.Version) { # バージョン指定あり
        [string]$PowershellYamlVersion = $script:Yaml.Module.'Powershell-Yaml'.Version.ToString()
        try {
            Import-Module -Name "powershell-yaml" -RequiredVersion $PowershellYamlVersion -Force -ErrorAction Stop
        } catch {
            if (-not $NoKeyWait) { # ポップアップ表示
                $script:comObject.Popup("powershell-yaml (v$PowershellYamlVersion) モジュールのインポートに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)", 0, "モジュールエラー", 0x10) | Out-Null
            }
            Write-Error "Exit Code 1: Module import failed - powershell-yaml v$PowershellYamlVersion"
            # 改善 #3: 例外タイプに基づくログレベル決定
            $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
            Write-Error "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]"
            $script:CanExecuteProcess = $false
            $script:ExitCode = 1
            return
        }
    }
    
    # YAML必須フィールドの検証
    $requiredFields = @( # 必須フィールドリスト
        @{ Path = "LOG.FILENAME"; Name = "ログファイル名" },
        @{ Path = "LOG.EXTENSION"; Name = "ログ拡張子" },
        @{ Path = "Project"; Name = "プロジェクト名" },
        @{ Path = "Version"; Name = "バージョン" },
        @{ Path = "DotnetSdk.SdkFolder"; Name = "SDKフォルダ名" },
        @{ Path = "DotnetSdk.Installer"; Name = "SDKインストーラー名" },
        @{ Path = "DotnetSdk.Version"; Name = "SDKバージョン" }
    )
    
    # Yamlファイルの必須フィールドチェック
    $missingFields = @()
    foreach ($field in $requiredFields) { # 各必須フィールドをチェック
        $pathParts = $field.Path -split '\.'
        $value = $yaml
        $found = $true
        
        # フィールドの存在確認
        foreach ($part in $pathParts) { # 各パスセグメントを順に辿る
            if ($null -eq $value) { # フィールドが見つからない場合
                $found = $false
                break
            }
            
            # OrderedDictionary または Hashtable の場合
            if ($value -is [System.Collections.IDictionary]) { # OrderedDictionary または Hashtable の場合
                if ($value.Contains($part)) { # キーが存在する場合
                    $value = $value[$part]
                } else { # フィールドが見つからない場合
                    $found = $false
                    # デバッグ情報をログに記録
                    if ($script:Log -and (Test-Path $script:Log)) { # OrderedDictionary または Hashtable の場合
                        $availableKeys = ($value.Keys | ForEach-Object { $_ }) -join ', '
                        Write-CommonLog -Message "YAML validation: Field '$part' not found in path '$($field.Path)'. Available keys: $availableKeys" -LogPath $script:Log -Level "DEBUG"
                    }
                    break
                }
            }
            # PSCustomObject の場合
            elseif ($value.PSObject.Properties.Name -contains $part) { # プロパティが存在する場合
                $value = $value.$part
            } else { # フィールドが見つからない場合
                $found = $false
                # デバッグ情報をログに記録
                if ($script:Log -and (Test-Path $script:Log)) { # PSCustomObject の場合
                    Write-CommonLog -Message "YAML validation: Field '$part' not found in path '$($field.Path)'. Available keys: $($value.PSObject.Properties.Name -join ', ')" -LogPath $script:Log -Level "DEBUG"
                }
                break
            }
        }
        
        # 不足フィールドの収集
        if (-not $found -or [string]::IsNullOrWhiteSpace($value)) { # フィールドが存在しないか、空文字
            $missingFields += "  - $($field.Name) ($($field.Path))"
        }
    }
    
    # 不足フィールドがあればエラーメッセージを表示して終了
    if ($missingFields.Count -gt 0) { # 不足フィールドあり
        $errorMsg = "YAMLファイルに必須フィールドが不足しています。`r`n`r`n不足フィールド:`r`n" + ($missingFields -join "`r`n")
        if (-not $NoKeyWait) { # ポップアップ表示
            $script:comObject.Popup($errorMsg, 0, "YAML検証エラー", 0x10) | Out-Null
        }
        Write-Error "Exit Code 2: YAML validation failed - Missing required fields"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 2
        return
    }

    # ログディレクトリが作成されていなければ作成
    if (-not (Test-Path -Path $LogDir)) { # ログディレクトリ作成
        try {
            New-Item -Path $LogDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            if (-not $NoKeyWait) { # ログディレクトリ作成失敗時のポップアップ表示
                $script:comObject.Popup("ログディレクトリの作成に失敗しました。`r`n`r`nパス: $LogDir`r`nエラー: $($_.Exception.Message)", 0, "ディレクトリエラー", 0x10) | Out-Null
            }
            Write-Error "Exit Code 1: Log directory creation failed - $LogDir"
            # 改善 #3: 例外タイプに基づくログレベル決定
            $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
            Write-Error "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]"
            $script:CanExecuteProcess = $false
            $script:ExitCode = 1
            return
        }
    }
    
    # ユーザーとホスト情報の取得
    $script:User = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME

    # YAMLファイルから必要な情報を取得
    $LogFileName = $script:Yaml.LOG.FILENAME
    $Logextension = $script:Yaml.LOG.EXTENSION

    # ログファイルパスの定義（ミリ秒を含めて重複を回避）
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $milliseconds = (Get-Date).Millisecond.ToString("000")
    $script:Log = Join-Path -Path $LogDir -ChildPath ($LogFileName + "_" + $timestamp + "-" + $milliseconds + $Logextension)
    
    # 管理者権限の確認
    $script:isAdmin = $false
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $script:isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
process {
    # 事前ガード: begin段階で致命エラーが発生した場合は処理しない
    if (-not $script:CanExecuteProcess) {
        return
    }
    # タイトル表示
    Write-CommonLog -Message "HOST: $script:HostName" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "USER: $script:User" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running as Administrator: $script:isAdmin" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Running PowerShell Version: $($PSVersionTable.PSVersion)" -LogPath $script:Log -Level "INFO"
    $ProjectLength = ("Project name: " + $script:Yaml.Project).Length
    $ProjectLine = "=" * $ProjectLength
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project name: $($script:Yaml.Project)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message "Project version: $($script:Yaml.Version)" -LogPath $script:Log -Level "INFO"
    Write-CommonLog -Message $ProjectLine -LogPath $script:Log -Level "INFO"
    
    # 改行をログに出力
    "`r`n" | Tee-Object -FilePath $script:Log -Append | Out-Null

    # ILSpyCmdがインストールされているか確認
    Write-CommonLog -Message "Checking if ILSpyCmd is already installed..." -LogPath $script:Log -Level "INFO"
    $ILSpyCmdInstalled = Get-Command "ilspycmd" -ErrorAction SilentlyContinue
    if ($ILSpyCmdInstalled) { # ILSpyCmdがインストールされている場合
        Write-CommonLog -Message "✅ ILSpyCmd is already installed." -LogPath $script:Log -Level "INFO"
        
        # バージョン情報の詳細ログ
        $installedVersion = $ILSpyCmdInstalled.Version
        $installedPath = $ILSpyCmdInstalled.Source
        Write-CommonLog -Message "Installed version: $installedVersion" -LogPath $script:Log -Level "INFO"
        Write-CommonLog -Message "Installation path: $installedPath" -LogPath $script:Log -Level "INFO"
        
        # YAMLに期待バージョンがあれば比較
        if ($script:Yaml.ILSpyCmd -and $script:Yaml.ILSpyCmd.ExpectedVersion) { # 期待バージョンが指定されている場合
            $expectedVersion = $script:Yaml.ILSpyCmd.ExpectedVersion
            Write-CommonLog -Message "Expected version (from YAML): $expectedVersion" -LogPath $script:Log -Level "INFO"
            # バージョン比較
            if ($installedVersion.ToString() -ne $expectedVersion) { # バージョンが異なる場合
                Write-CommonLog -Message "Version mismatch detected. Installed: $installedVersion, Expected: $expectedVersion" -LogPath $script:Log -Level "WARN"
                if (-not $NoKeyWait) {
                    $script:comObject.Popup("ILSpyCmdはインストール済みですが、バージョンが異なります。`r`n`r`nインストール済み: $installedVersion`r`n期待バージョン: $expectedVersion`r`n`r`nプログラムを終了します。", 0, "バージョン不一致", 0x30) | Out-Null
                }
            } else { # バージョンが一致
                Write-CommonLog -Message "Version matches expected version." -LogPath $script:Log -Level "INFO"
                if (-not $NoKeyWait) {
                    $script:comObject.Popup("ILSpyCmdはすでにインストールされています。`r`n`r`nバージョン: $installedVersion (正常)`r`n`r`nプログラムを終了します。", 0, "確認完了", 0x40) | Out-Null
                }
            }
        } else { # 期待バージョンが指定されていない場合
            Write-CommonLog -Message "No expected version specified in YAML. Skipping version check." -LogPath $script:Log -Level "INFO"
            if (-not $NoKeyWait) {
                $script:comObject.Popup("ILSpyCmdはすでにインストールされています。`r`n`r`nバージョン: $installedVersion`r`n`r`nプログラムを終了します。", 0, "確認完了", 0x40) | Out-Null
            }
        }

        # ログファイルを開いて終了
        if (-not $NoKeyWait) { # ログファイルを開く
            Invoke-Item -Path $script:Log
        }
        Write-CommonLog -Message "ILSpyCmd already installed. Exit Code 0." -LogPath $script:Log -Level "INFO"
        $script:CanExecuteProcess = $false
        $script:ExitCode = 0
        return
    } else { # ILSpyCmdがインストールされていない場合
        Write-CommonLog -Message "ILSpyCmd is not installed. Proceeding with installation..." -LogPath $script:Log -Level "INFO"
    }

    # .NET SDKの存在確認
    Write-CommonLog -Message "Checking for .NET SDK installation..." -LogPath $script:Log -Level "INFO"
    $dotnetCommand = Get-Command "dotnet" -ErrorAction SilentlyContinue
    $sdks = if ($dotnetCommand) { & dotnet --list-sdks 2>$null } else { $null }
    
    # SDKのインストール
    if (-not $sdks) { # SDKがインストールされていない場合
        Write-CommonLog -Message ".NET SDK is not installed." -LogPath $script:Log -Level "WARN"
        
        # 管理者権限の確認
        if (-not $script:isAdmin) { # 管理者権限がない場合
            Write-CommonLog -Message "Administrator privileges required for SDK installation." -LogPath $script:Log -Level "WARN"
            if (-not $NoKeyWait) { # COMポップアップで管理者権限エラーメッセージを表示
                $script:comObject.Popup(".NET SDKのインストールには管理者権限が必要です。`r`n`r`nこのスクリプトを管理者として実行してください。`r`n`r`nプログラムを終了します。", 0, "管理者権限が必要", 0x30) | Out-Null
            }
            Write-CommonLog -Message "Exit Code 3: Insufficient privileges - Administrator rights required" -LogPath $script:Log -Level "ERROR"
            if (-not $NoKeyWait) { # ログファイルを開く
                Invoke-Item -Path $script:Log
            }
            $script:CanExecuteProcess = $false
            $script:ExitCode = 3
            return
        }
        
        # ユーザーにSDKインストールの確認
        [int]$retButton = 6
        if (-not $NoKeyWait) {
            $retButton = $script:comObject.Popup("dotnet(sdk)がインストールされていません。`r`n`r`n.NET SDK をインストールしますか？`r`n`r`n※インストールには数分かかる場合があります。", 0, "SDK未検出", 36)
        } else {
            Write-CommonLog -Message "NoKeyWait is specified. Auto-accepting SDK installation prompt." -LogPath $script:Log -Level "INFO"
        }
        switch ($retButton) {
            # はい(.NET SDKをインストール)
            6 {
                # インストーラー格納先
                $SdkFolderName = $script:Yaml.DotnetSdk.SdkFolder
                $SdkFolderPath = Join-Path -Path $script:UpperPath -ChildPath $SdkFolderName
                $installerPath = Join-Path -Path $SdkFolderPath -ChildPath $script:Yaml.DotnetSdk.Installer
                $verSDK = $script:Yaml.DotnetSdk.Version
                
                # インストーラーの存在確認
                if (-not (Test-Path -Path $installerPath)) { # インストーラーが存在しない場合
                    Write-CommonLog -Message ".NET SDK installer not found: $installerPath" -LogPath $script:Log -Level "ERROR"
                    if (-not $NoKeyWait) { # COMポップアップでエラーメッセージを表示
                        $script:comObject.Popup("SDKインストーラーが見つかりません。`r`n`r`nパス: $installerPath`r`n`r`nプログラムを終了します。", 0, "ファイルエラー", 0x10) | Out-Null
                    }
                    if (-not $NoKeyWait) { # ログファイルを開く
                        Invoke-Item -Path $script:Log
                    }
                    $script:CanExecuteProcess = $false
                    $script:ExitCode = 1
                    return
                }
                
                # インストーラーファイルの検証
                try {
                    $installerFile = Get-Item -Path $installerPath -ErrorAction Stop
                    $installerSizeMB = [math]::Round($installerFile.Length / 1MB, 2)
                    Write-CommonLog -Message "Installer file size: $installerSizeMB MB" -LogPath $script:Log -Level "INFO"
                    
                    # ファイルサイズが異常に小さい場合は警告（通常50MB以上）
                    if ($installerFile.Length -lt 10MB) { # 10MB未満を異常とみなす
                        Write-CommonLog -Message "Warning: Installer file size is unusually small ($installerSizeMB MB). File may be corrupted." -LogPath $script:Log -Level "WARN"
                        if (-not $NoKeyWait) { # COMポップアップで警告表示
                            [int]$continueButton = $script:comObject.Popup("警告：インストーラーのファイルサイズが異常に小さいです ($installerSizeMB MB)。`r`n`r`nファイルが破損している可能性があります。`r`n`r`n続行しますか？", 0, "ファイル検証警告", 52)
                            # ユーザーが「いいえ」を選択した場合は終了
                            if ($continueButton -eq 7) { # 7 = No
                                Write-CommonLog -Message "User chose not to continue with potentially corrupted installer." -LogPath $script:Log -Level "INFO"
                                Write-CommonLog -Message "Exit Code 5: Installer validation warning - User declined to continue" -LogPath $script:Log -Level "WARN"
                                $script:CanExecuteProcess = $false
                                $script:ExitCode = 5
                                return
                            }
                        }
                    }
                    
                    # 読み取り可能かチェック
                    $fileStream = [System.IO.File]::OpenRead($installerPath)
                    $fileStream.Close()
                    Write-CommonLog -Message "Installer file is accessible and appears valid." -LogPath $script:Log -Level "INFO"
                } catch {
                    Write-CommonLog -Message "Installer file validation failed: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                    Write-CommonLog -Message "Exit Code 5: Installer validation failed - $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                    # 改善 #3: 例外タイプに基づくログレベル決定と記録
                    $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
                    Write-CommonLog -Message "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]" -LogPath $script:Log -Level $logLevel
                    if (-not $NoKeyWait) { # COMポップアップでエラーメッセージを表示
                        $script:comObject.Popup("インストーラーファイルの検証に失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`nプログラムを終了します。", 0, "ファイル検証エラー", 0x10) | Out-Null
                    }
                    $script:CanExecuteProcess = $false
                    $script:ExitCode = 5
                    return
                }

                # dotnet SDKのインストール
                Write-CommonLog -Message "Starting .NET SDK ($verSDK) installation..." -LogPath $script:Log -Level "INFO"
                if (-not $NoKeyWait) { # COMポップアップでインストール開始メッセージを表示
                    $script:comObject.Popup("dotnet SDK ($verSDK) のインストールを開始します。`r`n`r`nインストールウィンドウが表示されます。`r`n完了まで数分かかる場合があります。", 0, "インストール開始", 0x40) | Out-Null
                }

                # インストール前の状態を記録（ロールバック用）
                $preSdks = if (Get-Command "dotnet" -ErrorAction SilentlyContinue) { & dotnet --list-sdks 2>$null } else { @() }
                Write-CommonLog -Message "Pre-installation SDK count: $($preSdks.Count)" -LogPath $script:Log -Level "INFO"

                Try {
                    # インストール（パッシブモード：進捗表示あり、操作不要）
                    Write-CommonLog -Message "Executing installer with 10-minute timeout..." -LogPath $script:Log -Level "INFO"
                    $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/install /passive /norestart" -PassThru
                    
                    # タイムアウト処理（10分）
                    $timeoutSeconds = 600
                    $waitResult = $installProcess.WaitForExit($timeoutSeconds * 1000)
                    
                    # タイムアウト発生時の処理
                    if (-not $waitResult) { # インストールプロセスがタイムアウトした場合の処理
                        # タイムアウト発生
                        Write-CommonLog -Message "Installation process timed out after $timeoutSeconds seconds." -LogPath $script:Log -Level "ERROR"
                        Write-CommonLog -Message "Exit Code 6: Installation timeout - Process exceeded $timeoutSeconds seconds" -LogPath $script:Log -Level "ERROR"
                        try {
                            $installProcess.Kill()
                            Write-CommonLog -Message "Installation process terminated." -LogPath $script:Log -Level "WARN"
                        } catch {
                            # 改善 #3: 例外タイプに基づくログレベル決定
                            $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
                            Write-CommonLog -Message "Failed to terminate installation process: $($_.Exception.Message)" -LogPath $script:Log -Level $logLevel
                            Write-CommonLog -Message "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]" -LogPath $script:Log -Level $logLevel
                        }
                        if (-not $NoKeyWait) { # COMポップアップでタイムアウトメッセージを表示
                            $script:comObject.Popup("SDKのインストールがタイムアウトしました（${timeoutSeconds}秒）。`r`n`r`nインストールプロセスを中断しました。`r`n`r`nプログラムを終了します。", 0, "タイムアウトエラー", 0x10) | Out-Null
                        }
                        $script:CanExecuteProcess = $false
                        $script:ExitCode = 6
                        return
                    }
                    
                    # インストール完了後の処理
                    if ($installProcess.ExitCode -eq 0) { # インストール成功時の処理
                        Write-CommonLog -Message ".NET SDK installation completed successfully (Exit Code: 0)." -LogPath $script:Log -Level "INFO"
                        
                        # 環境変数のPATHを更新（現在のセッションに反映）
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                        Write-CommonLog -Message "Environment PATH updated." -LogPath $script:Log -Level "INFO"
                        
                        # インストール確認（PATH更新後に再確認）
                        Start-Sleep -Seconds 2
                        $dotnetCheck = Get-Command "dotnet" -ErrorAction SilentlyContinue
                        if ($dotnetCheck) { # PATHが反映され、コマンドが認識された場合
                            $dotnetVersion = & dotnet --version 2>$null
                            Write-CommonLog -Message "✅ .NET SDK installed successfully. Version: $dotnetVersion" -LogPath $script:Log -Level "INFO"
                        } else { # PATH未反映または認識されない場合の処理
                            Write-CommonLog -Message "Warning: dotnet command not found after installation. May require system restart." -LogPath $script:Log -Level "WARN"
                            if (-not $NoKeyWait) { # COMポップアップで警告メッセージを表示
                                $script:comObject.Popup("SDKのインストールは完了しましたが、`r`nコマンドが認識されません。`r`n`r`nシステムの再起動が必要な場合があります。", 0, "警告", 0x30) | Out-Null
                            }
                        }
                    } else { # インストール失敗時の処理
                        # インストール失敗時のロールバック試行
                        Write-CommonLog -Message ".NET SDK installation failed (Exit Code: $($installProcess.ExitCode))." -LogPath $script:Log -Level "ERROR"
                        
                        # インストール後の状態確認
                        $postSdks = if (Get-Command "dotnet" -ErrorAction SilentlyContinue) { & dotnet --list-sdks 2>$null } else { @() }
                        if ($postSdks.Count -gt $preSdks.Count) { # インストールが部分的に成功した場合
                            Write-CommonLog -Message "Partial installation detected. Attempting rollback..." -LogPath $script:Log -Level "WARN"
                            [int]$rollbackButton = $script:comObject.Popup("SDKのインストールに失敗しましたが、一部がインストールされた可能性があります。`r`n`r`nロールバック（削除）を試みますか？", 0, "ロールバック確認", 36)
                            if ($rollbackButton -eq 6) { # ユーザーがロールバックを選択
                                try {
                                    Write-CommonLog -Message "User chose to rollback. Executing uninstaller..." -LogPath $script:Log -Level "INFO"
                                    $uninstallProcess = Start-Process -FilePath $installerPath -ArgumentList "/uninstall /passive /norestart" -Wait -PassThru   # ロールバック実行
                                    if ($uninstallProcess.ExitCode -eq 0) { # ロールバック成功
                                        Write-CommonLog -Message "Rollback completed successfully." -LogPath $script:Log -Level "INFO"
                                    } else { # ロールバック失敗
                                        Write-CommonLog -Message "Rollback failed (Exit Code: $($uninstallProcess.ExitCode))." -LogPath $script:Log -Level "ERROR"
                                    }
                                } catch {
                                    Write-CommonLog -Message "Rollback failed: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                                }
                            }
                        }
                        
                        if (-not $NoKeyWait) { # COMポップアップでエラーメッセージを表示
                            $script:comObject.Popup("dotnet SDKのインストールに失敗しました。`r`n`r`n終了コード: $($installProcess.ExitCode)`r`n`r`nプログラムを終了します。", 0, "インストールエラー", 0x10) | Out-Null
                        }
                        $script:CanExecuteProcess = $false
                        $script:ExitCode = 1
                        return
                    }
            
                } catch {
                    Write-CommonLog -Message "Failed to start .NET SDK installation: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
                    # 改善 #3: 例外タイプに基づくログレベル決定
                    $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
                    Write-CommonLog -Message "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]" -LogPath $script:Log -Level $logLevel
                    if (-not $NoKeyWait) { # COMポップアップでエラーメッセージを表示
                        $script:comObject.Popup("SDKインストーラーの起動に失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`nプログラムを終了します。", 0, "起動エラー", 0x10) | Out-Null
                    }
                    $script:CanExecuteProcess = $false
                    $script:ExitCode = 1
                    return
                }
            }                
            # いいえ(スクリプト終了)
            7 {
                Write-CommonLog -Message "User declined .NET SDK installation. Exiting script." -LogPath $script:Log -Level "INFO"
                if (-not $NoKeyWait) { # COMポップアップでキャンセルメッセージを表示
                    $script:comObject.Popup(".NET SDKのインストールがキャンセルされました。`r`n`r`nプログラムを終了します。", 0, "キャンセル", 0x40) | Out-Null
                }
                $script:CanExecuteProcess = $false
                $script:ExitCode = 0
                return
            }
        }

    } else { # dotnetがインストールされていた場合の処理
        # dotnetがインストールされていた場合の処理
        Write-CommonLog -Message "✅ .NET SDK is already installed." -LogPath $script:Log -Level "INFO"
        $DotnetSdks = & dotnet --list-sdks 2>$null
        Write-CommonLog -Message "Installed SDKs:" -LogPath $script:Log -Level "INFO"
        # インストールされているSDKの一覧をログに出力
        foreach ($sdk in $DotnetSdks) { # SDKごとにログ出力
            Write-CommonLog -Message "  $sdk" -LogPath $script:Log -Level "INFO"
        }
    }

    # ILSpyCmdのインストール
    Write-CommonLog -Message "Starting ILSpyCmd installation..." -LogPath $script:Log -Level "INFO"
    
    # ネットワーク接続の確認（NuGet.orgへの接続テスト）
    Write-CommonLog -Message "Checking network connectivity to NuGet.org..." -LogPath $script:Log -Level "INFO"
    try {
        # ICMPでの接続テスト
        $testConnection = Test-Connection -ComputerName "nuget.org" -Count 2 -Quiet -ErrorAction SilentlyContinue
        # 代替手段としてHTTP接続も試みる
        if (-not $testConnection) {
            # Test-Connectionが失敗した場合、HTTP接続で再試行
            try {
                $webRequest = [System.Net.WebRequest]::Create("https://www.nuget.org")
                $webRequest.Timeout = 5000
                $response = $webRequest.GetResponse()
                $response.Close()
                $testConnection = $true
                Write-CommonLog -Message "Network connectivity confirmed via HTTP." -LogPath $script:Log -Level "INFO"
            } catch {
                $testConnection = $false
            }
        } else { # ICMP接続成功時のログ
            Write-CommonLog -Message "Network connectivity confirmed via ICMP." -LogPath $script:Log -Level "INFO"
        }
        
        # ネットワーク接続が確認できない場合の処理
        if (-not $testConnection) { # 接続失敗時の処理
            Write-CommonLog -Message "Network connectivity check failed. Cannot reach NuGet.org." -LogPath $script:Log -Level "ERROR"
            Write-CommonLog -Message "Exit Code 4: Network connectivity error - Unable to reach NuGet.org" -LogPath $script:Log -Level "ERROR"
            if (-not $NoKeyWait) { # COMポップアップでエラーメッセージを表示
                $script:comObject.Popup("インターネット接続が確認できません。`r`n`r`nILSpyCmdのインストールにはインターネット接続が必要です。`r`n`r`nネットワーク接続を確認してください。", 0, "ネットワークエラー", 0x10) | Out-Null
            }
            $script:CanExecuteProcess = $false
            $script:ExitCode = 4
            return
        }
    } catch {
        # 改善 #3: ネットワーク例外でも WARN レベルとして記録
        $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
        Write-CommonLog -Message "Network connectivity check encountered an error: $($_.Exception.Message)" -LogPath $script:Log -Level $logLevel
        Write-CommonLog -Message "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]" -LogPath $script:Log -Level $logLevel
        Write-CommonLog -Message "Proceeding with installation attempt..." -LogPath $script:Log -Level "INFO"
    }
    
    if (-not $NoKeyWait) { # COMポップアップでインストール開始メッセージを表示
        $script:comObject.Popup("ILSpyCmdをインストールします。`r`n`r`nコマンドプロンプトウィンドウが表示されます。`r`n完了まで数分かかる場合があります。", 0, "インストール開始", 0x40) | Out-Null
    }
    
    try {
        # dotnet tool install --global ilspycmd をコマンドプロンプトで実行
        $cmdCommand = 'dotnet tool install --global ilspycmd && echo. && echo ILSpyCmd のインストールが完了しました。 && echo Enterキーを押して終了してください。 && pause'
        $installProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmdCommand" -Wait -PassThru -ErrorAction Stop
        
        # インストール結果の確認
        if ($installProcess.ExitCode -eq 0) { # インストール成功時の処理
            Write-CommonLog -Message "'dotnet tool install --global ilspycmd' executed successfully (Exit Code: 0)." -LogPath $script:Log -Level "INFO"
            
            # インストール確認
            Start-Sleep -Seconds 2
            $ilspyCheck = Get-Command "ilspycmd" -ErrorAction SilentlyContinue
            if ($ilspyCheck) { # コマンドが見つかった場合
                Write-CommonLog -Message "✅ ILSpyCmd installed successfully." -LogPath $script:Log -Level "INFO"
                Write-CommonLog -Message "ILSpyCmd Path: $($ilspyCheck.Source)" -LogPath $script:Log -Level "INFO"
                if (-not $NoKeyWait) { # COMポップアップで完了メッセージを表示
                    $script:comObject.Popup("ILSpyCmdのインストールが完了しました。`r`n`r`nインストール先: $($ilspyCheck.Source)", 0, "インストール完了", 0x40) | Out-Null
                }
            } else { # コマンドが見つからない場合の処理
                Write-CommonLog -Message "Warning: ilspycmd command not found after installation." -LogPath $script:Log -Level "WARN"
                if (-not $NoKeyWait) { # COMポップアップで警告メッセージを表示
                    $script:comObject.Popup("インストールは完了しましたが、`r`nコマンドが認識されません。`r`n`r`nターミナルの再起動が必要な場合があります。", 0, "警告", 0x30) | Out-Null
                }
            }
        } else { # インストール失敗時の処理
            Write-CommonLog -Message "ILSpyCmd installation failed (Exit Code: $($installProcess.ExitCode))." -LogPath $script:Log -Level "ERROR"
            if (-not $NoKeyWait) { # COMポップアップでエラーメッセージを表示
                $script:comObject.Popup("ILSpyCmdのインストールに失敗しました。`r`n`r`n終了コード: $($installProcess.ExitCode)`r`n`r`n詳細はログを確認してください。", 0, "インストールエラー", 0x10) | Out-Null
            }
            $script:CanExecuteProcess = $false
            $script:ExitCode = 1
            return
        }
    } catch {
        Write-CommonLog -Message "Failed to install ILSpyCmd: $($_.Exception.Message)" -LogPath $script:Log -Level "ERROR"
        # 改善 #3: 例外タイプに基づくログレベル決定
        $logLevel = Get-ExceptionLogLevel -Exception $_.Exception
        Write-CommonLog -Message "Exception Type: $($_.Exception.GetType().FullName) [Log Level: $logLevel]" -LogPath $script:Log -Level $logLevel
        if (-not $NoKeyWait) { # COMポップアップでエラーメッセージを表示
            $script:comObject.Popup("ILSpyCmdのインストールに失敗しました。`r`n`r`nエラー: $($_.Exception.Message)`r`n`r`n詳細はログを確認してください。", 0, "インストールエラー", 0x10) | Out-Null
        }
        $script:CanExecuteProcess = $false
        $script:ExitCode = 1
        return
    }
}
end {
    # スクリプトの終了メッセージをログに出力（ログファイルがある場合のみ）
    if ($script:Log -and (Test-Path $script:Log)) {
        Write-CommonLog -Message "Script completed successfully." -LogPath $script:Log -Level "INFO"
    }
    
    # 終了コードに基づいてクリーンアップメッセージを出力（可読性向上）
    if ($script:Log -and (Test-Path $script:Log)) { # ログファイルが存在する場合
        if ($script:ExitCode -eq 0) {
            # 正常終了の場合
            Add-Content -Path $script:Log -Value "`n=== Script completed successfully (Exit Code: 0) ==="
        } else {
            # エラー終了の場合
            Add-Content -Path $script:Log -Value "`n=== Script ended with error (Exit Code: $script:ExitCode) ==="
        }
    }
    
    # COMオブジェクトの解放
    if ($script:comObject) { # COMオブジェクトが存在する場合
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:comObject) | Out-Null    # COMオブジェクトの解放
            [System.GC]::Collect()                  # ガベージコレクションを強制実行
            [System.GC]::WaitForPendingFinalizers() # ガベージコレクションを強制実行
        } catch {
            if ($script:Log -and (Test-Path $script:Log)) { # ログファイルが存在する場合
                Write-CommonLog -Message "COMオブジェクト解放に失敗: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
            } else {
                # ログファイルが存在しない場合
                Write-Warning "COMオブジェクト解放に失敗: $($_.Exception.Message)"
            }
        }
    }
    
    # ログファイルを開く（非対話モードを除く）
    if ((-not $NoKeyWait) -and ($script:Log -and (Test-Path $script:Log))) { # ログファイルが存在する場合
        try {
            Invoke-Item -Path $script:Log
        } catch {
            if ($script:Log -and (Test-Path $script:Log)) { # ログファイルが存在するが開けない場合
                Write-CommonLog -Message "ログファイルを開けませんでした: $($_.Exception.Message)" -LogPath $script:Log -Level "WARN"
            } else {
                Write-Warning "ログファイルを開けませんでした: $($_.Exception.Message)"
            }
        }
    }
    
    # スクリプト終了コードを返す
    exit $script:ExitCode
}



