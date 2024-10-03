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
    
    # ユーザ名取得
    $global:glbUser = $env:USERNAME
    # ホスト名取得
    $global:glbHost = $env:COMPUTERNAME

    # .ps1ファイル読み込み
    try {
        . $comPath"\NoDoubleActivation.ps1" -ErrorAction Stop
        . $scriptDir"\Check-EnvModule.ps1" -ErrorAction Stop
        . $scriptDir"\Log-Output.ps1" -ErrorAction Stop
        . $scriptDir"\Chck-YamlModule.ps1" -ErrorAction Stop
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $scriptName = $_.InvocationInfo.MyCommand.Name
        $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
            # おわり
    }

    # Powershell-Yamlモジュールの存在チェック
    # なければインストールする(無指定だと0.4.7をインストールする)
    # 違うバージョンをインストールしたい場合は、以下のコメントアウトを参考にバージョン指定する
    # Check-YamlModule -Ver 'x.x.x'
    Check-YamlModule

    # Yamlファイル読み込み
    # $yaml = Get-Content $yamlDir"\Env.yaml" -Delimiter "`0" | ConvertFrom-Yaml
    try{
        $yaml = Get-Content $envPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    }catch{
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($envFileName+"の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        Exit    # おわり
    }
    # ログの定義
    $Log = Join-Path -Path $LogDir -ChildPath ($glbHost+"_"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")
        
    # ログの書き込み関数
    function Write-Log {
        param(
            [Parameter(Mandatory=$true)]
            [string]$Message
        )
        Log-Output -Message $Message -LogPath $Log
    }
}
Process{
    # 二重起動の禁止
    Check-NoDoubleActivation -Thread "InstMain" # スレッド名は拡張子無しのスクリプトファイル名

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
    Write-Log ("HOST: "+$glbHost)   # ホスト名
    Write-Log ("USER: "+$glbUser)   # ユーザ名

    Write-Log ("Running PowerShell Version: "+$pwsVerChk)
    Write-Log "============================"
    Write-Log ($yaml.Project)
    Write-Log ("Version: "+$yaml.Version)
    Write-Log "============================"

    Write-Log ("MSG: "+(Get-Date -Format "yyyyMMdd HH:mm:ss")+" [[[START]]]")

    # モジュールのインストール
    foreach($module in $yaml.Module.Keys){
        Check-EnvModule -ModuleName $yaml.Module.$module.Name -ModuleVersion $yaml.Module.$module.Version  # モジュールのインストール
    }

    Write-Log ("MSG: "+(Get-Date -Format "yyyyMMdd HH:mm:ss")+" [[[END]]]")
    Write-Log "-----------------------------"
    }
end{
    # 終了メッセージ
    $obj = New-Object -ComObject WScript.Shell
    $obj.popup("処理を終了しました。ログを表示します", 0, "完了", 0x40)   # 0x40:情報

    # ログの見方を追記
    Write-Log " "
    Write-Log "ログの見方"
    Write-Log "[EXIST] : yaml記述バージョンのモジュールを発見"
    Write-Log "[OTHER] : yaml記述バージョン以外のモジュールを発見"
    Write-Log "[NOTHING] : yaml記述モジュールが存在しない"
    Write-Log "[INSTALL] : yaml記述バージョンのモジュールが存在しないのでインストール"

    # ログファイルを開く
    Invoke-Item $Log
}
