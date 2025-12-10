<#
.SYNOPSIS
    リリースバッチ自動化スクリプト - YAML設定に基づいてファイルをリリース先にコピーします

.DESCRIPTION
    このスクリプトは、YAML設定ファイルで定義されたリリースタイプごとに、
    リリース元フォルダからリリース先フォルダへファイルを自動コピーします。
    
    主な機能:
    - 複数のリリースタイプ（TYPE_A, TYPE_B など）をサポート
    - 既存ファイルのバージョニング（タイムスタンプ付きリネーム）
    - マルチ言語対応メッセージ（日本語/英語）
    - ログファイルの自動生成と機密情報マスキング
    - 二重起動防止機能
    - ファイルシステムパーミッション管理

.PARAMETER DecryptionKey
    暗号化用鍵ファイル名。デフォルト値: "Encryption.Key"
    将来的な暗号化パスワード処理に使用予定

.PARAMETER EnvYaml
    環境設定YAMLファイル名。デフォルト値: "EnvDEV.yaml"
    有効な値:
    - EnvDEV.yaml   : 開発環境
    - EnvSTG.yaml   : ステージング環境
    - EnvPROD.yaml  : 本番環境

.EXAMPLE
    # デフォルト（DEV環境）で実行
    .\relMain.ps1

.EXAMPLE
    # STG環境で実行
    .\relMain.ps1 -EnvYaml "EnvSTG.yaml"

.EXAMPLE
    # PROD環境で実行
    .\relMain.ps1 -EnvYaml "EnvPROD.yaml"

.NOTES
    File Name      : relMain.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2025-12-10
    Last Modified  : 2025-12-10
    
    前提条件:
    - PowerShell 7.3.9 以上
    - PowerShell-Yaml モジュール 0.4.7 以上
    - SqlServer モジュール 22.1.1 以上
    - Windows PowerShell実行ポリシー: RemoteSigned 以上
    
    依存ファイル:
    - Common/FindModule.ps1       : モジュール検索関数
    - Common/NoDoubleActivation.ps1 : 二重起動防止機能
    - Common/Write-CommonLog.ps1  : ログ出力関数
    - Script/CopyItemCustom.ps1   : ファイルコピー処理
    - YAML/Env*.yaml              : 環境設定ファイル
    
    変更履歴:
    v1.2.0 (2025-12-10)
        - ログファイルセキュリティ機能追加（パーミッション設定、機密情報マスキング）
        - 二重起動チェックを begin ブロックに移動（早期チェック）
        - COM オブジェクト管理を関数化
        - エラーメッセージ多言語化
        
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
#>

# ===================================
# 起動オプション
#  -DecryptionKey   鍵ファイル指定 (現在未使用・将来の暗号化機能用に予約)
#  -EnvYaml         YAMLファイル指定
# ===================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        # ファイル名としての有効性を検証
        if ($_ -match '[\\/:"*?<>|]') {
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ([string]::IsNullOrWhiteSpace($_)) {
            throw "ファイル名は空にできません"
        }
        if ($_.Length -gt 255) {
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true
    })]
    [string]$DecryptionKey = "Encryption.Key" , # 暗号化鍵ファイル名（現在未使用・将来の暗号化機能用に予約）
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        # ファイル名としての有効性を検証（.yaml または .yml 拡張子必須）
        if ($_ -notmatch '\.(yaml|yml)$') {
            throw "YAMLファイルは .yaml または .yml 拡張子である必要があります: $_"
        }
        if ($_ -match '[\\/:"*?<>|]') {
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ([string]::IsNullOrWhiteSpace($_)) {
            throw "ファイル名は空にできません"
        }
        if ($_.Length -gt 255) {
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true
    })]
    [string]$EnvYaml = "EnvDEV.yaml"            # DEV環境用:EnvDEV.yaml, STG環境用:EnvSTG.yaml, 本番環境用:EnvPRD.yaml
)
begin{
    # エラーメッセージ定数（YAML読み込み前）
    $ErrorMessages = @{
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
        if (-not (Test-ModuleInstalled -ModuleName "PowerShell-Yaml")) {
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
        $script:Yaml = Get-Content $script:YamlPath -Delimiter "`0" | ConvertFrom-Yaml -Ordered -ErrorAction Stop
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
    if ($script:yaml.SECURITY.SensitivePatterns) {
        $script:SensitivePatterns = $script:yaml.SECURITY.SensitivePatterns
    }
    
    # COM オブジェクト（WScript.Shell）を安全に管理するヘルパー関数
    $script:ShowPopup = {
        param(
            [string]$Message,
            [int]$Buttons = 0,
            [string]$Title = "Information"
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
            [string]$Key
        )
        # スクリプトブロックの可変長引数は$argsに入る
        $Arguments = $args
        $script:Lang = $script:Yaml.MESSAGES.LANGUAGE
        $script:Message = $script:Yaml.MESSAGES.$script:Lang.$Key
        
        # メッセージがない場合はキーをそのまま返す
        if ([string]::IsNullOrEmpty($script:Message)) {
            return $Key
        }
        
        # YAMLのエスケープシーケンスを実際の改行に変換
        $script:Message = $script:Message.Replace('\r\n', "`r`n").Replace('\n', "`n")
        
        # 引数があれば、文字列をフォーマット
        if ($Arguments -and $Arguments.Count -gt 0) {
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
    if (-not (Test-Path -Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir | Out-Null
    }
    
    # ログディレクトリのパーミッション設定（現在のユーザーのみアクセス可能）
    # 管理者権限がない場合はスキップ
    try {
        $logDirAcl = Get-Acl -Path $script:LogDir -ErrorAction Stop
        # 既存の継承権を無効化
        $logDirAcl.SetAccessRuleProtection($true, $false)
        # すべての権限を削除
        $logDirAcl.Access | ForEach-Object { $logDirAcl.RemoveAccessRule($_) } | Out-Null
        # 現在のユーザーにフルアクセス権を付与
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity.User, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $logDirAcl.AddAccessRule($rule)
        Set-Acl -Path $script:LogDir -AclObject $logDirAcl -ErrorAction Stop
    } catch {
        # ACL設定に失敗した場合は警告を表示するが、処理を続行
        # （管理者権限がない場合など）
        Write-Host "[WARNING] Could not set ACL on log directory (requires administrator privilege). Continuing without ACL configuration." -ForegroundColor Yellow
    }

    # 二重起動の禁止（早期チェック）
    Test-NoDoubleActivation -Thread "relMain" # スレッド名は拡張子無しのスクリプトファイル名
}
process{
    # スクリプトバージョン情報をログに記録（デバッグ用）
    Write-Host "[INFO] Script version: 1.2.0, Configuration version: $($script:yaml.Version)" -ForegroundColor Gray

    # PowerShellのバージョンチェック
    $PwsVerChk = ($PSVersionTable.PSVersion).ToString()
    if($script:Yaml.PowerShell.Version -ne $PwsVerChk){
        [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "VERSION_WARNING" $PwsVerChk $script:Yaml.PowerShell.Version) -Title "WARNING" -Buttons 4
        switch($Button){
            6 { break } # OK(Continue)
            7 { exit }  # Cancel(End)
            default { 
                Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
                exit
            }
        }
    }

    # 実行するかどうかの確認
    [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "EXECUTE_CONFIRM") -Title "INQUIRY" -Buttons 4
    switch($Button){
        6 { break } # OK(Continue)
        7 { exit }  # Cancel(End)
        default { 
            Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
            & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
            exit
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
    foreach($ModuleType in $script:Yaml.Module.Keys){
        $ModuleName = $script:Yaml.Module.$ModuleType.Name         # モジュール名
        $ModuleVersion = $script:Yaml.Module.$ModuleType.VERSION   # モジュールのバージョン
        
        # もし、モジュール名かバージョンが空であれば、スキップ
        if ([string]::IsNullOrWhiteSpace($ModuleName) -or [string]::IsNullOrWhiteSpace($ModuleVersion)) {
            Write-CommonLog -Message (& $script:GetMessage "MODULE_EMPTY_SKIP") -LogPath $script:LogPath -Level 'WARN'
            continue # スキップ
        }
        # モジュールがインストールされているか確認
        if (-not (Test-ModuleInstalled -ModuleName $ModuleName)) {
            # モジュールがインストールされていない場合は、インストールを促す
            [int]$Button = & $script:ShowPopup -Message (& $script:GetMessage "MODULE_INSTALL_PROMPT" $ModuleName) -Title "Module Check" -Buttons 4
            switch($Button){
                6 { break } # OK(Continue)
                7 { exit }  # Cancel(End)
                default { 
                    Write-CommonLog -Message (& $script:GetMessage "UNKNOWN_BUTTON") -LogPath $script:LogPath -Level 'ERROR'
                    & $script:ShowPopup -Message (& $script:GetMessage "UNKNOWN_BUTTON") -Title "Unknown" -Buttons 0x30 | Out-Null
                    exit
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
            exit # 終了
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
    foreach($ReleaseType in $AllTypeObj){
        # リリース処理を実行
        Copy-ItemCustom -ReleaseType $ReleaseType -Yaml $script:Yaml -LogPath $script:LogPath -SensitivePatterns $script:SensitivePatterns
    }    } # ここまで時間計測

}
end{
    # ログファイルのパーミッション設定（現在のユーザーのみ読み取り可能）
    # 管理者権限がない場合はスキップ
    try {
        if (Test-Path -Path $script:LogPath) {
            $logFileAcl = Get-Acl -Path $script:LogPath -ErrorAction Stop
            # 既存の継承権を無効化
            $logFileAcl.SetAccessRuleProtection($true, $false)
            # すべての権限を削除
            $logFileAcl.Access | ForEach-Object { $logFileAcl.RemoveAccessRule($_) } | Out-Null
            # 現在のユーザーにフルアクセス権を付与
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity.User, "FullControl", "None", "None", "Allow")
            $logFileAcl.AddAccessRule($rule)
            Set-Acl -Path $script:LogPath -AclObject $logFileAcl -ErrorAction Stop
        }
    } catch {
        Write-CommonLog -Message "[WARNING] Could not set ACL on log file (requires administrator privilege). Continuing without ACL configuration." -LogPath $script:LogPath -Level 'WARN'
    }
    
    # Measure-Commandの結果をログに出力
    Write-CommonLog -Message ("Elapsed time for release: {0:D2}:Min {1:D2}:Sec" -f $TimeLap.Minutes, $TimeLap.Seconds) -LogPath $script:LogPath -Level 'INFO' # リリース処理の経過時間をログに出力
    Write-CommonLog -Message "Release end time: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')" -LogPath $script:LogPath -Level 'INFO'   # リリース終了時間をログに出力
    
    Invoke-Item -Path $script:LogPath   # ログファイルを開く
}

