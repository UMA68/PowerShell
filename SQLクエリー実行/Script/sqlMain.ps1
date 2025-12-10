<#
.SYNOPSIS
SQL Serverのクエリファイルを自動実行し、結果をログに記録するスクリプト

.DESCRIPTION
指定されたフォルダ内の複数のSQLファイルをファイル名順で実行し、以下の処理を行います：
- SQLファイルの文字エンコーディング自動変換（UTF-8/CRLF対応）
- SQL Server接続情報の暗号化・復号化処理
- 実行結果の整形とログ記録
- エラーハンドリングと処理統計

.PARAMETER DecryptionKey
復号化鍵ファイル名（デフォルト: "Encryption.Key"）
Common フォルダに配置されている鍵ファイルを指定

.PARAMETER EnvYaml
設定ファイル名（デフォルト: "sql.yaml"）
YAML フォルダに配置されている設定ファイルを指定

.EXAMPLE
# デフォルト設定で実行
.\sqlMain.ps1

.EXAMPLE
# カスタム鍵と設定ファイルを指定
.\sqlMain.ps1 -DecryptionKey "production.key" -EnvYaml "prod.yaml"

.INPUTS
なし

.OUTPUTS
ログファイル: LOG/log_yyyyMMdd_HHmmss.log
- SQL実行結果
- エラーメッセージ
- 処理統計（成功数・エラー数）

.NOTES
Version: 1.0.0
Author: SQL Query Automation
Updated: 2025-12-09

必須モジュール:
- PowerShell-Yaml 0.4.7
- SqlServer 22.1.1

必須ツール:
- nkf32 (文字コード変換)

ディレクトリ構造:
PowerShell/
├── Common/
│   ├── Encryption.Key
│   ├── NoDoubleActivation.ps1
│   └── CheckCommand.ps1
└── SQLクエリー実行/
    ├── Script/
    │   └── sqlMain.ps1 (このファイル)
    ├── YAML/
    │   └── sql.yaml
    ├── SQL/
    │   ├── test.sql
    │   └── ...
    └── LOG/ (自動作成)

セキュリティ注意事項:
- 暗号化鍵（Encryption.Key）はマシン固有
- 別マシンへの移行時は鍵を再作成が必要
- パスワードファイル（*.pass）はバージョン管理から除外

トラブルシューティング:
- PowerShell-Yaml モジュール未インストール → Install-Module を実行
- SQL接続エラー → ホスト名/ポート/認証情報を確認
- 文字エンコーディング問題 → nkf32 のインストール確認

.LINK
ドキュメント: ../README.md
#>

# SQLファイルを実行するスクリプト

param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({ # ファイル名の検証
        # ファイル名としての有効性を検証
        if ($_ -match '[\\/:"*?<>|]') { # 禁止文字チェック
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ([string]::IsNullOrWhiteSpace($_)) { # 空文字チェック
            throw "ファイル名は空にできません"
        }
        if ($_.Length -gt 255) { # ファイル名長さ制限チェック
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true   # バリデーション(検証)成功
    })]
    [string]$DecryptionKey = "Encryption.Key",  # 復号化鍵ファイル名
    [Parameter(Mandatory=$false)]
    [ValidateScript({ # yamlファイル名の検証
        # ファイル名としての有効性を検証（.yaml または .yml 拡張子必須）
        if ($_ -notmatch '\.(yaml|yml)$') { # YAML拡張子チェック
            throw "YAMLファイルは .yaml または .yml 拡張子である必要があります: $_"
        }
        if ($_ -match '[\\/:"*?<>|]') { # 禁止文字チェック
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ([string]::IsNullOrWhiteSpace($_)) { # 空文字チェック
            throw "ファイル名は空にできません"
        }
        if ($_.Length -gt 255) { # ファイル名長さ制限チェック
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true   # バリデーション(検証)成功
    })]
    [string]$EnvYaml = "sql.yaml"               # 設定ファイル名
)

begin {

    # ====================================
    # ディレクトリとパスの初期化
    # ====================================
    # スクリプト実行位置から相対的にパスを構築
    $script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトディレクトリ
    $script:UpperDir = Split-Path -Parent $script:ScriptDir                       # SQLクエリー実行フォルダ
    $script:PowerShellDir = Split-Path -Parent $script:UpperDir                   # PowerShellフォルダ
    $script:ComPath = Join-Path -Path $script:PowerShellDir -ChildPath "Common"   # 共通スクリプトフォルダ
    $script:YamlDir = Join-Path -Path $script:UpperDir -ChildPath "YAML"          # 設定ファイルフォルダ
    $script:KeyPath = Join-Path -Path $script:ComPath -ChildPath $DecryptionKey   # 鍵ファイルパス
    $script:YamlPath = Join-Path -Path $script:YamlDir -ChildPath $EnvYaml        # 設定ファイルパス

    # ====================================
    # 共通スクリプトの読み込み
    # ====================================
    # 二重起動チェックとコマンド検証用スクリプトを読み込む
    try {
        . (Join-Path -Path $script:ComPath -ChildPath "NoDoubleActivation.ps1") -ErrorAction Stop   # 二重起動防止スクリプト読み込み
        . (Join-Path -Path $script:ComPath -ChildPath "CheckCommand.ps1") -ErrorAction Stop         # コマンド検証スクリプト読み込み
    } catch {
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $scriptName = $_.InvocationInfo.MyCommand.Name
            $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x30)
        } finally {
            if ($null -ne $obj) { # スクリプト読み込みエラー
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
        exit
    }
    
    # ====================================
    # 実行前の検証
    # ====================================
    # 二重起動防止と必要なコマンドの存在確認
    Test-NoDoubleActivation -Thread "sqlMain"  # 二重起動チェック
    Test-Command -ComName "nkf32"              # nkf32コマンド確認

    # ====================================
    # モジュール検証
    # ====================================
    # PowerShell-Yaml モジュールがインストールされているか確認
    $YamlModuleCount = ((Get-Module -ListAvailable -Name PowerShell-Yaml).Name).Count
    $obj = $null
    if ($YamlModuleCount -eq 0) { # モジュール未インストール
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup("PowerShell-Yamlモジュールがインストールされていません。処理を終了します。", 0, "警告", 0x30) | Out-Null
        } finally {
            if ($null -ne $obj) { # モジュール未インストール
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
        exit
    }
    
    # ====================================
    # 設定ファイルの読み込み
    # ====================================
    # YAML設定ファイルの存在確認
    if (-not (Test-Path -Path $YamlPath)) { # YAMLファイル無し
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($EnvYaml + "ファイルが見つかりません。処理を終了します。", 0, "エラー", 0x10) | Out-Null
        } finally {
            if ($null -ne $obj) { # YAMLファイル無し
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
        exit
    }

    # YAML設定ファイルを読み込む
    try {
        $script:YamlOBJ = Get-Content $script:YamlPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered 
    }
    catch {
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($EnvYaml + "ファイルが読み込めませんでした。処理を終了します。", 0, "警告", 0x30) | Out-Null
        } finally {
            if ($null -ne $obj) { # YAML読み込みエラー
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
        exit
    }

    # ====================================
    # PowerShellバージョン検証
    # ====================================
    # YAML設定のバージョンと実行バージョンを比較
    $pwsVerChk = ($PSVersionTable.PSVersion).ToString()
    $pwsAssumVer = $script:YamlOBJ.PowerShell.Version
    $obj = $null
    if ($pwsVerChk -ne $pwsAssumVer) {  # バージョン不一致
        try {
            $obj = New-Object -ComObject WScript.Shell
            [int]$retButton = $obj.Popup("実行中のPowerShellは " + $pwsVerChk + " です。`r`n必要なモジュールは PowerShell " + $script:YamlOBJ.PowerShell.Version + " を前提にインストールを行います。`r`n`r`n続行しますか？", 0, "警告", 0x31)
            switch ($retButton) {
                1 { break }  # OK
                2 { # キャンセル
                    if ($null -ne $obj) { # バージョン不一致
                        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                        $obj = $null
                    }
                    exit  # キャンセル
                }
            }
        } finally {
            if ($null -ne $obj) { # バージョン不一致
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
    }
    
    # ====================================
    # 必須モジュールのインポート
    # ====================================
    # YAMLに記述されたバージョンでモジュールをインポート
    foreach ($module in $script:YamlOBJ.Module.Keys) { # 各モジュールを処理
        try {
            Import-Module $script:YamlOBJ.Module.$module.Name -RequiredVersion $script:YamlOBJ.Module.$module.Version -ErrorAction Stop
        }
        catch {
            $obj = $null
            try {
                $obj = New-Object -ComObject WScript.Shell
                $obj.Popup($script:YamlOBJ.Module.$module.Name + "：" + $script:YamlOBJ.Module.$module.Version + " モジュールがインポートできませんでした。処理を終了します。", 0, "警告", 0x30) | Out-Null
            } finally {
                if ($null -ne $obj) { # モジュールインポートエラー
                    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                    $obj = $null
                }
            }
            exit
        }
    }

    # ====================================
    # ログファイルの初期化
    # ====================================
    # ログ出力先ディレクトリを作成（未存在の場合）
    $script:LogFolder = Join-Path -Path $script:UpperDir -ChildPath $script:YamlOBJ.LOG.FOLDER
    if (-not (Test-Path -Path $script:LogFolder)) { # ログフォルダがなければ作成
        New-Item -Path $script:LogFolder -ItemType Directory -Force | Out-Null
    }
    $LogFileName = $script:YamlOBJ.LOG.FILENAME + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + $script:YamlOBJ.LOG.EXTENSION
    $script:LogPath = Join-Path -Path $script:LogFolder -ChildPath $LogFileName

    # ====================================
    # SQL接続パラメータの定義
    # ====================================
    # ホスト、ポート、データベース、ユーザー名の設定
    if ($script:YamlOBJ.HOST.PORT) { # ポート指定がある場合
        [string]$script:ServerInstance = "$($script:YamlOBJ.HOST.SERVER),$($script:YamlOBJ.HOST.PORT)"
    } else { # ポート指定がない場合
        [string]$script:ServerInstance = $script:YamlOBJ.HOST.SERVER
    }
    [string]$script:Database = $script:YamlOBJ.HOST.DATABASE
    [string]$script:Username = $script:YamlOBJ.HOST.USERNAME
    [string]$pwFile = $script:YamlOBJ.HOST.PWF
    $script:PwFilePath = Join-Path -Path $script:UpperDir -ChildPath $pwFile

    # ====================================
    # 復号化鍵の読み込み
    # ====================================
    # パスワード復号化用の鍵ファイルを読み込む
    try {
        if (Test-Path -Path $script:KeyPath) { # 鍵ファイルが存在する場合
            [byte[]]$script:EncryptedKey = [System.IO.File]::ReadAllBytes($script:KeyPath)
            Write-Host "鍵ファイル『$DecryptionKey』を読み込みました。"
        } else { # 鍵ファイルが存在しない場合
            throw "鍵ファイル『$DecryptionKey』が見つかりません。"
        }
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($_.Exception.Message + "`r`n作成した $DecryptionKey を `"$($script:ComPath)`" へ置いてください。", 0, "エラー", 0x10)
        } finally {
            if ($null -ne $obj) { # 鍵ファイルエラー
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
        }
        exit
    }

    # ====================================
    # パスワードの復号化
    # ====================================
    # 暗号化されたパスワードファイルを復号化して平文に変換
    try {
        if (-not (Test-Path -Path $script:PwFilePath)) { # パスワードファイルが存在しない場合
            throw "パスワードファイル『$pwFile』が見つかりません。"
        }
        $password = Get-Content -Path $script:PwFilePath | ConvertTo-SecureString -Key $script:EncryptedKey -ErrorAction Stop
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
    
    # ====================================
    # SQLファイルの検出と準備
    # ====================================
    # YAML設定から SQL ファイル格納フォルダを取得
    $YamlSQL = $script:YamlOBJ.RELEASE.SQL.FolderBy[0]
    $script:SqlFolder = Join-Path -Path $script:UpperDir -ChildPath $YamlSQL
    
    # SQLフォルダの存在確認
    if (-not (Test-Path -Path $script:SqlFolder)) { # SQLフォルダ無し
        $errorMsg = "SQLフォルダ『$YamlSQL』が見つかりません。処理を終了します。"
        Write-Host $errorMsg -ForegroundColor Red
        Write-Output $errorMsg | Out-File -FilePath $script:LogPath -Append
        exit
    }
    
    # SQLファイルをファイル名順でソート取得
    $SqlFiles = Get-ChildItem -Path $script:SqlFolder -Filter *.sql | Sort-Object Name
    
    # SQLファイルが存在しない場合は警告
    if ($SqlFiles.Count -eq 0) { # SQLファイル無し
        $warnMsg = "SQLフォルダ内に.sqlファイルが見つかりません。"
        Write-Host $warnMsg -ForegroundColor Yellow
        Write-Output $warnMsg | Out-File -FilePath $script:LogPath -Append
        exit
    }

    # ====================================
    # SQL Serverバージョン判定
    # ====================================
    # TrustServerCertificate パラメータの必要性を判定
    # SQL Server 2019以降ではTrustServerCertificate=true が必要
    $script:TrustServerCert = $false
    if ($script:YamlOBJ.HOST.VERSION -match 'SQL Server (\d{4})') { # バージョン情報がある場合
        $sqlVersion = [int]$Matches[1]
        $script:TrustServerCert = ($sqlVersion -ge 2019)
    } else { # バージョン情報が不明な場合は警告を表示して有効にする
        Write-Host "SQL Serverバージョンの判定に失敗しました。TrustServerCertificateを有効にします。" -ForegroundColor Yellow
        $script:TrustServerCert = $true
    }
    
    # ====================================
    # SQL実行と結果処理
    # ====================================
    # 実行カウンター初期化
    $successCount = 0
    $errorCount = 0
    
    foreach ($sqlFile in $SqlFiles) { # 各SQLファイルを処理
        Write-Output "====================================" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
        Write-Output $sqlFile.Name | Tee-Object -FilePath $script:LogPath -Append | Out-Default
        
        $tempFile = $null
        try {
            # ====================================
            # ファイル文字エンコーディング変換
            # ====================================
            # ファイルがUTF-8(CRLF)以外だったらUTF-8(CRLF)に変換する
            $fileEncoding = & nkf32 --guess $sqlFile.FullName
            if ($fileEncoding -ne "UTF-8 (CRLF)") { # UTF-8(CRLF)でない場合
                Write-Output "///文字エンコーディング変換: $fileEncoding → UTF-8 (CRLF)///" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
                $tempFile = $sqlFile.FullName + ".utf8(CRLF)"
                & nkf32 --ms-ucs-map -x -wLw -O $sqlFile.FullName $tempFile # UTF-8(CRLF)に変換して一時ファイルに保存
                Write-Output "///一時ファイル作成: $tempFile///" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
                $sqlFile = Get-Item -Path $tempFile
            }
            
            # ====================================
            # SQL実行
            # ====================================
            # invoke-sqlcmd パラメータをスプラッティングで構築
            $invokeParams = @{ # invoke-sqlcmd パラメータ
                ErrorAction     = 'Stop'
                InputFile       = $sqlFile.FullName
                ServerInstance  = $script:ServerInstance
                Database        = $script:Database
                Username        = $script:Username
                Password        = $password
                QueryTimeout    = 0
            }
            
            # SQL Server 2019以降の場合のみ TrustServerCertificate を追加
            if ($script:TrustServerCert) { # TrustServerCertificate が必要な場合
                $invokeParams['TrustServerCertificate'] = $true
            }
            
            # SQLクエリーを実行
            $result = invoke-sqlcmd @invokeParams
            
            # ====================================
            # 結果出力
            # ====================================
            # 結果セットが空の場合は専用メッセージ、そうでなければ表形式で出力
            if ($null -eq $result -or @($result).Count -eq 0) { # 結果セットなし
                Write-Output "(結果セットなし)" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
            } else { # 結果セットあり
                $result | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | Format-Table -Property * -AutoSize -Wrap | Out-String -Width 4096 | Tee-Object -FilePath $script:LogPath -Append | Out-Default
            }
            $successCount++
        }
        catch {
            # ====================================
            # エラー処理
            # ====================================
            # SQL実行エラーをログに記録
            Write-Output "///エラーが発生しました。///" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
            Write-Output $_.Exception.Message | Tee-Object -FilePath $script:LogPath -Append | Out-Default
            $errorCount++
        }
        finally {
            # ====================================
            # クリーンアップ
            # ====================================
            # 一時ファイル（UTF-8変換後）が存在すれば削除
            if ($tempFile -and (Test-Path -Path $tempFile)) {   # 一時ファイルの存在チェック
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Output "====================================" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
    }
    
    # ====================================
    # 実行結果サマリー
    # ====================================
    # 処理完了時に統計情報を表示・ログ記録
    $totalCount = $SqlFiles.Count
    $summaryMsg = "`n実行完了: 合計 $totalCount 件 (成功: $successCount 件, エラー: $errorCount 件)"
    Write-Host $summaryMsg -ForegroundColor Cyan
    Write-Output $summaryMsg | Out-File -FilePath $script:LogPath -Append
}