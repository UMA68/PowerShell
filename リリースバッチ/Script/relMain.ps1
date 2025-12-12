<#
.SYNOPSIS
    リリースバッチ自動化スクリプト - YAML設定に基づいてファイルをリリース先にコピーします

.DESCRIPTION
    このスクリプトは、YAML設定ファイルで定義されたリリースタイプごとに、
    リリース元フォルダからリリース先フォルダへファイルを自動コピーします。
    
    主な機能:
    - 複数のリリースタイプ（TYPE_A, TYPE_B など）をサポート
    - 既存ファイルのバージョニング（タイムスタンプ付きリネーム）
    - 上書きポリシー切替（RenameThenCopy/DeleteThenCopy/SkipIfExists）
    - ファイル操作の再試行機能（回数・待機時間をYAMLで設定）
    - 長パス対応（\\?\プレフィックス、YAMLで有効化）
    - マルチ言語対応メッセージ（日本語/英語）
    - ログファイルの自動生成と機密情報マスキング
    - 複数ユーザーへのログアクセス権限設定（LOG.USERS配列）
    - 二重起動防止機能（早期チェック）
    - ファイルシステムパーミッション管理（ログディレクトリ・ファイル）
    - PowerShellバージョン検証
    - 必須モジュールの自動インポート
    - スクリプトスコープによる一貫した変数管理
    - リリース結果のサマリ出力（コピー/リネーム/削除/失敗件数）

.PARAMETER DecryptionKey
    暗号化用鍵ファイル名。デフォルト値: "Encryption.Key"
    
    注意: 現在このパラメータは未使用です。将来的にリリース設定に機密情報
    （パスワード、APIキーなど）を含める場合の暗号化・復号化機能用に予約されています。
    実装例は SQLクエリー実行/Script/sqlMain.ps1 の復号化処理を参照してください。
    
    パラメータ検証:
    - ファイル名に使用できない文字（\ / : " * ? < > |）を検証
    - 空白文字のみの入力を拒否
    - 最大255文字の長さ制限

.PARAMETER EnvYaml
    環境設定YAMLファイル名。デフォルト値: "EnvDEV.yaml"
    
    有効な値:
    - EnvDEV.yaml   : 開発環境
    - EnvSTG.yaml   : ステージング環境
    - EnvPROD.yaml  : 本番環境
    
    パラメータ検証:
    - .yaml または .yml 拡張子が必須
    - ファイル名に使用できない文字を検証
    - 空白文字のみの入力を拒否
    - 最大255文字の長さ制限

.EXAMPLE
    # デフォルト（DEV環境）で実行
    .\relMain.ps1

.EXAMPLE
    # STG環境で実行
    .\relMain.ps1 -EnvYaml "EnvSTG.yaml"

.EXAMPLE
    # PROD環境で実行
    .\relMain.ps1 -EnvYaml "EnvPROD.yaml"

.EXAMPLE
    # カスタム鍵ファイルを指定（将来の暗号化機能用）
    .\relMain.ps1 -DecryptionKey "CustomKey.key" -EnvYaml "EnvPROD.yaml"

.NOTES
    File Name      : relMain.ps1
    Author         : UMA68
    Version        : 1.3.0
    Release Date   : 2025-12-12
    Last Modified  : 2025-12-12
    
    前提条件:
    - PowerShell 7.3.9 以上
    - PowerShell-Yaml モジュール 0.4.7 以上
    - SqlServer モジュール 22.1.1 以上（YAMLで指定）
    - Windows PowerShell実行ポリシー: RemoteSigned 以上
    
    依存ファイル:
    - Common/FindModule.ps1         : モジュール検索関数
    - Common/NoDoubleActivation.ps1 : 二重起動防止機能
    - Common/Write-CommonLog.ps1    : ログ出力関数（機密情報マスキング対応）
    - Script/CopyItemCustom.ps1     : ファイルコピー処理とリリースルール適用
    - YAML/Env*.yaml                : 環境設定ファイル
    
    ディレクトリ構造:
    PowerShell/
    ├── Common/
    │   ├── Encryption.Key          (暗号化鍵・将来使用予定)
    │   ├── FindModule.ps1
    │   ├── NoDoubleActivation.ps1
    │   └── Write-CommonLog.ps1
    └── リリースバッチ/
        ├── Script/
        │   ├── relMain.ps1         (このファイル)
        │   └── CopyItemCustom.ps1
        ├── YAML/
        │   ├── EnvDEV.yaml
        │   ├── EnvSTG.yaml
        │   └── EnvPROD.yaml
        └── LOG/                     (自動作成)
            └── relMain_YYYYMMDD-HHmmss.log
    
    変更履歴:
    v1.3.0 (2025-12-12)
        - LOG.USERS配列による複数ユーザーへのログアクセス権付与機能
        - ユーザーSID解決時の実行ユーザー重複検出（実行ユーザーとUSERS配列の重複を自動スキップ）
        - 無効なユーザー名の警告ログ出力
        - 上書きポリシー切替機能統合（RenameThenCopy/DeleteThenCopy/SkipIfExists）
        - ファイル操作リトライ機能統合（回数・待機時間をYAMLで設定）
        - 長パス対応機能統合（\\?\プレフィックス、YAMLで有効化）
        - リリース結果サマリ出力統合（コピー/リネーム/削除/失敗件数）
        - CopyItemCustom.ps1 Phase2機能の完全統合
    
    v1.2.0 (2025-12-10)
        - 変数スコープの統一（$script: プレフィックス）
        - パラメータ検証の強化（ValidateScript属性）
        - ログ出力の重複削除（秒数表示を削除、Min:Sec形式のみ）
        - 未使用変数の文書化（$DecryptionKey, $KeyPath）
        - パス結合を Join-Path に統一
        - 全exitポイントでCOMオブジェクト解放
        - ログファイルセキュリティ機能追加（パーミッション設定、機密情報マスキング）
        - 二重起動チェックを begin ブロックに移動（早期チェック）
        - COM オブジェクト管理を関数化（$script:ShowPopup, $script:GetMessage）
        - エラーメッセージ多言語化（YAML定義）
        
    v1.1.0 (2025-12-09)
        - マルチ言語メッセージサポート実装
        - スクリプトブロックによるメッセージ管理
        - ログディレクトリパーミッション管理
        
    v1.0.0 (2025-11-20)
        - 初版リリース
        - 基本的なリリース機能実装

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    Wiki: https://github.com/UMA68/PowerShell/wiki
    スコープガイドライン: ../SCOPE_GUIDELINES.md
#>

# ===================================
# 起動オプション
#  -DecryptionKey   鍵ファイル指定 (現在未使用・将来の暗号化機能用に予約)
#  -EnvYaml         YAMLファイル指定
# ===================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({ # ファイル名の検証
        # ファイル名としての有効性を検証
        if ($_ -match '[\\/:"*?<>|]') { # ファイル名に使用できない文字を検証
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ([string]::IsNullOrWhiteSpace($_)) { # 空白文字のみの入力を拒否
            throw "ファイル名は空にできません"
        }
        if ($_.Length -gt 255) { # 255文字制限
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true
    })]
    [string]$DecryptionKey = "Encryption.Key" , # 暗号化鍵ファイル名（現在未使用・将来の暗号化機能用に予約）
    [Parameter(Mandatory=$false)]
    [ValidateScript({ # YAMLファイル名の検証
        # ファイル名としての有効性を検証（.yaml または .yml 拡張子必須）
        if ($_ -notmatch '\.(yaml|yml)$') { # 拡張子チェック
            throw "YAMLファイルは .yaml または .yml 拡張子である必要があります: $_"
        }
        if ($_ -match '[\\/:"*?<>|]') { # ファイル名に使用できない文字を検証
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ([string]::IsNullOrWhiteSpace($_)) { # 空白文字のみの入力を拒否
            throw "ファイル名は空にできません"
        }
        if ($_.Length -gt 255) { # 255文字制限
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true
    })]
    [string]$EnvYaml = "EnvDEV.yaml"            # DEV環境用:EnvDEV.yaml, STG環境用:EnvSTG.yaml, 本番環境用:EnvPRD.yaml
)
begin{
    # プロセス実行可否フラグ（endブロックの安全なクリーンアップ用）
    $script:CanExecuteProcess = $true
    # エラーメッセージ定数（YAML読み込み前）
    $ErrorMessages = @{ # .NETハッシュテーブル
        ScriptReadError = "I couldn't read the PowerShell file. I'm ending the process."
        ModuleNotInstalled = "Module 'PowerShell-Yaml' is not installed. I'm ending the process."
        ModuleCheckError = "I couldn't execute 'Test-ModuleInstalled'. I'm ending the process."
        YamlReadError = "I couldn't read the YAML file. I'm ending the process."
    }
    
    # スクリプトの実行環境を取得
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $script:UpperPath = Split-Path -Parent $script:ScriptPath                   # スクリプトの親パスを取得
    $script:PowerShellDir = Split-Path -Parent $script:UpperPath                # スクリプトの親パスの親パスを取得
    $script:YamlPath = Join-Path -Path $script:UpperPath -ChildPath "YAML" | Join-Path -ChildPath $EnvYaml   # YAMLファイルのフルパスを取得
    
    # NOTE: 暗号化機能は現在未実装
    # 将来、リリース設定に機密情報（パスワード、APIキーなど）を含める場合、
    # 以下の$KeyPathを使用して暗号化・復号化機能を実装する予定
    # 実装例は sqlMain.ps1 の復号化処理を参照
    # $script:KeyPath = Join-Path -Path $script:PowerShellDir -ChildPath "Common" | Join-Path -ChildPath $DecryptionKey
    
    $script:ComPath = Join-Path -Path $script:PowerShellDir -ChildPath "Common"       # 共通スクリプトのパス

    # ユーザの特定
    $script:User = $env:USERNAME
    $script:HostName = $env:COMPUTERNAME

    # .ps1ファイルの読み込み
    try{
        . (Join-Path -Path $script:PowerShellDir -ChildPath "Common" | Join-Path -ChildPath "FindModule.ps1") -ErrorAction Stop
        . (Join-Path -Path $script:PowerShellDir -ChildPath "Common" | Join-Path -ChildPath "NoDoubleActivation.ps1") -ErrorAction Stop
        . (Join-Path -Path $script:ComPath -ChildPath "Write-CommonLog.ps1") -ErrorAction Stop
        . (Join-Path -Path $script:ScriptPath -ChildPath "CopyItemCustom.ps1") -ErrorAction Stop
    }catch{
        # スクリプトファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($ErrorMessages.ScriptReadError + "`r`n`r`n" + $_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        $obj = $null
        exit # 終了
    }

    # PowerShell-Yamlモジュールがインストールされていなければ、終了
    try {
        if (-not (Test-ModuleInstalled -ModuleName "PowerShell-Yaml")) { # モジュールがインストールされていない場合
            # 警告を表示し終了
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($ErrorMessages.ModuleNotInstalled, 0, "Module Check", 0x30) | Out-Null
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
            exit # 終了
        }
    }
    catch {
        # Test-ModuleInstalledを実行できない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($ErrorMessages.ModuleCheckError + "`r`n`r`n" + $_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        $obj = $null
        exit # 終了
    }

    # YAMLファイルの読み込み
    try{
        # YAMLは-Rawで読み込み、ConvertFrom-Yamlへ渡す
        $script:Yaml = Get-Content -Path $script:YamlPath -Raw -ErrorAction Stop | ConvertFrom-Yaml -Ordered -ErrorAction Stop
    }catch{
        # YAMLファイルが読めない場合は警告を表示し終了
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($ErrorMessages.YamlReadError + "`r`n`r`n" + $_.Exception.Message, 0, "Module Check", 0x30) | Out-Null
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
        $obj = $null
        exit # 終了
    }
    
    # 機密情報パターンを読み込む
    $script:SensitivePatterns = @()
    if ($script:Yaml.SECURITY -and $script:Yaml.SECURITY.SensitivePatterns) { # 機密情報パターンが定義されている場合
        $script:SensitivePatterns = $script:Yaml.SECURITY.SensitivePatterns
    }
    
    # COM オブジェクト（WScript.Shell）を安全に管理するヘルパー関数
    $script:ShowPopup = { # ポップアップ表示関数
        param(
            [string]$Message,               # 表示メッセージ
            [int]$Buttons = 0,              # ボタンとアイコンの組み合わせ（WScript.Popupの仕様に準拠）
            [string]$Title = "Information"  # ウィンドウタイトル
        )
        $obj = New-Object -ComObject WScript.Shell
        try {
            return [int]$obj.Popup($Message, 0, $Title, $Buttons)
        } finally {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
    }

    # メッセージ取得関数（YAMLから言語に応じたメッセージを取得）
    $script:GetMessage = {
        param(
            [string]$Key    # メッセージキー
        )
        # スクリプトブロックの可変長引数は$argsに入る
        $Arguments = $args
        $script:Lang = $script:Yaml.MESSAGES.LANGUAGE
        $script:Message = $script:Yaml.MESSAGES.$script:Lang.$Key
        
        # メッセージがない場合はキーをそのまま返す
        if ([string]::IsNullOrEmpty($script:Message)) { # メッセージが存在しない場合
            return $Key
        }
        
        # YAMLのエスケープシーケンスを実際の改行に変換
        $script:Message = $script:Message.Replace('\r\n', "`r`n").Replace('\n', "`n")
        
        # 引数があれば、文字列をフォーマット
        if ($Arguments -and $Arguments.Count -gt 0) { # 引数がある場合
            try {
                return ($script:Message -f $Arguments)
            } catch {
                return $script:Message
            }
        }
        
        return $script:Message
    }

    # ログの定義
    $script:LogPath = Join-Path -Path $script:Yaml.LOG.PATH -ChildPath ($script:Yaml.LOG.FILENAME+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+$script:Yaml.LOG.EXTENSION) # ログの保存先
    # ログファイルのディレクトリが存在しなければ作成
    $script:LogDir = Split-Path -Parent $script:LogPath
    if (-not (Test-Path -Path $script:LogDir)) { # ログディレクトリが存在しない場合
        New-Item -ItemType Directory -Path $script:LogDir | Out-Null
    }

    # ログACL用のユーザー解決
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $script:ExecutorSid = $identity.User
    $script:UserSidList = @()  # 複数ユーザーのSIDリスト
    
    if ($script:Yaml.LOG.USERS -and $script:Yaml.LOG.USERS.Count -gt 0) { # USERS配列が存在する場合
        foreach ($user in $script:Yaml.LOG.USERS) { # 各ユーザーごとに処理
            if ([string]::IsNullOrWhiteSpace($user)) { continue }
            try {
                $ntAccount = New-Object System.Security.Principal.NTAccount($user)
                $userSid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
                # 実行ユーザーと同じならスキップ（フル権限なので重複不要）
                if ($userSid.Value -ne $script:ExecutorSid.Value) { # 重複しない場合のみ追加
                    $script:UserSidList += $userSid
                }
            } catch {
                Write-Host "[WARNING] Could not resolve YAML LOG.USERS user '$user'. Skipping." -ForegroundColor Yellow
            }
        }
    }
    
    # ログディレクトリのパーミッション設定（実行ユーザー: フル、USERS: 読み取り）
    # 管理者権限がない場合はスキップ
    try {
        $logDirAcl = Get-Acl -Path $script:LogDir -ErrorAction Stop
        # 既存の継承権を無効化
        $logDirAcl.SetAccessRuleProtection($true, $false)
        # すべての権限を削除
        $logDirAcl.Access | ForEach-Object { $logDirAcl.RemoveAccessRule($_) } | Out-Null
        # 実行ユーザーにフルアクセス権を付与
        $ruleExec = New-Object System.Security.AccessControl.FileSystemAccessRule($script:ExecutorSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $logDirAcl.AddAccessRule($ruleExec)
        # 追加ユーザーに読み取り権限を付与
        foreach ($userSid in $script:UserSidList) { # 各ユーザーごとに処理
            $ruleUser = New-Object System.Security.AccessControl.FileSystemAccessRule($userSid, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
            $logDirAcl.AddAccessRule($ruleUser)
        }
        Set-Acl -Path $script:LogDir -AclObject $logDirAcl -ErrorAction Stop
    } catch {
        # ACL設定に失敗した場合は警告を表示するが、処理を続行
        # （管理者権限がない場合など）
        Write-Host "[WARNING] Could not set ACL on log directory (requires administrator privilege). Continuing without ACL configuration." -ForegroundColor Yellow
    }

    # 二重起動の禁止（早期チェック）
    # 同じスクリプトが複数同時実行されないようチェック
    if (-not (Test-NoDoubleActivation -Thread "relMain" -ShowDialog)) { # 二重起動している場合
        # 既に起動中のため以降の処理をスキップ（endは実行）
        Write-Host "既に起動中のため処理を終了します" -ForegroundColor Yellow
        $script:CanExecuteProcess = $false
    }

}
process{
    if (-not $script:CanExecuteProcess) { return }
    # スクリプトバージョン情報をログに記録（デバッグ用）
    Write-Host "[INFO] Script version: 1.2.0, Configuration version: $($script:yaml.Version)" -ForegroundColor Gray

    # PowerShellのバージョンチェック
    $PwsVerChk = ($PSVersionTable.PSVersion).ToString()
    if($script:Yaml.PowerShell.Version -ne $PwsVerChk){ # PowerShellバージョンが異なる場合
        # バージョンが異なる場合は、警告を表示
        [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "VERSION_WARNING" $PwsVerChk $script:Yaml.PowerShell.Version) -Title "WARNING" -Buttons 4
        switch($Button){
            6 { break } # OK(Continue)
            7 { $script:CanExecuteProcess = $false; return }  # Cancel(End)
            default { # 未知のボタン
                Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
                $script:CanExecuteProcess = $false; return
            }
        }
    }

    # 実行するかどうかの確認
    [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "EXECUTE_CONFIRM") -Title "INQUIRY" -Buttons 4
    switch($Button){
        6 { break } # OK(Continue)
        7 { $script:CanExecuteProcess = $false; return }  # Cancel(End)
        default { # 未知のボタン
            Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
            & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
            $script:CanExecuteProcess = $false; return
        }
    }

    # タイトル表示
    $ProjectLength = "Project name: $($script:Yaml.Project)".Length    # プロジェクト名の長さを取得
    $ProjectLine = "=" * $ProjectLength                         # プロジェクト名の長さと同じ長さの=を作成
    Write-CommonLog -Message $ProjectLine -LogPath $script:LogPath -Level 'INFO'                            # プロジェクト名の長さと同じ長さの=をログに出力
    Write-CommonLog -Message "Project name: $($script:Yaml.Project)" -LogPath $script:LogPath -Level 'INFO'        # プロジェクト名をログに出力
    Write-CommonLog -Message "Project version: $($script:Yaml.Version)" -LogPath $script:LogPath -Level 'INFO'     # バージョンをログに出力
    Write-CommonLog -Message $ProjectLine -LogPath $script:LogPath -Level 'INFO'                  # プロジェクト名の長さと同じ長さの=をログに出力
    
    # モジュールのインポート
    foreach($ModuleType in $script:Yaml.Module.Keys){ # 各モジュールタイプごとに処理
        $ModuleName = $script:Yaml.Module.$ModuleType.Name         # モジュール名
        $ModuleVersion = $script:Yaml.Module.$ModuleType.VERSION   # モジュールのバージョン
        
        # もし、モジュール名かバージョンが空であれば、スキップ
        if ([string]::IsNullOrWhiteSpace($ModuleName) -or [string]::IsNullOrWhiteSpace($ModuleVersion)) { # モジュール名かバージョンが空の場合
            Write-CommonLog -Message (& $script:GetMessage "MODULE_EMPTY_SKIP") -LogPath $script:LogPath -Level 'WARN'
            continue # スキップ
        }
        # モジュールがインストールされているか確認
        if (-not (Test-ModuleInstalled -ModuleName $ModuleName)) { # モジュールがインストールされていない場合
            # モジュールがインストールされていない場合は、インストールを促す
            [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "MODULE_INSTALL_PROMPT" $ModuleName) -Title "Module Check" -Buttons 4
            switch($Button){
                6 { break } # OK(Continue)
                7 { $script:CanExecuteProcess = $false; return }  # Cancel(End)
                default { # 未知のボタン
                    Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                    & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
                    $script:CanExecuteProcess = $false; return
                }
            }
        }
        
        try{
            # モジュールのインポート
            Import-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -ErrorAction Stop
            $msg = & $script:GetMessage "MODULE_IMPORT_SUCCESS" $ModuleName $ModuleVersion
            Write-CommonLog -Message $msg -LogPath $script:LogPath -Level 'INFO'
        }catch{
            # モジュールのインポートに失敗した場合は警告を表示し終了
            $msg = & $script:GetMessage "MODULE_IMPORT_ERROR" $ModuleName $ModuleVersion
            & $script:ShowPopup -Message ($msg + "`r`n`r`n" + $_.Exception.Message) -Title "Module Check" -Buttons 0x30 | Out-Null
            $script:CanExecuteProcess = $false; return
        }
    }

    # リリースの実行
    $RunPwsVerLength = ("Running PowerShell version: "+$PwsVerChk).Length   # PowerShellバージョンの長さを取得
    $RunPwsVerLine = "+" * $RunPwsVerLength                                 # PowerShellバージョンの長さと同じ長さの+を作成
    Write-CommonLog -Message $RunPwsVerLine -LogPath $script:LogPath -Level 'INFO'                              # PowerShellバージョンの長さと同じ長さの+をログに出力
    Write-CommonLog -Message ("HOST: "+$script:HostName) -LogPath $script:LogPath -Level 'INFO'                 # ホスト名をログに出力
    Write-CommonLog -Message ("USER: "+$script:User) -LogPath $script:LogPath -Level 'INFO'                     # ユーザ名をログに出力
    Write-CommonLog -Message ("Running PowerShell version: "+$PwsVerChk) -LogPath $script:LogPath -Level 'INFO' # PowerShellのバージョンをログに出力
    Write-CommonLog -Message $RunPwsVerLine -LogPath $script:LogPath -Level 'INFO'                              # PowerShellバージョンの長さと同じ長さの+をログに出力
    Write-CommonLog -Message ("Release start time: "+(Get-Date -Format "yyyy/MM/dd HH:mm:ss")) -LogPath $script:LogPath -Level 'INFO' # リリース開始時間をログに出力  

    # ここから時間計測
    $TimeLap = Measure-Command{ # 開始時間を取得

    # リリース処理
    $AllTypeObj = $script:Yaml.RELEASE.Keys # リリースタイプの取得
    foreach($ReleaseType in $AllTypeObj){ # 各リリースタイプごとに処理
        # リリース処理を実行
        Copy-ItemCustom -ReleaseType $ReleaseType -Yaml $script:Yaml -LogPath $script:LogPath -SensitivePatterns $script:SensitivePatterns
    }    } # ここまで時間計測

}
end{
    # 実行フラグがfalseでも最終ログは安全に出力
    # ログファイルのパーミッション設定（現在のユーザーのみ読み取り可能）
    # 管理者権限がない場合はスキップ
    try {
        if (Test-Path -Path $script:LogPath) { # ログファイルが存在する場合
            $logFileAcl = Get-Acl -Path $script:LogPath -ErrorAction Stop
            # 既存の継承権を無効化
            $logFileAcl.SetAccessRuleProtection($true, $false)
            # すべての権限を削除
            $logFileAcl.Access | ForEach-Object { $logFileAcl.RemoveAccessRule($_) } | Out-Null
            # 実行ユーザーにフルアクセス権を付与
            $ruleExecFile = New-Object System.Security.AccessControl.FileSystemAccessRule($script:ExecutorSid, "FullControl", "None", "None", "Allow")
            $logFileAcl.AddAccessRule($ruleExecFile)
            # 追加ユーザーに読み取り権限を付与
            foreach ($userSid in $script:UserSidList) { # YAMLのLOG.USERS配列からのユーザー
                $ruleUserFile = New-Object System.Security.AccessControl.FileSystemAccessRule($userSid, "Read", "None", "None", "Allow")
                $logFileAcl.AddAccessRule($ruleUserFile)
            }
            Set-Acl -Path $script:LogPath -AclObject $logFileAcl -ErrorAction Stop
        }
    } catch {
        Write-CommonLog -Message "[WARNING] Could not set ACL on log file (requires administrator privilege). Continuing without ACL configuration." -LogPath $script:LogPath -Level 'WARN'
    }
    
    # Measure-Commandの結果をログに出力（未実行時はスキップ）
    if ($null -ne $TimeLap) { # 時間計測結果が存在する場合
        Write-CommonLog -Message ("Elapsed time for release: {0:D2}:Min {1:D2}:Sec" -f $TimeLap.Minutes, $TimeLap.Seconds) -LogPath $script:LogPath -Level 'INFO'
    }
    Write-CommonLog -Message "Release end time: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')" -LogPath $script:LogPath -Level 'INFO'
    
    if (Test-Path -Path $script:LogPath) { Invoke-Item -Path $script:LogPath } # ログファイルを自動オープン
}

