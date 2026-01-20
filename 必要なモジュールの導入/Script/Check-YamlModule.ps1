<#
.SYNOPSIS
    powershell-yaml モジュールの存在確認とインストールを行う関数

.DESCRIPTION
    Test-YamlModule 関数は、指定されたバージョンの powershell-yaml モジュールが
    既にインストールされているかを確認します。
    
    指定バージョンが存在しない場合は、自動的にインストールを実行します。
    このモジュールはYAML設定ファイルの読み込みに必須です。
    
    主な処理フロー：
    1. 指定バージョンのモジュール存在確認
    2. 存在しない場合はユーザーに通知
    3. PowerShell Gallery からインストール
    4. インストール結果をログに記録
    5. エラー時は処理を中断

.PARAMETER Ver
    インストールまたは確認する powershell-yaml モジュールのバージョンを指定します。
    
    デフォルト値: 0.4.7
    形式: x.x.x（例: 0.4.7, 0.4.6）
    
    指定されたバージョンが存在しない場合、PowerShell Gallery からダウンロードされます。

.EXAMPLE
    Test-YamlModule
    
    説明:
    デフォルトバージョン（0.4.7）の powershell-yaml モジュールを確認します。
    存在しない場合は自動的にインストールされます。

.EXAMPLE
    Test-YamlModule -Ver '0.4.6'
    
    説明:
    バージョン 0.4.6 の powershell-yaml モジュールを確認します。
    指定バージョンが存在しない場合はインストールされます。

.EXAMPLE
    $result = Test-YamlModule -Ver '0.4.7'
    if ($result) {
        Write-Host "モジュール準備完了"
    }
    
    説明:
    戻り値を使用して、モジュールの準備状況を確認する例。

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    System.Boolean
    インストール成功時は $true、失敗時は処理を終了します。

.NOTES
    ファイル名: Check-YamlModule.ps1
    作成者: UMA68
    バージョン: 1.1.0
    作成日: 2025-12-09
    最終更新: 2026-01-20
    
    前提条件:
    - インターネット接続（PowerShell Gallery へのアクセス）
    - 管理者権限（モジュールインストール時に必要な場合あり）
    
    依存関係:
    - Write-CommonLog 関数（ログ記録用）
    - $script:Log 変数（ログファイルパス）
    - $script:ShowInConsoleFlag 変数（コンソール冗長出力制御）
    
    動作仕様:
    - 特定バージョンの存在を確認（複数バージョン対応）
    - インストール済みの場合は何もしない
    - 未インストールの場合は指定バージョンをインストール
    - エラー時はポップアップで通知して処理終了
    - $script:ShowInConsoleFlag が真の場合のみコンソールへ出力
    
    モジュール情報:
    - 正式名称: powershell-yaml
    - リポジトリ: PowerShell Gallery
    - 用途: YAML ファイルの読み込み・変換
    
    変更履歴:
    v1.1.0 (2026-01-20)
        - $script:ShowInConsoleFlag を使用したコンソール出力制御に対応
        - Write-CommonLog の -Quiet パラメータを動的に制御
        - ScriptAnalyzer 対応の修正
    
    v1.0.0 (2025-12-09)
        - 初版リリース

.LINK
    https://www.powershellgallery.com/packages/powershell-yaml
    
.LINK
    Install-Module
    Get-Module

#>

function Test-YamlModule {
    Param(
        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$Ver = '0.4.7'
    )
    
    # ====================================
    # 指定バージョンの存在確認
    # ====================================
    # 特定バージョンのモジュールが既にインストールされているかチェック
    $existingModule = Get-Module -ListAvailable -Name "powershell-yaml" | 
                      Where-Object { $_.Version -eq $Ver }
    
    if ($null -eq $existingModule) { # 指定バージョンのモジュールが存在しない場合
        # ====================================
        # モジュール未インストール - インストール処理
        # ====================================
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup("powershell-yaml $Ver がインストールされていません。`r`nインストールを開始します。", 0, "情報", 0x40) | Out-Null
            
            # PowerShell Gallery からモジュールをインストール
            Install-Module -Name "powershell-yaml" -RequiredVersion $Ver -Force -Scope CurrentUser -ErrorAction Stop
            
            # インストール成功をログに記録
            if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
                $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
                Write-CommonLog -Message "[INSTALL] powershell-yaml $Ver をインストールしました" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
            }
            
            # 成功通知
            $obj.Popup("powershell-yaml $Ver のインストールが完了しました。", 0, "完了", 0x40) | Out-Null
            return $true
            
        } catch {
            # インストール失敗時の処理
            if ($null -ne $obj) { # COMオブジェクトが存在する場合
                $obj.Popup("powershell-yaml のインストールに失敗しました。処理を終了します。`r`n`r`nエラー: " + $_.Exception.Message, 0, "エラー", 0x30) | Out-Null
            }
            exit
        } finally {
            # COM オブジェクトのクリーンアップ
            if ($null -ne $obj) { # COMオブジェクトが存在する場合
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
                $obj = $null
            }
        }
        
    } else { # モジュール既にインストール済み
        # ====================================
        # モジュール既にインストール済み
        # ====================================
        # インストール済みバージョン情報をログに記録
        if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
            $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
            Write-CommonLog -Message "[EXIST] powershell-yaml $Ver は既にインストールされています" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
        }
        return $true
    }
}
