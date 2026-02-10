<#
.SYNOPSIS
    YAML設定ファイルを読み込み、オブジェクトに変換します。

.DESCRIPTION
    Import-YamlConfig 関数は、指定されたYAMLファイルを読み込み、
    PowerShellで扱えるOrderedDictionaryオブジェクトに変換します。
    
    前提条件:
    - PowerShell 5.1 以上
    - PowerShell-Yaml モジュール (0.4.7以上) がインストールされている必要があります
      インストール: Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Force
    
    パラメーター検証時に実行される確認:
    - PowerShell-Yaml モジュールの存在（ConvertFrom-Yaml コマンドレット）
    - YAMLファイルの存在（ファイル）
    - YAMLファイルの読み取り可能性
    - パスのワイルドカード文字検出（警告のみ）

.PARAMETER YamlPath
    読み込むYAMLファイルのパスを指定します。相対パスまたは絶対パスが可能です。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ファイルが存在する必要があります（Test-Path -PathType Leaf）
    - PowerShell-Yaml モジュールがインストール済みである必要があります
    - ワイルドカード文字（* ?）が含まれていないか確認（警告のみ）
    
    ファイルエンコーディング: UTF-8 を前提としています

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
    # 空の YAML または null の場合
    $config = Import-YamlConfig -YamlPath ".\empty.yaml"
    if ($null -eq $config) {
        Write-Host "YAMLファイルが空または無効です"
    }

.EXAMPLE
    # エラーハンドリング付き（PowerShell-Yaml 未インストール）
    try {
        $config = Import-YamlConfig -YamlPath ".\settings.yaml"
    }
    catch [System.Management.Automation.ValidationMetadataException] {
        Write-Error "PowerShell-Yaml モジュールをインストールしてください"
        exit 1
    }

.EXAMPLE
    # エラーハンドリング付き（ファイルアクセス権）
    try {
        $config = Import-YamlConfig -YamlPath ".\settings.yaml"
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "ファイルへのアクセス権がありません。管理者権限が必要です"
        exit 1
    }

.OUTPUTS
    [System.Collections.Specialized.OrderedDictionary] YAML設定のオブジェクト
    
    注意: YAMLファイルが空または無効な場合は $null が返される可能性があります

.FUNCTIONALITY
    YAML設定ファイルの読み込みとオブジェクト変換

.NOTES
    File Name      : Import-YamlConfig.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2026-01-14
    Prerequisite   : PowerShell 5.1 以上, PowerShell-Yaml 0.4.7 以上
    
    変更履歴:
    v1.2.0 (2026-01-14)
        - ValidateScript により詳細なパラメーター検証を統一実装
        - エラーハンドリングを詳細化（UnauthorizedAccessException、FileNotFoundException、IOException の個別処理）
        - YAML 構文エラー時の例外処理を追加
        - PowerShell-Yaml モジュールインストール方法をドキュメント記載
        - ワイルドカード文字検出についてドキュメント記載
        - 空/無効な YAML 返却時の $null 返却をドキュメント記載
        - UTF-8 エンコーディング明示化
        - -Ordered フラグの用途をドキュメント記載
        - エラーハンドリング例を充実
    
    v1.1.0 (2025-12-11)
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - PowerShell-Yaml モジュールの依存チェック追加
        - エラーハンドリングを改善（詳細なエラーメッセージ）
        - Get-Content -Raw 使用に変更（デリミター不要）
        - 戻り値の型を明示（OutputType）
        - Resolve-Path で絶対パス変換
    
    v1.0.0 (2025-12-10)
        - 初版リリース
    
    既知の制限:
    - UTF-8 以外のエンコーディング（SHIFT_JIS など）は別途処理が必要
    - 超大規模 YAML ファイル（数百 MB）はメモリ効率を考慮した外部ツール推奨
    - YAML 構文エラー時は ConvertFrom-Yaml からの例外メッセージに依存

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    PowerShell-Yaml: https://github.com/cloudbase/powershell-yaml
    ConvertFrom-Yaml: https://github.com/cloudbase/powershell-yaml#convertfrom-yaml
#>

function Import-YamlConfig {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                # PowerShell-Yaml モジュールの存在確認
                if (!(Get-Command -Name ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
                    throw "PowerShell-Yaml モジュールが見つかりません。Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7"
                }
                
                # ファイルの存在確認
                if (!(Test-Path -Path $_ -PathType Leaf)) {
                    throw "YAMLファイルが見つかりません: $_"
                }
                
                # ワイルドカード文字チェック
                if ($_ -match '[\*\?]') {
                    Write-Warning "パスにワイルドカード文字が含まれています: $_"
                }
                
                $true
            })]
        [string]$YamlPath       # 読み込むYAMLファイルのパス
    )
    
    process {
        try {
            # 絶対パスに変換
            $resolvedPath = (Resolve-Path -Path $YamlPath -ErrorAction Stop).Path
            
            # YAMLファイルを読み込み（UTF-8エンコーディングを指定）
            Write-Verbose "YAMLファイルを読み込み中: $resolvedPath"
            $yamlContent = Get-Content -Path $resolvedPath -Raw -Encoding UTF8 -ErrorAction Stop
            
            # YAMLをオブジェクトに変換
            $yamlObject = $yamlContent | ConvertFrom-Yaml -Ordered
            
            # 変換結果の検証
            if ($null -eq $yamlObject) {
                Write-Warning "YAMLファイルが空であるか、無効な内容です: $resolvedPath"
            }
            
            Write-Verbose "YAML読み込み完了。キー数: $(if ($yamlObject -is [System.Collections.Specialized.OrderedDictionary]) { $yamlObject.Count } else { 'N/A' })"
            
            return $yamlObject
        }
        catch [System.UnauthorizedAccessException] {
            Write-Error "YAMLファイルへの読み取りアクセス権がありません: $YamlPath。管理者権限が必要な可能性があります。" -ErrorAction Stop
        }
        catch [System.IO.FileNotFoundException] {
            Write-Error "YAMLファイルが見つかりません: $YamlPath" -ErrorAction Stop
        }
        catch [System.IO.IOException] {
            Write-Error "YAMLファイルの読み込み中にI/Oエラーが発生しました: $($_.Exception.Message)" -ErrorAction Stop
        }
        catch {
            # YAML構文エラーやその他のエラー
            $errorMessage = "YAMLファイルの処理に失敗しました。パス: $YamlPath`n詳細: $($_.Exception.Message)"
            Write-Error $errorMessage -ErrorAction Stop
        }
    }
}