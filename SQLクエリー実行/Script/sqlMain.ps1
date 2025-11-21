# SQLファイルを実行するサンプル

param(
    # 起動オプション
    $DecryptionKey = "Encryption.Key" , # オプション無しのデフォルト値
    $EnvYaml = "sql.yaml"               # オプション無しのデフォルト値
)

begin{

    # スクリプトのディレクトリ取得
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ取得
    $UpperDir = Split-Path -Parent $ScriptDir                       # スクリプトの親ディレクトリ取得
    $PowerShellDir = Split-Path -Parent $UpperDir                   # PowerShellディレクトリ
    $comPath = $PowerShellDir+"\Common"                             # 共通スクリプト格納ディレクトリ
    $Yaml = $UpperDir+"\YAML"                                       # yamlファイルの格納場所
    $KeyPath = Join-Path -Path $comPath -ChildPath $DecryptionKey   # 鍵ファイルのパス
    $YamlPath = Join-Path -Path $Yaml -ChildPath $EnvYaml           # yamlファイルのパス

    # .ps1ファイル読み込み
    try {
        . $comPath"\NoDoubleActivation.ps1" -ErrorAction Stop
        . $comPath"\CheckCommand.ps1" -ErrorAction Stop
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $scriptName = $_.InvocationInfo.MyCommand.Name
        $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
            # おわり
    }
    
    # 実行前のチェック。問題があったら終了
    Test-NoDoubleActivation -Thread "sqlMain"  # 二重起動チェック
    Test-Command -ComName "nkf32"              # nkf32の存在を確認(nkf32.exeと拡張子付も可)

    # PowerShell-Yamlモジュールがインストールされていなけれは終了
    $YamlModule = ((Get-Module -ListAvailable -Name PowerShell-Yaml).Name).Count
    if($YamlModule -eq 0){
        # モジュールがインストールされていない場合はエラーを表示して終了する
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("PowerShell-Yamlモジュールがインストールされていません。処理を終了します。",0,"警告",0x30) | Out-Null
        exit    # おわり
    }
    
    # yamlファイルの読み込み
    try {
        # $envPath = $Yaml+"\sql.yaml"
        $YamlOBJ = Get-Content $YamlPath -Delimiter "`0"  -ErrorAction Stop | ConvertFrom-Yaml -Ordered 
    }
    catch {
        # ファイルが読み込めなかった場合はエラーを表示して終了する
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($EnvYaml+"ファイルが読み込めませんでした。処理を終了します。",0,"警告",0x30) | Out-Null
        exit    # おわり
    }

    # PowerShellのバージョンチェック
    $pwsVerChk = ($PSVersionTable.PSVersion).ToString() # 実行バージョン
    $pwsAssumVer = $YamlOBJ.PowerShell.Version          # 想定バージョン(yamlに記述)
    if($pwsVerChk -ne $pwsAssumVer){
        # 想定のバージョンと違ったら警告表示
        $obj = New-Object -ComObject WScript.Shell
        [int]$retButton = $obj.Popup("実行中のPowerShellは "+$pwsVerChk+" です。`r`n必要なモジュールは PowerShell "+$pwsAssumVer+" を前提にインストールを行います。`r`n`r`n続行しますか？",0,"警告",0x30)   # はい=6 いいえ=7
        switch($retButton){
            6 { break } # はい
            7 { exit }  # いいえ
        }
    }
    
    # # モジュールがインストールされているか確認する
    # $YamlModule = ((Get-Module -ListAvailable -Name sqlserver).Name).Count
    # if($YamlModule -eq 0){
    #     # モジュールがインストールされていない場合はエラーを表示して終了する
    #     $obj = New-Object -ComObject WScript.Shell
    #     $obj.Popup("invoke-sqlcmdモジュールがインストールされていません。処理を終了します。",0,"警告",0x30) | Out-Null
    #     exit    # おわり

    # yamlに記述されたバージョンのモジュールを使用する
    foreach($module in $YamlOBJ.Module.Keys){
        try {
            Import-Module $YamlOBJ.Module.$module.Name -RequiredVersion $YamlOBJ.Module.$module.Version -ErrorAction Stop
        }
        catch {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($YamlOBJ.Module.$module.Name+"："+$YamlOBJ.Module.$module.Version+" モジュールがインポートできませんでした。処理を終了します。",0,"警告",0x30) | Out-Null
            exit    # おわり
        }
    }

    # LOGの定義
    $LogFolder = $UpperDir+"\"+$YamlOBJ.LOG.FOLDER
    $LogName = $YamlOBJ.LOG.FILENAME+"_"+(Get-Date -Format "yyyyMMdd_HHmmss")+$YamlOBJ.LOG.EXTENSION
    # $glbLog = $LogFolder+"\"+$LogName
    $LogPath = Join-Path -Path $LogFolder -ChildPath $LogName
    
    # # ps1ファイルの読み込み
    # .$ScriptDir"\CopyItem.ps1"

        # パラメータの定義
        [string]$ServerInstance = $YamlOBJ.HOST.SERVER
        [string]$Database = $YamlOBJ.HOST.DATABASE
        [string]$Username = $YamlOBJ.HOST.USERNAME
        [string]$pwFile = $YamlOBJ.HOST.PWF   # パスワードファイル名
    
        # 復号化する鍵を読み込む
        # 読み込み失敗した場合はエラーを表示し終了する
        # try {
        #     [byte[]]$EncryptedKey = Get-Content -Path $DecryptionKeyFile -ErrorAction stop
        # }
        # catch {
        #     Write-Host "鍵の読み込みに失敗しました。" -ForegroundColor Yellow
        #     Write-Host $_.Exception.Message -ForegroundColor Red    # エラー内容を表示
        #     Write-Host "鍵ファイル(Encryption.Key)が正しいことを確認してください。" -ForegroundColor Yellow
        #     # 処理を一時停止する
        #     Write-Host "何かキーを押してください。" -ForegroundColor Yellow
        #     $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")  | Out-Null # キー入力を受け付ける
        #     exit    # 終了
        # }
        try {
            if (Test-Path -Path $keyPath) {
                # 鍵ファイルを読み込む
                [byte[]]$EncryptedKey =[System.IO.File]::ReadAllBytes($keyPath)
                Write-Host "鍵ファイル「"$DecryptionKey"」を読み込みました。"
            } else {
                throw "鍵ファイル「"+$DecryptionKey+"」が読み込めません。"  # 例外を発生させる
            }
        } catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            $obj = New-Object -ComObject WScript.Shell
            $obj.popup($_.Exception.Message + "作成した "+$DecryptionKey+" を 「"+$comPath+"」 へ置いてください。", 0, "エラー", 0x10)  # 0x10:エラーアイコン
            exit
        }        
        # [byte[]]$EncryptedKey = Get-Content -Path $ScriptDir"\Encryption.Key"
    
        # # 暗号化したパスワードを平文に戻して使う場合は以下のようにする
        # $password = Get-Content -Path $ScriptDir"\Password.pass" | ConvertTo-SecureString
        # 他のユーザーのパスワードを使う場合は以下のようにする
        # $password = Get-Content -Path $ScriptDir"\Password.pass" | ConvertTo-SecureString -Key $EncryptedKey  # パスワードを暗号化したファイルを読み込む
        try {
            $password = Get-Content -Path $UpperDir"\"$pwFile | ConvertTo-SecureString -Key $EncryptedKey -ErrorAction stop # パスワードを暗号化したファイルを読み込む
        }
        catch {
            Write-Host "パスワードの復号化に失敗しました。" -ForegroundColor Yellow    # パスワードの復号化に失敗した場合はエラーを表示して終了する
            Write-Host $_.Exception.Message -ForegroundColor Red    # エラー内容を表示
            Write-Host "パスワードファイル,鍵ファイル("+$DecryptionKey+")が正しいことを確認してください。" -ForegroundColor Yellow
            # 処理を一時停止する
            Write-Host "何かキーを押してください。" -ForegroundColor Yellow
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")  | Out-Null # キー入力を受け付ける
            exit    # 終了
        }
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))    # パスワードを平文に戻す
    
    # # ログファイルの作成
    # $LogPath = $log+"\log_"+(Get-Date -Format "yyyyMMdd_HHmmss")+".log"

}
process{
    
    # SqlFolder内のファイルをinvoke-sqlcmdで実行する
    $YamlSQL = $YamlOBJ.RELEASE.SQL.FolderBy    # SQLファイルを置くフォルダ名(Yaml記述)
    $SqlFolder = $UpperDir+"\"+$YamlSQL         # sqlフォルダの格納場所
    $SqlFiles = Get-ChildItem -Path $SqlFolder -Filter *.sql

    # SQL Serverのバージョンチェック
    $sqlVersion = ($YamlOBJ.HOST.VERSION).trim()    # SQL Serverのバージョン
    $sqlVersion = $sqlVersion.Substring(21, 4)      # バージョン番号のみ取得
    $sqlVersion = [int]$sqlVersion
    # もし、2019より小さければCertificateをfalse, それ以外はtrue    
    if($sqlVersion -lt 2019){
        $Certificate = $false
    } else {
        $Certificate = $true
    }
    
    foreach($sqlFile in $SqlFiles){
        Write-Output "====================================" | Tee-Object -FilePath $LogPath -Append | Out-Default
        Write-Output $sqlFile.Name   | Tee-Object -FilePath $LogPath -Append | Out-Default
        try {
            # ファイルがUTF-8(CRLF)以外だったらUTF-8(CRLF)に変換する(nkfが必要)
            $fileEncoding = & nkf32 --guess $sqlFile.FullName # 文字コードと改行コードを判定する
            # 文字コードがuft8で改行がCRLFでなければ
            if ($fileEncoding -ne "UTF-8 (CRLF)") {
                # ファイル名の後ろに.utf8をつける
                $newName = $sqlFile.FullName + ".utf8(CRLF)"

                # utf8(CRLF)で保存する
                # 全角'－'が半角'-'に変換されるので--ms-ucs-mapを指定する(MS-UNICODEを指定する)
                & nkf32 --ms-ucs-map -x -wLw -O $sqlFile.FullName $newName
                $sqlFile = Get-Item -Path $newName
            }
            # SQLファイルを実行する
            # invoke-sqlcmd -ErrorAction Stop -TrustServerCertificate -InputFile $sqlFile.FullName -ServerInstance $ServerInstance -Database $Database -Username $Username -Password $password -QueryTimeout 0 | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | Format-Table -Property * -AutoSize -Wrap | Out-String -Width 4096 | tee-object -FilePath $LogPath -Append | Out-Default
            # SQL ServerのバージョンによってTrustServerCertificateの有無を変える
            Switch ($Certificate) {
                $true {
                    invoke-sqlcmd -TrustServerCertificate -ErrorAction Stop -InputFile $sqlFile.FullName -ServerInstance $ServerInstance -Database $Database -Username $Username -Password $password -QueryTimeout 0 | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | Format-Table -Property * -AutoSize -Wrap | Out-String -Width 4096 | tee-object -FilePath $LogPath -Append | Out-Default
                }
                $false {
                    invoke-sqlcmd -ErrorAction Stop -InputFile $sqlFile.FullName -ServerInstance $ServerInstance -Database $Database -Username $Username -Password $password -QueryTimeout 0 | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | Format-Table -Property * -AutoSize -Wrap | Out-String -Width 4096 | tee-object -FilePath $LogPath -Append | Out-Default
                }
            }
        }
        catch {
            # エラーを表示する
            Write-Output "///エラーが発生しました。///" | Tee-Object -FilePath $LogPath -Append | Out-Default
            Write-Output $_.Exception.Message | Tee-Object -FilePath $LogPath -Append | Out-Default      # エラー内容を表示
        }
        Write-Output "====================================" | Tee-Object -FilePath $LogPath -Append | Out-Default
    }
}