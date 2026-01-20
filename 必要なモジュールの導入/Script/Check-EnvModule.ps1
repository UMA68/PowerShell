<#
.SYNOPSIS
    指定されたPowerShellモジュールの存在確認と自動インストール関数

.DESCRIPTION
    Test-EnvModule 関数は、指定されたモジュールが要求されたバージョンでインストール
    されているかを確認します。
    
    指定バージョンが存在しない場合は、自動的にPowerShell Galleryからインストールします。
    既に同じバージョンがインストール済みの場合は何もしません。
    異なるバージョンが存在する場合は、指定バージョンを追加でインストールします。
    
    主な処理フロー：
    1. 指定モジュールと指定バージョンの存在確認
    2. 同じバージョンが見つかった場合は処理終了
    3. 見つからない場合はユーザーに通知
    4. PowerShell Gallery からインストール実行
    5. インストール結果をログに記録

.PARAMETER ModuleName
    確認またはインストールするモジュールの正式名称を指定します（必須）。
    
    PowerShell Gallery での登録名と完全一致させてください。
    例: SqlServer, ImportExcel, Az
    
.PARAMETER ModuleVersion
    インストールまたは確認するモジュールのバージョンを指定します（必須）。
    
    形式: x.x.x （例: 22.1.1, 7.8.5）
    指定バージョンが存在しない場合は新規インストールされます。

.EXAMPLE
    Test-EnvModule -ModuleName "SqlServer" -ModuleVersion "22.1.1"
    
    説明:
    SqlServer モジュール（バージョン 22.1.1）の存在を確認します。
    存在しない場合はインストールされます。

.EXAMPLE
    Test-EnvModule -ModuleName "ImportExcel" -ModuleVersion "7.8.5"
    
    説明:
    ImportExcel モジュール（バージョン 7.8.5）の存在を確認します。

.EXAMPLE
    $modules = @(
        @{Name="SqlServer"; Version="22.1.1"},
        @{Name="ImportExcel"; Version="7.8.5"}
    )
    $modules | ForEach-Object {
        Test-EnvModule -ModuleName $_.Name -ModuleVersion $_.Version
    }
    
    説明:
    複数のモジュールをループで確認・インストールする例。

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    System.Boolean
    インストール成功時は $true を返します。
    エラー時は処理を中断します。

.NOTES
    ファイル名: Check-EnvModule.ps1
    作成者: UMA68
    バージョン: 1.1.0
    作成日: 2025-12-09
    最終更新: 2026-01-20
    
    前提条件:
    - インターネット接続（PowerShell Gallery へのアクセス）
    - Write-CommonLog 関数（ログ記録用）
    - $script:Log 変数（ログファイルパス）
    
    依存関係:
    - $script:ShowInConsoleFlag 変数（コンソール冗長出力制御）
    
    動作仕様:
    - 指定バージョンの存在を確認
    - 複数バージョンが存在する場合は全て認識
    - 指定バージョンのみインストール
    - Scope: CurrentUser（管理者権限不要）
    - $script:ShowInConsoleFlag が真の場合のみコンソールへ出力
    
    ログレベル:
    [EXIST]   : 指定バージョンが既にインストール済み
    [OTHER]   : 異なるバージョンが存在（追加インストール対象外）
    [NOTHING] : モジュール自体が存在しない
    [INSTALL] : モジュールをインストール中
    [ERROR]   : モジュールのインストール失敗
    
    エラーハンドリング:
    - インストール失敗時はエラー情報をログに記録
    - ユーザーにエラーダイアログで通知
    - 処理は中断（exit）
    
    変更履歴:
    v1.1.0 (2026-01-20)
        - $script:ShowInConsoleFlag を使用したコンソール出力制御に対応
        - Write-CommonLog の -Quiet パラメータを動的に制御
        - ScriptAnalyzer 対応の修正（空のcatchブロック、スペース修正）
    
    v1.0.0 (2025-12-09)
        - 初版リリース

.LINK
    https://www.powershellgallery.com/

.LINK
    Install-Module
    Get-Module

#>

function Test-EnvModule {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$ModuleVersion
    )

    # ====================================
    # モジュールの存在確認
    # ====================================
    # 指定モジュールが1つ以上インストールされているか確認
    $installedModules = Get-Module -ListAvailable -Name $ModuleName
    $isVersionFound = $false

    if ($null -ne $installedModules) { # モジュール自体が存在する場合
        # ====================================
        # 指定バージョンの確認
        # ====================================
        # 複数バージョンが存在する可能性があるため、全て確認
        if ($installedModules -is [array]) { # 複数バージョン存在時
            # 複数バージョン存在時
            foreach ($module in $installedModules) { # 各バージョンを確認
                if ($module.Version.ToString() -eq $ModuleVersion) { # 指定バージョンが見つかった場合
                    # 指定バージョンが見つかった場合
                    $isVersionFound = $true
                    if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
                        $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
                        Write-CommonLog -Message "[EXIST] $ModuleName Version: $($module.Version.ToString())" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
                    }
                } else { # 異なるバージョンが存在
                    # 異なるバージョンが存在
                    if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
                        $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
                        Write-CommonLog -Message "[OTHER] $ModuleName Version: $($module.Version.ToString())" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
                    }
                }
            }
        } else { # 単一バージョンのみ存在時
            # 単一バージョンのみ存在時
            if ($installedModules.Version.ToString() -eq $ModuleVersion) { # 指定バージョンが見つかった場合
                $isVersionFound = $true
                if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
                    $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
                    Write-CommonLog -Message "[EXIST] $ModuleName Version: $($installedModules.Version.ToString())" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
                }
            } else { # 異なるバージョンが存在
                if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
                    $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
                    Write-CommonLog -Message "[OTHER] $ModuleName Version: $($installedModules.Version.ToString())" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
                }
            }
        }
    } else { # モジュール自体が存在しない場合
        # ====================================
        # モジュール自体が存在しない
        # ====================================
        if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
            $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
            Write-CommonLog -Message "[NOTHING] $ModuleName" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
        }
    }

    # ====================================
    # インストール処理
    # ====================================
    # 指定バージョンが存在しない場合はインストール
    if ($isVersionFound -eq $false) { # 指定バージョンが存在しない場合
        if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
            $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
            Write-CommonLog -Message "[INSTALL] $ModuleName Version: $ModuleVersion をインストール中..." -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
        }

        try {
            # PowerShell Gallery からモジュールをインストール
            Install-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -Scope CurrentUser -ErrorAction Stop

            # インストール成功
            if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
                $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
                Write-CommonLog -Message "[INSTALL] $ModuleName Version: $ModuleVersion をインストールしました" -LogPath $script:Log -Level 'INFO' -Quiet:$quietMode
            }
            return $true

        } catch {
            # インストール失敗時の処理
            $errorMsg = $_.Exception.Message
            if (Get-Variable -Name Log -Scope Script -ErrorAction SilentlyContinue) { # Log変数が存在する場合のみログ記録
                $quietMode = -not (Get-Variable -Name ShowInConsoleFlag -Scope Script -ErrorAction SilentlyContinue -ValueOnly)
                Write-CommonLog -Message "[ERROR] $ModuleName のインストールに失敗しました。エラー: $errorMsg" -LogPath $script:Log -Level 'ERROR' -Quiet:$quietMode
            }

            # エラーダイアログを表示
            $obj = $null
            try {
                $obj = New-Object -ComObject WScript.Shell
                $obj.Popup("$ModuleName のインストールに失敗しました。`r`n処理を終了します。`r`n`r`nエラー: $errorMsg", 0, "エラー", 0x30) | Out-Null
            } finally {
                if ($null -ne $obj) { # COMオブジェクトが存在する場合
                    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
                    $obj = $null
                }
            }
            exit
        }
    } else { # 指定バージョンが既に存在する場合
        return $true
    }
}
