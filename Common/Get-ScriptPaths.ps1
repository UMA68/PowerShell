<#
.SYNOPSIS
    スクリプトと関連ディレクトリのパスを取得します。

.DESCRIPTION
    Get-ScriptPaths 関数は、実行中のスクリプトの場所から、
    親ディレクトリ、PowerShell ルート、共通スクリプト格納ディレクトリなど
    プロジェクト全体で使用される重要なパスを計算して返します。
    
    返却されるハッシュテーブルには以下のキーが含まれます：
    - Script      : スクリプト実行ディレクトリ
    - Upper       : スクリプト実行ディレクトリの親ディレクトリ
    - PowerShell  : PowerShell プロジェクトルートディレクトリ
    - Yaml        : YAML 設定ファイル格納ディレクトリ
    - Log         : ログファイル格納ディレクトリ
    - Common      : 共通スクリプト格納ディレクトリ
    - EnvFile     : 環境設定ファイルのフルパス（オプション）

.PARAMETER ScriptPath
    基準となるスクリプトのパス。デフォルト: 呼び出し元のスクリプトパス
    
    このパラメーターは通常、自動的に $MyInvocation.MyCommand.Path が設定されます。
    テスト時など、明示的にパスを指定することも可能です。

.PARAMETER EnvFileName
    環境設定ファイル名。デフォルト: ""（空文字列＝EnvFile キーを含めない）
    
    指定した場合、EnvFile キーに YAML ディレクトリ配下のファイルパスが設定されます。
    例: -EnvFileName "Env.yaml"

.EXAMPLE
    # 基本的な使用方法
    $paths = Get-ScriptPaths
    Write-Host "スクリプトディレクトリ: $($paths.Script)"
    Write-Host "PowerShell ルート: $($paths.PowerShell)"
    Write-Host "共通スクリプト: $($paths.Common)"

.EXAMPLE
    # 環境設定ファイルパスを含める
    $paths = Get-ScriptPaths -EnvFileName "EnvDEV.yaml"
    Write-Host "環境設定ファイル: $($paths.EnvFile)"

.EXAMPLE
    # 返却値の全キーを表示
    $paths = Get-ScriptPaths
    $paths.GetEnumerator() | ForEach-Object {
        Write-Host "$($_.Key): $($_.Value)"
    }

.OUTPUTS
    [hashtable] 以下のキーを持つハッシュテーブル:
    - Script      : スクリプトディレクトリパス
    - Upper       : 親ディレクトリパス
    - PowerShell  : PowerShell ルートパス
    - Yaml        : YAML ディレクトリパス
    - Log         : LOG ディレクトリパス
    - Common      : Common ディレクトリパス
    - EnvFile     : 環境設定ファイルパス（EnvFileName 指定時のみ）

.FUNCTIONALITY
    スクリプト関連パスの計算と取得

.NOTES
    File Name      : Get-ScriptPaths.ps1
    Author         : UMA68
    Version        : 1.1.0
    Release Date   : 2025-12-11
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.1.0 (2025-12-11)
        - ハッシュテーブルの文法を修正（キー = 値 形式に統一）
        - 到達不可能なコード（Mutex イベント登録）を削除
        - $envFileName をパラメーター化
        - ヘルプドキュメント全体を追加
        - 返却するハッシュテーブルの構造を明確化
        - エラーハンドリングを追加
        - スコープ変数管理に対応
        - 単一責務（パス計算のみ）に特化
        - 古いコメント化コードを削除
    
    v1.0.0 (2025-12-10)
        - 初版リリース

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    Split-Path: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/split-path
    Join-Path: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path
#>

function Get-ScriptPaths {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ScriptPath,        # 基準となるスクリプトのパス
        
        [Parameter(Mandatory=$false)]
        [string]$EnvFileName = ""   # 環境設定ファイル名
    )
    
    begin {
        # ScriptPath が指定されていない場合、呼び出し元のパスを使用
        if ([string]::IsNullOrEmpty($ScriptPath)) { # ScriptPath が空の場合
            # $MyInvocation.MyCommand.Path は関数内では関数自体を指すため、
            # 呼び出し元のスクリプトパスを取得するには PSCommandPath を使用
            $ScriptPath = $PSCommandPath
            
            # PSCommandPath が空の場合（対話的実行など）は、カレントディレクトリを使用
            if ([string]::IsNullOrEmpty($ScriptPath)) { # 依然として空の場合
                $ScriptPath = (Get-Location).Path
                Write-Warning "スクリプトパスが取得できませんでした。カレントディレクトリを使用します: $ScriptPath"
            }
        }
    }
    
    process {
        try {
            # 各パスを計算
            $script:ScriptDir = Split-Path -Path $ScriptPath -Parent                        # スクリプト実行ディレクトリ
            $script:UpperDir = Split-Path -Path $script:ScriptDir -Parent                   # 親ディレクトリ
            $script:PowerShellDir = Split-Path -Path $script:UpperDir -Parent               # PowerShell ルートディレクトリ
            $script:YamlDir = Join-Path -Path $script:UpperDir -ChildPath "YAML"            # YAML ディレクトリ
            $script:LogDir = Join-Path -Path $script:UpperDir -ChildPath "LOG"              # LOG ディレクトリ
            $script:CommonDir = Join-Path -Path $script:PowerShellDir -ChildPath "Common"   # Common ディレクトリ
            
            # ハッシュテーブルを構築
            $script:PathsTable = @{ # ハッシュテーブル初期化
                Script      = $script:ScriptDir
                Upper       = $script:UpperDir
                PowerShell  = $script:PowerShellDir
                Yaml        = $script:YamlDir
                Log         = $script:LogDir
                Common      = $script:CommonDir
            }
            
            # EnvFileName が指定されている場合、EnvFile キーを追加
            if (-not [string]::IsNullOrEmpty($EnvFileName)) { # EnvFileName が空でない場合
                $script:EnvPath = Join-Path -Path $script:YamlDir -ChildPath $EnvFileName
                $script:PathsTable.Add("EnvFile", $script:EnvPath)
            }
            
            Write-Verbose "パス計算完了: Script=$($script:ScriptDir), PowerShell=$($script:PowerShellDir)"
            
            return $script:PathsTable
        }
        catch {
            Write-Error "パス計算に失敗しました。詳細: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
}

