# ================================================
# yamlファイルに記述したモジュールをインストールする
# ================================================

param (
    [string]$envFileName = "Env.yaml" # オプションなしの場合は「Env.yaml」を使用する
)

begin{
    # 実行環境の設定
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path    # スクリプト実行ディレクトリ取得
    $UpperDir = Split-Path $scriptDir -Parent               # スクリプト実行ディレクトリの親ディレクトリ取得
    $PowerShellDir = Split-Path $UpperDir -Parent           # PowerShellディレクトリ
    $yamlDir = $UpperDir+"\YAML"                            # Yamlファイル格納ディレクトリ
    $LogDir = $UpperDir+"\Log"                              # Logファイル格納ディレクトリ
    $envPath = $yamlDir+"\"+$envFileName                    # yamlファイルのパス
    $comPath = $PowerShellDir+"\Common"                     # 共通スクリプト格納ディレクトリ
    
    # 環境変数の取得
    $UserName = $env:USERNAME       # ユーザ名取得
    $HostName = $env:COMPUTERNAME   # ホスト名取得

    # .ps1ファイル読み込み
    try {
        . $comPath"\NoDoubleActivation.ps1" -ErrorAction Stop
        . $comPath"\Get-EncryptionKey.ps1" -ErrorAction Stop
        . $comPath"\Get-ScriptPaths.ps1" -ErrorAction Stop
        . $comPath"\Import-YamlConfig.ps1" -ErrorAction Stop
        . $comPath"\Write-CommonLog.ps1" -ErrorAction Stop
        . $scriptDir"\Check-EnvModule.ps1" -ErrorAction Stop
        . $scriptDir"\Log-Output.ps1" -ErrorAction Stop
        . $scriptDir"\Check-YamlModule.ps1" -ErrorAction Stop
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $scriptName = $_.InvocationInfo.MyCommand.Name
        $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        Exit    # おわり
    }
    # ログの定義
    $Log = Join-Path -Path $LogDir -ChildPath ($HostName+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")
    # ログディレクトリがなければ作成
    if(!(Test-Path -Path $LogDir)){
        New-Item -Path $LogDir -ItemType Directory | Out-Null
    }
    
    # Powershell-Yamlモジュールの存在チェック
    # なければインストールする(無指定だと0.4.7をインストールする)
    # 違うバージョンをインストールしたい場合は、以下のコメントアウトを参考にバージョン指定する
    # Test-YamlModule -Ver 'x.x.x'
    Test-YamlModule

    # Yamlファイル読み込み
    try{
        $yaml = Get-Content $envPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    }catch{
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($envFileName+"の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        Exit    # おわり
    }
}
Process{
    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "InstMain" # スレッド名は拡張子無しのスクリプトファイル名

    # メインスクリプトの実行
    # powerShellバージョンチェック
    $pwsVerChk = ($PSVersionTable.PSVersion).ToString()
    if(!($pwsVerChk -eq $yaml.PowerShell.Version)){
        # yaml記述のバージョンと違ったら警告表示
        $obj = New-Object -ComObject WScript.Shell
        [int]$retButton = $obj.Popup("実行中のPowerShellは "+$pwsVerChk+" です。`r`nPowerShell "+$yaml.PowerShell.Version+" を前提にインストールを行います。続行しますか？",0,"警告",4)   # はい=6 いいえ=7
        switch($retButton){
            6 { break } # はい
            7 { exit }  # いいえ
        }
    }

    # ログの記録開始
    Write-CommonLog -Message ("HOST: "+$HostName) -LogPath $Log -Level 'INFO'   # ホスト名
    Write-CommonLog -Message ("USER: "+$userName) -LogPath $Log -Level 'INFO'   # ユーザ名

    Write-CommonLog -Message ("Running PowerShell Version: "+$pwsVerChk) -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "============================" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message ($yaml.Project) -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message ("Version: "+$yaml.Version) -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "============================" -LogPath $Log -Level 'INFO'

    Write-CommonLog -Message ("[[[START]]]") -LogPath $Log -Level 'INFO'

    # モジュールのインストール
    foreach($module in $yaml.Module.Keys){
        Test-EnvModule -ModuleName $yaml.Module.$module.Name -ModuleVersion $yaml.Module.$module.Version  # モジュールのインストール
    }

    Write-CommonLog -Message ("[[[END]]]") -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "-----------------------------" -LogPath $Log -Level 'INFO'
}
end{
    # 終了メッセージ
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("処理を終了しました。ログを表示します", 0, "完了", 0x40)   # 0x40:情報

    # ログの見方を追記
    Write-CommonLog -Message " " -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "ログの見方" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[EXIST] : yaml記述バージョンのモジュールを発見" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[OTHER] : yaml記述バージョン以外のモジュールを発見" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[NOTHING] : yaml記述モジュールが存在しない" -LogPath $Log -Level 'INFO'
    Write-CommonLog -Message "[INSTALL] : yaml記述バージョンのモジュールが存在しないのでインストール" -LogPath $Log -Level 'INFO'
    
    # ログファイルを開く
    Invoke-Item $Log
}
