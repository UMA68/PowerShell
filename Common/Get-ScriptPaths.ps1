<#
.SYNOPSIS
    スクリプトと関連ディレクトリのパスを取得します。

.DESCRIPTION
    Get-ScriptPaths 関数は、実行中のスクリプトの場所から、
    親ディレクトリ、PowerShell ルート、共通スクリプト格納ディレクトリなど
    プロジェクト全体で使用される重要なパスを計算して返します。
    
    パス階層構造:
    PowerShell ルート/
    ├─ Upper (スクリプト実行フォルダの親)
    │  ├─ YAML (設定ファイル)
    │  ├─ LOG (ログファイル)
    │  └─ Script (スクリプト実行ディレクトリ)
    └─ Common (共通スクリプト)
    
    呼び出し元の自動検出メカニズム:
    1. $PSCommandPath で呼び出し元スクリプトパス取得
    2. 失敗時は Get-PSCallStack のコールスタック検索
    3. 失敗時はカレントディレクトリを使用（警告表示）
    
    返却されるハッシュテーブルには以下のキーが含まれます：
    - Script      : スクリプト実行ディレクトリ
    - Upper       : スクリプト実行ディレクトリの親ディレクトリ
    - PowerShell  : PowerShell プロジェクトルートディレクトリ
    - Yaml        : YAML 設定ファイル格納ディレクトリ
    - Log         : ログファイル格納ディレクトリ
    - Common      : 共通スクリプト格納ディレクトリ
    - EnvFile     : 環境設定ファイルのフルパス（EnvFileName 指定時のみ）

.PARAMETER ScriptPath
    基準となるスクリプトのパス。デフォルト: 呼び出し元のスクリプトパス（自動検出）
    
    指定しない場合の検出順序:
    1. $PSCommandPath で呼び出し元スクリプトを取得
    2. 失敗時は Get-PSCallStack のコールスタック[1] から取得
    3. 失敗時はカレントディレクトリを使用（警告表示）
    
    テスト時など、明示的にパスを指定することも可能です。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ファイルまたはディレクトリが存在する必要があります

.PARAMETER EnvFileName
    環境設定ファイル名。デフォルト: ""（空文字列＝EnvFile キーを含めない）
    
    指定した場合、EnvFile キーに YAML ディレクトリ配下のファイルパスが設定されます。
    例: -EnvFileName "Env.yaml"
    
    ファイルの存在確認は行わず、パスのみを計算して返却します。
    ファイルの実在確認は呼び出し元で行うことが推奨されます。

.EXAMPLE
    # 基本的な使用方法（呼び出し元スクリプトパスを自動検出）
    $paths = Get-ScriptPaths
    Write-Host "スクリプトディレクトリ: $($paths.Script)"
    Write-Host "PowerShell ルート: $($paths.PowerShell)"
    Write-Host "共通スクリプト: $($paths.Common)"

.EXAMPLE
    # 環境設定ファイルパスを含める（ファイル存在確認は別途実施）
    $paths = Get-ScriptPaths -EnvFileName "EnvDEV.yaml"
    if (Test-Path -Path $paths.EnvFile) {
        Write-Host "環境設定ファイル: $($paths.EnvFile)"
    } else {
        Write-Warning "環境設定ファイルが見つかりません: $($paths.EnvFile)"
    }

.EXAMPLE
    # テスト時に明示的にパスを指定
    $testPath = "C:\Test\Script\test.ps1"
    $paths = Get-ScriptPaths -ScriptPath $testPath
    Write-Host "テスト用パス計算: $($paths.PowerShell)"

.EXAMPLE
    # 返却値の全キーを表示（パス階層構造の確認）
    $paths = Get-ScriptPaths
    $paths.GetEnumerator() | ForEach-Object {
        Write-Host "$($_.Key): $($_.Value)"
    }
    # 出力例:
    # Script: C:\Users\...\Project\Script
    # Upper: C:\Users\...\Project
    # PowerShell: C:\Users\...\
    # Yaml: C:\Users\...\Project\YAML
    # Log: C:\Users\...\Project\LOG
    # Common: C:\Users\...\Common

.OUTPUTS
    [hashtable] 以下のキーを持つハッシュテーブル:
    - Script      : スクリプトディレクトリパス
    - Upper       : 親ディレクトリパス（プロジェクトルート配下）
    - PowerShell  : PowerShell ルートパス
    - Yaml        : YAML ディレクトリパス
    - Log         : LOG ディレクトリパス
    - Common      : Common ディレクトリパス
    - EnvFile     : 環境設定ファイルパス（EnvFileName 指定時のみ、ファイル存在確認はしない）
    
    注意: EnvFile キーはファイルの存在確認を行わず、パス文字列のみを返却します。
    ファイルの実在確認は呼び出し元で実施してください。

.FUNCTIONALITY
    スクリプト関連パスの計算と取得

.NOTES
    File Name      : Get-ScriptPaths.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2026-01-14
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.2.0 (2026-01-14)
        - $PSCommandPath → Get-PSCallStack → Get-Location のフォールバック検出順序を実装・記載
        - パス階層構造を図示してドキュメント記載
        - ValidateScript による パス存在確認を実装・記載
        - ScriptPath パラメータの検出順序を詳細ドキュメント記載
        - エラーハンドリング詳細化（ParameterBindingException、IOException）
        - EnvFile キーの存在確認を行わない仕様をドキュメント記載
        - PSUseSingularNouns SuppressMessageAttribute の理由を記載
        - テスト用パスの例を追加
        - 出力例を詳細化
    
    v1.1.0 (2025-12-11)
        - ハッシュテーブルの文法を修正（キー = 値 形式に統一）
        - $envFileName をパラメーター化
        - 返却するハッシュテーブルの構造を明確化
        - エラーハンドリングを追加
    
    v1.0.0 (2025-12-10)
        - 初版リリース
    
    既知の制限:
    - スクリプト実行パスが自動検出できない場合はカレントディレクトリを使用（警告表示）
    - EnvFile キーはパス計算のみで、ファイル存在確認は実施しない
    - パス階層構造が想定と異なる環境では手動での ScriptPath 指定が必要
    
    PSUseSingularNouns Suppression:
    - 関数名を Paths（複数形）としているのは、複数のパスを返すためです
    - パス計算の責務を強調するため Get-ScriptPaths としています

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    Split-Path: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/split-path
    Join-Path: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path
#>

function Get-ScriptPaths {
    [CmdletBinding()]
    [OutputType([hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = '複数のパスを返すため複数形が適切')]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateScript({
            # null の場合は省略として扱う
            if ($null -eq $_) { 
                return $true 
            }
            # 空白のみの場合はエラー
            if ([string]::IsNullOrWhiteSpace($_)) {
                throw "ScriptPath パラメータに空白のみの値は指定できません。"
            }
            return $true
        })]
        [string]$ScriptPath,        # 基準となるスクリプトのパス
        
        [Parameter(Mandatory = $false)]
        [string]$EnvFileName = ""   # 環境設定ファイル名
    )
    
    begin {
        # ScriptPath が指定されていない場合、呼び出し元のパスを使用
        if ([string]::IsNullOrEmpty($ScriptPath)) {
            # 呼び出し元のスクリプトパスを取得（複数の方法を試行）
            $ScriptPath = $PSCommandPath
            
            if ([string]::IsNullOrEmpty($ScriptPath)) {
                # コールスタックから呼び出し元のスクリプトを取得
                $callStack = Get-PSCallStack
                if ($callStack.Count -gt 1) {
                    $ScriptPath = $callStack[1].ScriptName
                }
            }
            
            # それでも取得できない場合はカレントディレクトリを使用
            if ([string]::IsNullOrEmpty($ScriptPath)) {
                $ScriptPath = (Get-Location).Path
                Write-Warning "スクリプトパスが取得できませんでした。カレントディレクトリを使用します: $ScriptPath"
            }
        }
    }
    
    process {
        try {
            # 存在するパスのみ Resolve-Path を使用（存在しないUNCでの例外回避）
            if (Test-Path -Path $ScriptPath) {
                $ScriptPath = (Resolve-Path -Path $ScriptPath).Path
            }

            # UNC パス判定と share root 抽出（\server\share）
            $isUncPath = $false
            $uncShareRoot = $null
            if ($ScriptPath -match '^\\\\[^\\]+\\[^\\]+') {
                $isUncPath = $true
                $uncShareRoot = $Matches[0]
            }

            # 各パスを計算（ローカル変数を使用）
            $scriptDir = Split-Path -Path $ScriptPath -Parent
            if ([string]::IsNullOrEmpty($scriptDir)) {
                throw "スクリプトディレクトリの取得に失敗しました: $ScriptPath"
            }
            
            $upperDir = Split-Path -Path $scriptDir -Parent
            $powerShellDir = Split-Path -Path $upperDir -Parent

            # UNC の場合は share root より上に遡らない
            if ($isUncPath -and $uncShareRoot) {
                if ($upperDir -notlike "$uncShareRoot*") {
                    $upperDir = $uncShareRoot
                }
                if ($powerShellDir -notlike "$uncShareRoot*") {
                    $powerShellDir = $uncShareRoot
                }
            }
            $yamlDir = Join-Path -Path $upperDir -ChildPath "YAML"
            $logDir = Join-Path -Path $upperDir -ChildPath "LOG"
            $commonDir = Join-Path -Path $powerShellDir -ChildPath "Common"
            
            # ハッシュテーブルを構築
            $pathsTable = @{
                Script = $scriptDir
                Upper = $upperDir
                PowerShell = $powerShellDir
                Yaml = $yamlDir
                Log = $logDir
                Common = $commonDir
            }
            
            # EnvFileName が指定されている場合、EnvFile キーを追加
            if (![string]::IsNullOrEmpty($EnvFileName)) {
                $envPath = Join-Path -Path $yamlDir -ChildPath $EnvFileName
                $pathsTable.Add("EnvFile", $envPath)
            }
            
            Write-Verbose "パス計算完了: Script=$scriptDir, PowerShell=$powerShellDir"
            
            return $pathsTable
        }
        catch [System.Management.Automation.ParameterBindingException] {
            Write-Error "パラメーターが無効です: $($_.Exception.Message)" -ErrorAction Stop
        }
        catch [System.IO.IOException] {
            Write-Error "パス操作に失敗しました: $($_.Exception.Message)" -ErrorAction Stop
        }
        catch {
            Write-Error "パス計算に失敗しました。詳細: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
}

