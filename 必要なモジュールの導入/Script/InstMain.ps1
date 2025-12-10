<#
.SYNOPSIS
    YAMLファイルに記述されたPowerShellモジュールを一括インストールするスクリプト

.DESCRIPTION
    このスクリプトは、YAML設定ファイルに定義されたPowerShellモジュールを自動的にインストールします。
    以下の機能を提供します：
    
    1. YAMLファイルからモジュール情報を読み込み
    2. 指定されたバージョンのモジュール存在チェック
    3. 不足しているモジュールの自動インストール
    4. PowerShellバージョンの検証と警告表示
    5. 二重起動の防止
    6. インストール結果の詳細ログ記録

.PARAMETER envFileName
    使用する環境設定YAMLファイル名を指定します。
    省略時は "Env.yaml" が使用されます。
    
    ファイルは YAML フォルダ内に配置する必要があります。

.EXAMPLE
    .\InstMain.ps1
    
    デフォルトの Env.yaml を使用してモジュールをインストールします。

.EXAMPLE
    .\InstMain.ps1 -envFileName "Production.yaml"
    
    カスタム設定ファイル Production.yaml を使用してインストールします。

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    None
    標準出力はありません。結果はログファイルに記録されます。

.NOTES
    ファイル名: InstMain.ps1
    作成者: UMA68
    バージョン: 1.0.0
    必要なモジュール: powershell-yaml (自動インストール)
    
    ディレクトリ構造:
        必要なモジュールの導入/
        ├── Script/
        │   ├── InstMain.ps1              ← このスクリプト
        │   ├── Check-EnvModule.ps1        ← モジュールチェック
        │   └── Check-YamlModule.ps1       ← YAMLモジュールチェック
        ├── YAML/
        │   └── Env.yaml                   ← 設定ファイル
        └── LOG/                           ← ログ出力先（自動作成）
            └── {ホスト名}_yyyyMMdd-HHmmss.log
    
    ログレベル:
        [EXIST]   - 指定バージョンのモジュールが既にインストール済み
        [OTHER]   - 異なるバージョンのモジュールが存在
        [NOTHING] - モジュールが存在しない
        [INSTALL] - モジュールを新規インストール
    
    セキュリティ:
        - 管理者権限が必要な場合があります
        - 二重起動を防止する機構が組み込まれています

.LINK
    https://github.com/UMA68/PowerShell

#>

# ================================================
# yamlファイルに記述したモジュールをインストールする
# ================================================

param (
    [string]$envFileName = "Env.yaml" # オプションなしの場合は「Env.yaml」を使用する
)

begin{
    # ====================================
    # ディレクトリとパスの初期化
    # ====================================
    # スクリプト実行に必要な各種ディレクトリパスを構築
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path    # スクリプト実行ディレクトリ取得
    $UpperDir = Split-Path $scriptDir -Parent               # スクリプト実行ディレクトリの親ディレクトリ取得
    $PowerShellDir = Split-Path $UpperDir -Parent           # PowerShellディレクトリ
    $yamlDir = $UpperDir+"\YAML"                            # Yamlファイル格納ディレクトリ
    $LogDir = $UpperDir+"\Log"                              # Logファイル格納ディレクトリ
    $envPath = $yamlDir+"\"+$envFileName                    # yamlファイルのパス
    $comPath = $PowerShellDir+"\Common"                     # 共通スクリプト格納ディレクトリ
    
    # ====================================
    # 環境変数の取得
    # ====================================
    # 実行環境情報を取得し、ログに記録
    $UserName = $env:USERNAME       # ユーザ名取得
    $HostName = $env:COMPUTERNAME   # ホスト名取得

    # ====================================
    # 共通スクリプトの読み込み
    # ====================================
    # 必要な.ps1ファイルをドットソーシングで読み込み
    try {
        . $comPath"\NoDoubleActivation.ps1" -ErrorAction Stop    # 二重起動チェック
        . $comPath"\Write-CommonLog.ps1" -ErrorAction Stop       # ログ記録機能
        . $scriptDir"\Check-EnvModule.ps1" -ErrorAction Stop     # 環境モジュールチェック
        . $scriptDir"\Check-YamlModule.ps1" -ErrorAction Stop    # YAMLモジュールチェック
    } catch {
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $scriptName = $_.InvocationInfo.MyCommand.Name
            $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        } finally {
            if ($null -ne $obj) {
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
        exit    # おわり
    }
    
    # ====================================
    # ログファイルの初期化
    # ====================================
    # ログディレクトリとログファイルパスの作成
    $Log = Join-Path -Path $LogDir -ChildPath ($HostName+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")
    # ログディレクトリがなければ作成
    if(-not (Test-Path -Path $LogDir)){ # ログディレクトリがなければ作成
        New-Item -Path $LogDir -ItemType Directory | Out-Null
    }
    
    # ====================================
    # Powershell-Yamlモジュールの検証
    # ====================================
    # YAMLファイル読み込みに必須のモジュールを事前確認・インストール
    # なければインストールする(無指定だと0.4.7をインストールする)
    # 違うバージョンをインストールしたい場合は、以下のコメントアウトを参考にバージョン指定する
    # Test-YamlModule -Ver 'x.x.x'
    Test-YamlModule

    # ====================================
    # 設定ファイルの読み込み
    # ====================================
    # YAMLファイルからモジュール情報を読み込み
    try{
        $yaml = Get-Content $envPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    }catch{
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($envFileName+"の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        } finally {
            if ($null -ne $obj) {
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
        exit    # おわり
    }
}
Process{
    # ====================================
    # 二重起動の防止
    # ====================================
    # 同じスクリプトが複数同時実行されないようチェック
    Test-NoDoubleActivation -Thread "InstMain" # スレッド名は拡張子無しのスクリプトファイル名

    # ====================================
    # PowerShellバージョンの検証
    # ====================================
    # 実行中のPowerShellバージョンとYAMLで指定されたバージョンを比較
    $pwsVerChk = ($PSVersionTable.PSVersion).ToString()
    $obj = $null
    if($pwsVerChk -ne $yaml.PowerShell.Version){    # バージョン不一致の場合
        # yaml記述のバージョンと違ったら警告表示
        try {
            $obj = New-Object -ComObject WScript.Shell
            [int]$retButton = $obj.Popup("実行中のPowerShellは "+$pwsVerChk+" です。`r`nPowerShell "+$yaml.PowerShell.Version+" を前提にインストールを行います。続行しますか？",0,"警告",4)   # はい=6 いいえ=7
            switch($retButton){
                6 { break } # はい
                7 {
                    if ($null -ne $obj) {
                        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                        $obj = $null
                    }
                    exit  # いいえ
                }
            }
        } finally {
            if ($null -ne $obj) {
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
    }

    # ====================================
    # ログ記録の開始
    # ====================================
    # 実行環境情報をログファイルに記録
    Write-CommonLog -Message ("HOST: "+$HostName) -LogPath $Log -Level 'INFO'   # ホスト名
    Write-CommonLog -Message ("USER: "+$userName) -LogPath $Log -Level 'INFO'   # ユーザ名

    Write-CommonLog -Message ("Running PowerShell Version: "+$pwsVerChk) -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "============================" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message ($yaml.Project) -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message ("Version: "+$yaml.Version) -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "============================" -LogPath $Log -Level 'INFO'

    Write-CommonLog -Message ("[[[START]]]") -LogPath $Log -Level 'INFO'

    # ====================================
    # モジュールのインストール処理
    # ====================================
    # YAMLファイルで定義された全モジュールを順次チェック・インストール
    foreach($module in $yaml.Module.Keys){  # 各モジュールを処理
        Test-EnvModule -ModuleName $yaml.Module.$module.Name -ModuleVersion $yaml.Module.$module.Version  # モジュールのインストール
    }

    Write-CommonLog -Message ("[[[END]]]") -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "-----------------------------" -LogPath $Log -Level 'INFO'
}
end{
    # ====================================
    # 完了メッセージの表示
    # ====================================
    # 処理終了をポップアップで通知
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("処理を終了しました。ログを表示します", 0, "完了", 0x40)   # 0x40:情報

    # ====================================
    # ログの見方を追記
    # ====================================
    # ログファイル末尾に凡例を追加
    Write-CommonLog -Message " " -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "ログの見方" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[EXIST] : yaml記述バージョンのモジュールを発見" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[OTHER] : yaml記述バージョン以外のモジュールを発見" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[NOTHING] : yaml記述モジュールが存在しない" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[INSTALL] : yaml記述バージョンのモジュールが存在しないのでインストール" -LogPath $Log -Level 'INFO'
    
    # ====================================
    # ログファイルを開く
    # ====================================
    # 処理結果を確認するためログファイルを自動で開く
    Invoke-Item $Log
}
