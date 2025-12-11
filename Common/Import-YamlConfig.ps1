<#
.SYNOPSIS
    YAML設定ファイルを読み込み、オブジェクトに変換します。

.DESCRIPTION
    Import-YamlConfig 関数は、指定されたYAMLファイルを読み込み、
    PowerShellで扱えるOrderedDictionaryオブジェクトに変換します。
    
    前提条件:
    - PowerShell-Yaml モジュール (0.4.7以上) がインストールされている必要があります

.PARAMETER YamlPath
    読み込むYAMLファイルのパスを指定します。相対パスまたは絶対パスが可能です。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ファイルが存在する必要があります
    - ファイルが読み取り可能である必要があります

.EXAMPLE
    # YAML設定ファイルを読み込む
    $config = Import-YamlConfig -YamlPath ".\config.yaml"
    Write-Host "環境: $($config.Environment)"

.EXAMPLE
    # 絶対パスを指定
    $config = Import-YamlConfig -YamlPath "C:\Config\EnvDEV.yaml"
    $config.GetEnumerator() | ForEach-Object {
        Write-Host "$($_.Key): $($_.Value)"
    }

.EXAMPLE
    # エラーハンドリング付き
    try {
        $config = Import-YamlConfig -YamlPath ".\settings.yaml"
    }
    catch {
        Write-Error "設定ファイルの読み込みに失敗しました: $_"
        exit 1
    }

.OUTPUTS
    [System.Collections.Specialized.OrderedDictionary] YAML設定のオブジェクト

.FUNCTIONALITY
    YAML設定ファイルの読み込みとオブジェクト変換

.NOTES
    File Name      : Import-YamlConfig.ps1
    Author         : UMA68
    Version        : 1.1.0
    Release Date   : 2025-12-11
    Prerequisite   : PowerShell 5.1 以上, PowerShell-Yaml 0.4.7 以上
    
    変更履歴:
    v1.1.0 (2025-12-11)
        - 到達不可能なコード（Mutex イベント登録）を削除
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - PowerShell-Yaml モジュールの依存チェック追加
        - エラーハンドリングを改善（詳細なエラーメッセージ）
        - Get-Content -Raw 使用に変更（デリミター不要）
        - 戻り値の型を明示（OutputType）
        - Resolve-Path で絶対パス変換
        - ヘルプドキュメント全体を追加
        - スコープ変数管理に対応
        - Write-Verbose によるデバッグ情報追加
    
    v1.0.0 (2025-12-10)
        - 初版リリース

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    PowerShell-Yaml: https://github.com/cloudbase/powershell-yaml
    ConvertFrom-Yaml: https://github.com/cloudbase/powershell-yaml#convertfrom-yaml
#>

function Import-YamlConfig {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$YamlPath       # 読み込むYAMLファイルのパス
    )
    
    begin {
        # PowerShell-Yaml モジュールの存在確認
        if (-not (Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue)) { # モジュールが見つからない場合
            throw "PowerShell-Yaml モジュールが見つかりません。`nインストールしてください: Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7"
        }
        
        # パスのワイルドカード文字チェック
        if ($YamlPath -match '[\*\?]') { # ワイルドカード文字の検出
            Write-Warning "パスにワイルドカード文字が含まれています: $YamlPath"
        }
    }
    
    process {
        try {
            # 絶対パスに変換
            $script:ResolvedPath = Resolve-Path -Path $YamlPath -ErrorAction Stop
            
            # ファイルが存在するか確認
            if (-not (Test-Path -Path $script:ResolvedPath -PathType Leaf)) { # ファイルが存在しない場合
                throw "YAMLファイルが見つかりません: $script:ResolvedPath"
            }
            
            # YAMLファイルを読み込み
            Write-Verbose "YAMLファイルを読み込み中: $script:ResolvedPath"
            
            try {
                $script:YamlContent = Get-Content -Path $script:ResolvedPath -Raw -ErrorAction Stop
            }
            catch [System.UnauthorizedAccessException] {
                throw "YAMLファイルへの読み取りアクセス権がありません: $script:ResolvedPath"
            }
            
            # YAMLをオブジェクトに変換
            try {
                $script:YamlObject = $script:YamlContent | ConvertFrom-Yaml -Ordered
            }
            catch {
                throw "YAML構文エラー: ファイルの形式が正しくありません。`n詳細: $($_.Exception.Message)"
            }
            
            Write-Verbose "YAML読み込み完了。キー数: $($script:YamlObject.Count)"
            
            return $script:YamlObject
        }
        catch {
            $errorMessage = "YAMLファイルの読み込みに失敗しました。`nパス: $YamlPath`n詳細: $($_.Exception.Message)"
            Write-Error $errorMessage -ErrorAction Stop
        }
    }
}