# SQLファイルを実行するスクリプト

param(
    [string]$DecryptionKey = "Encryption.Key",  # 復号化鍵ファイル名
    [string]$EnvYaml = "sql.yaml"               # 設定ファイル名
)

begin {

    # スクリプトのディレクトリ取得
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ取得
    $UpperDir = Split-Path -Parent $ScriptDir                       # スクリプトの親ディレクトリ取得
    $PowerShellDir = Split-Path -Parent $UpperDir                   # PowerShellディレクトリ
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"   # 共通スクリプト格納ディレクトリ
    $Yaml = Join-Path -Path $UpperDir -ChildPath "YAML"             # yamlファイルの格納場所
    $KeyPath = Join-Path -Path $comPath -ChildPath $DecryptionKey   # 鍵ファイルのパス
    $YamlPath = Join-Path -Path $Yaml -ChildPath $EnvYaml           # yamlファイルのパス

    # .ps1ファイル読み込み
    try {
        . (Join-Path -Path $comPath -ChildPath "NoDoubleActivation.ps1") -ErrorAction Stop
        . (Join-Path -Path $comPath -ChildPath "CheckCommand.ps1") -ErrorAction Stop
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $scriptName = $_.InvocationInfo.MyCommand.Name
        $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x30)
        exit
    }
    
    # 実行前のチェック。問題があったら終了
    Test-NoDoubleActivation -Thread "sqlMain"  # 二重起動チェック
    Test-Command -ComName "nkf32"              # nkf32の存在を確認(nkf32.exeと拡張子付も可)

    # PowerShell-Yamlモジュールがインストールされていない場合は終了
    $YamlModuleCount = ((Get-Module -ListAvailable -Name PowerShell-Yaml).Name).Count
    if ($YamlModuleCount -eq 0) {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("PowerShell-Yamlモジュールがインストールされていません。処理を終了します。", 0, "警告", 0x30) | Out-Null
        exit
    }
    
    # yamlファイルの存在確認
    if (-not (Test-Path -Path $YamlPath)) {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($EnvYaml + "ファイルが見つかりません。処理を終了します。", 0, "エラー", 0x10) | Out-Null
        exit
    }

    # yamlファイルの読み込み
    try {
        $YamlOBJ = Get-Content $YamlPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered 
    }
    catch {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($EnvYaml + "ファイルが読み込めませんでした。処理を終了します。", 0, "警告", 0x30) | Out-Null
        exit
    }

    # PowerShellのバージョンチェック
    $pwsVerChk = ($PSVersionTable.PSVersion).ToString()
    $pwsAssumVer = $YamlOBJ.PowerShell.Version
    if ($pwsVerChk -ne $pwsAssumVer) {
        $obj = New-Object -ComObject WScript.Shell
        [int]$retButton = $obj.Popup("実行中のPowerShellは " + $pwsVerChk + " です。`r`n必要なモジュールは PowerShell " + $pwsAssumVer + " を前提にインストールを行います。`r`n`r`n続行しますか？", 0, "警告", 0x30)
        switch ($retButton) {
            6 { break }  # はい
            7 { exit }   # いいえ
        }
    }
    
    # yamlに記述されたバージョンのモジュールを使用する
    foreach ($module in $YamlOBJ.Module.Keys) {
        try {
            Import-Module $YamlOBJ.Module.$module.Name -RequiredVersion $YamlOBJ.Module.$module.Version -ErrorAction Stop
        }
        catch {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($YamlOBJ.Module.$module.Name + "：" + $YamlOBJ.Module.$module.Version + " モジュールがインポートできませんでした。処理を終了します。", 0, "警告", 0x30) | Out-Null
            exit
        }
    }

    # LOGの定義
    $LogFolder = Join-Path -Path $UpperDir -ChildPath $YamlOBJ.LOG.FOLDER
    # LOGフォルダが存在しない場合は作成
    if (-not (Test-Path -Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
    $LogFileName = $YamlOBJ.LOG.FILENAME + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + $YamlOBJ.LOG.EXTENSION
    $LogPath = Join-Path -Path $LogFolder -ChildPath $LogFileName

    # 接続パラメータの定義
    if ($YamlOBJ.HOST.PORT) {
        [string]$ServerInstance = "$($YamlOBJ.HOST.SERVER),$($YamlOBJ.HOST.PORT)"
    } else {
        [string]$ServerInstance = $YamlOBJ.HOST.SERVER
    }
    [string]$Database = $YamlOBJ.HOST.DATABASE
    [string]$Username = $YamlOBJ.HOST.USERNAME
    [string]$pwFile = $YamlOBJ.HOST.PWF
    $pwFilePath = Join-Path -Path $UpperDir -ChildPath $pwFile

    # 鍵ファイルを読み込む
    try {
        if (Test-Path -Path $KeyPath) {
            [byte[]]$EncryptedKey = [System.IO.File]::ReadAllBytes($KeyPath)
            Write-Host "鍵ファイル『$DecryptionKey』を読み込みました。"
        } else {
            throw "鍵ファイル『$DecryptionKey』が見つかりません。"
        }
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup($_.Exception.Message + "`r`n作成した $DecryptionKey を `"$comPath`" へ置いてください。", 0, "エラー", 0x10)
        exit
    }

    # パスワードファイルを復号化
    try {
        if (-not (Test-Path -Path $pwFilePath)) {
            throw "パスワードファイル『$pwFile』が見つかりません。"
        }
        $password = Get-Content -Path $pwFilePath | ConvertTo-SecureString -Key $EncryptedKey -ErrorAction Stop
    }
    catch {
        Write-Host "パスワードの復号化に失敗しました。" -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "パスワードファイル『$pwFile』と鍵ファイル『$DecryptionKey』が正しいことを確認してください。" -ForegroundColor Yellow
        Write-Host "何かキーを押してください。" -ForegroundColor Yellow
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        exit
    }
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

}
process {
    
    # SQLフォルダ内のファイルをinvoke-sqlcmdで実行する
    $YamlSQL = $YamlOBJ.RELEASE.SQL.FolderBy[0]
    $SqlFolder = Join-Path -Path $UpperDir -ChildPath $YamlSQL
    
    # SQLフォルダの存在確認
    if (-not (Test-Path -Path $SqlFolder)) {
        $errorMsg = "SQLフォルダ『$YamlSQL』が見つかりません。処理を終了します。"
        Write-Host $errorMsg -ForegroundColor Red
        Write-Output $errorMsg | Out-File -FilePath $LogPath -Append
        exit
    }
    
    $SqlFiles = Get-ChildItem -Path $SqlFolder -Filter *.sql | Sort-Object Name
    
    # SQLファイルが存在しない場合は警告
    if ($SqlFiles.Count -eq 0) {
        $warnMsg = "SQLフォルダ内に.sqlファイルが見つかりません。"
        Write-Host $warnMsg -ForegroundColor Yellow
        Write-Output $warnMsg | Out-File -FilePath $LogPath -Append
        exit
    }

    # SQL Serverのバージョンチェック（正規表現で抽出）
    $TrustServerCert = $false
    if ($YamlOBJ.HOST.VERSION -match 'SQL Server (\d{4})') {
        $sqlVersion = [int]$Matches[1]
        $TrustServerCert = ($sqlVersion -ge 2019)
    } else {
        Write-Host "SQL Serverバージョンの判定に失敗しました。TrustServerCertificateを有効にします。" -ForegroundColor Yellow
        $TrustServerCert = $true
    }
    
    # SQL実行カウンター
    $successCount = 0
    $errorCount = 0
    
    foreach ($sqlFile in $SqlFiles) {
        Write-Output "====================================" | Tee-Object -FilePath $LogPath -Append | Out-Default
        Write-Output $sqlFile.Name | Tee-Object -FilePath $LogPath -Append | Out-Default
        
        $tempFile = $null
        try {
            # ファイルがUTF-8(CRLF)以外だったらUTF-8(CRLF)に変換する
            $fileEncoding = & nkf32 --guess $sqlFile.FullName
            if ($fileEncoding -ne "UTF-8 (CRLF)") {
                $tempFile = $sqlFile.FullName + ".utf8(CRLF)"
                & nkf32 --ms-ucs-map -x -wLw -O $sqlFile.FullName $tempFile
                $sqlFile = Get-Item -Path $tempFile
            }
            
            # SQL実行パラメータ（スプラッティング）
            $invokeParams = @{
                ErrorAction     = 'Stop'
                InputFile       = $sqlFile.FullName
                ServerInstance  = $ServerInstance
                Database        = $Database
                Username        = $Username
                Password        = $password
                QueryTimeout    = 0
            }
            
            if ($TrustServerCert) {
                $invokeParams['TrustServerCertificate'] = $true
            }
            
            # SQL実行
            $result = invoke-sqlcmd @invokeParams
            if ($null -eq $result -or @($result).Count -eq 0) {
                Write-Output "(結果セットなし)" | Tee-Object -FilePath $LogPath -Append | Out-Default
            } else {
                $result | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | Format-Table -Property * -AutoSize -Wrap | Out-String -Width 4096 | Tee-Object -FilePath $LogPath -Append | Out-Default
            }
            $successCount++
        }
        catch {
            Write-Output "///エラーが発生しました。///" | Tee-Object -FilePath $LogPath -Append | Out-Default
            Write-Output $_.Exception.Message | Tee-Object -FilePath $LogPath -Append | Out-Default
            $errorCount++
        }
        finally {
            # 一時ファイルが作成されていれば削除
            if ($tempFile -and (Test-Path -Path $tempFile)) {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Output "====================================" | Tee-Object -FilePath $LogPath -Append | Out-Default
    }
    
    # 実行結果サマリー
    $totalCount = $SqlFiles.Count
    $summaryMsg = "`n実行完了: 合計 $totalCount 件 (成功: $successCount 件, エラー: $errorCount 件)"
    Write-Host $summaryMsg -ForegroundColor Cyan
    Write-Output $summaryMsg | Out-File -FilePath $LogPath -Append
}