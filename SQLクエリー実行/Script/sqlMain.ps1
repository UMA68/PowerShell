<#
.SYNOPSIS
SQL Serverのクエリファイルを自動実行し、結果をログに記録するスクリプト

.DESCRIPTION
指定されたフォルダ内の複数のSQLファイルをファイル名順で実行し、以下の処理を行います：
- SQLファイルの文字エンコーディング自動変換（UTF-8/CRLF対応）
- SQL Server接続情報の暗号化・復号化処理
- 実行結果の整形とログ記録
- エラーハンドリングと処理統計
- 二重起動防止機能
- 処理時間計測と成功率表示
- ログファイルの自動表示
    
主な機能:
- YAML設定ファイルによる柔軟な構成管理
- 暗号化されたパスワードファイルの安全な復号化
- nkf32による文字エンコーディング自動検出・変換
- SQL Server 2019以降のTrustServerCertificate対応
- 詳細なエラーログ（例外タイプ、メッセージ）
- 処理結果サマリ（成功数、エラー数、成功率）
- COM オブジェクトの安全な管理
- スクリプトスコープによる変数管理の一貫性
    
スクリプトは以下の順序で実行されます:
1. パラメータ検証（ValidateScript属性）
2. 二重起動チェック（ミューテックスベース）
3. 必須コマンド確認（nkf32）
4. PowerShell-Yamlモジュール検証
5. YAML設定ファイル読み込み
6. PowerShellバージョン確認（YAML指定バージョンとの照合）
7. 必須モジュールのインポート（SqlServer等）
8. ログディレクトリ作成
9. 暗号化鍵とパスワードの復号化
10. SQLファイルの検出とソート
11. SQL Server接続パラメータ設定
12. 各SQLファイルの実行
    - 文字エンコーディング変換（必要時）
    - SQL実行
    - 結果の整形と出力
    - エラーハンドリング
13. 処理結果サマリ出力
14. ログファイルの自動表示

.PARAMETER DecryptionKey
復号化鍵ファイル名（デフォルト: "Encryption.Key"）
Common フォルダに配置されている鍵ファイルを指定します。
    
パラメータ検証:
- 空白文字のみの入力を拒否
- ファイル名に使用できない文字（\ / : * ? " < > |）を検証
- 最大255文字の長さ制限

.PARAMETER EnvYaml
設定ファイル名（デフォルト: "sql.yaml"）
YAML フォルダに配置されている設定ファイルを指定します。
    
パラメータ検証:
- 空白文字のみの入力を拒否
- .yaml または .yml 拡張子が必須
- ファイル名に使用できない文字を検証
- 最大255文字の長さ制限

.EXAMPLE
# デフォルト設定で実行
.\sqlMain.ps1

.EXAMPLE
# カスタム鍵と設定ファイルを指定
.\sqlMain.ps1 -DecryptionKey "production.key" -EnvYaml "prod.yaml"

.EXAMPLE
# ステージング環境の設定で実行
.\sqlMain.ps1 -EnvYaml "sql_stg.yaml"

.INPUTS
なし

.OUTPUTS
ログファイル: LOG/log_yyyyMMdd_HHmmss.log
- SQL実行結果
- エラーメッセージ
- 処理統計（成功数・エラー数・成功率）

.NOTES
    File Name      : sqlMain.ps1
    Author         : UMA68
    Version        : 2.0.0
    Release Date   : 2025-12-12
    Last Modified  : 2025-12-12
    
    前提条件:
    - PowerShell 7.3.9 以上
    - Windows PowerShell実行ポリシー: RemoteSigned 以上
    
    必須モジュール:
    - PowerShell-Yaml 0.4.7 以上
    - SqlServer 22.1.1 以上
    
    必須ツール:
    - nkf32 (文字コード変換)
    
    依存ファイル:
    - Common/NoDoubleActivation.ps1 : 二重起動防止機能
    - Common/CheckCommand.ps1       : コマンド存在確認
    - Common/Encryption.Key         : 暗号化鍵ファイル
    - YAML/sql.yaml                 : 設定ファイル
    - *.pass                        : 暗号化パスワードファイル
    
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
            └── log_yyyyMMdd_HHmmss.log
    
    処理結果サマリ:
    - 合計ファイル数: 処理対象SQLファイルの総数
    - 成功数: 正常に実行されたファイル数
    - エラー数: 実行中にエラーが発生したファイル数
    - 成功率: (合計 - エラー) / 合計 × 100 (%)
    - 処理時間: MM:Min SS:Sec 形式
    
    セキュリティ注意事項:
    - 暗号化鍵（Encryption.Key）はマシン固有
    - 別マシンへの移行時は鍵を再作成が必要
    - パスワードファイル（*.pass）はバージョン管理から除外
    - 復号化されたパスワードはメモリ上で使用後に自動クリア
    
    変更履歴:
    v2.0.0 (2025-12-12)
        - exit文の除去とCanExecuteProcessフラグ導入
        - ShowPopupヘルパー関数追加（COM解放保証）
        - Test-NoDoubleActivation戻り値確認
        - Test-Command戻り値確認とエラーハンドリング
        - パラメータ検証順序の最適化（空文字チェック優先）
        - 変数スコープの統一（$script:password）
        - 開始ログ追加（ホスト名、ユーザー名、サーバー、DB）
        - SQL実行エラー時の例外タイプ記録
        - ログファイルの自動表示機能
        - 成功率計算と表示
        - 処理時間計測と表示（MM:Min SS:Sec形式）
        - PowerShellバージョンチェックのフラグ設定
        - パスワードの安全なクリア処理
    
    v1.0.0 (2025-12-09)
        - 初版リリース
        - 基本的なSQL実行機能実装
        - YAML設定ファイル対応
        - 暗号化パスワード対応
        - 文字エンコーディング変換
    
    トラブルシューティング:
    - PowerShell-Yaml モジュール未インストール → Install-Module PowerShell-Yaml を実行
    - nkf32コマンドが見つからない → nkf32.exeをパスの通った場所に配置
    - SQL接続エラー → ホスト名/ポート/認証情報を確認
    - 文字エンコーディング問題 → nkf32 のインストールと動作確認
    - 鍵ファイルエラー → Encryption.Keyが正しい場所にあるか確認
    - パスワード復号化エラー → 鍵ファイルとパスワードファイルの対応を確認

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    Wiki: https://github.com/UMA68/PowerShell/wiki
#>

# SQLファイルを実行するスクリプト

param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ # ファイル名の検証
        # ファイル名としての有効性を検証
        if ([string]::IsNullOrWhiteSpace($_)) { # 空文字チェック
            throw "ファイル名は空にできません"
        }
        if ($_ -match '[\\/:"*?<>|]') { # 禁止文字チェック
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ($_.Length -gt 255) { # ファイル名長さ制限チェック
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true   # バリデーション(検証)成功
    })]
    [string]$DecryptionKey = "Encryption.Key",  # 復号化鍵ファイル名
    [Parameter(Mandatory = $false)]
    [ValidateScript({ # yamlファイル名の検証
        # ファイル名としての有効性を検証（.yaml または .yml 拡張子必須）
        if ([string]::IsNullOrWhiteSpace($_)) { # 空文字チェック
            throw "ファイル名は空にできません"
        }
        if ($_ -notmatch '\.(yaml|yml)$') { # YAML拡張子チェック
            throw "YAMLファイルは .yaml または .yml 拡張子である必要があります: $_"
        }
        if ($_ -match '[\\/:"*?<>|]') { # 禁止文字チェック
            throw "ファイル名に使用できない文字が含まれています: $_"
        }
        if ($_.Length -gt 255) { # ファイル名長さ制限チェック
            throw "ファイル名が長すぎます（最大255文字）: $($_.Length)文字"
        }
        $true   # バリデーション(検証)成功
    })]
    [string]$EnvYaml = "sql.yaml"               # 設定ファイル名
)

begin {

    # 共通ポップアップ関数（COM解放を保証）
    $script:ShowPopup = { # ポップアップ表示関数
        param(
            [string]$Message,   # ポップアップメッセージ
            [string]$Title,     # ポップアップタイトル
            [int]$Icon = 0x30   # 0x10:エラー, 0x20:警告, 0x30:情報
        )
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($Message, 0, $Title, $Icon) | Out-Null
        }
        finally {
            if ($null -ne $obj) { # COMオブジェクトの解放
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_ }
                $obj = $null
            }
        }
    }

    $script:CanExecuteProcess = $true
    $script:StartTime = Get-Date

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
        & $script:ShowPopup -Message ("$($_.InvocationInfo.MyCommand.Name) の読み込みに失敗しました。処理を終了します。`r`n`r`n" + $_.Exception.Message) -Title "エラー" -Icon 0x30
        $script:CanExecuteProcess = $false
        return
    }
    
    # ====================================
    # 実行前の検証
    # ====================================
    # 二重起動防止と必要なコマンドの存在確認
    if (-not (Test-NoDoubleActivation -Thread "sqlMain")) { # 二重起動チェックで既に起動中の場合
        $script:CanExecuteProcess = $false
        return
    }
    
    if (-not (Test-Command -ComName "nkf32")) { # nkf32コマンドが存在しない場合
        & $script:ShowPopup -Message "nkf32コマンドが見つかりません。処理を終了します。" -Title "エラー" -Icon 0x10
        $script:CanExecuteProcess = $false
        return
    }

    # ====================================
    # モジュール検証
    # ====================================
    # PowerShell-Yaml モジュールがインストールされているか確認
    $YamlModuleCount = ((Get-Module -ListAvailable -Name PowerShell-Yaml).Name).Count
    if ($YamlModuleCount -eq 0) { # モジュール未インストール
        & $script:ShowPopup -Message "PowerShell-Yamlモジュールがインストールされていません。処理を終了します。" -Title "警告" -Icon 0x30
        $script:CanExecuteProcess = $false
        return
    }
    
    # ====================================
    # 設定ファイルの読み込み
    # ====================================
    # YAML設定ファイルの存在確認
    if (-not (Test-Path -Path $YamlPath)) { # 設定ファイルが存在しない場合
        & $script:ShowPopup -Message ($EnvYaml + "ファイルが見つかりません。処理を終了します。") -Title "エラー" -Icon 0x10
        $script:CanExecuteProcess = $false
        return
    }

    # YAML設定ファイルを読み込む
    try {
        $script:YamlOBJ = Get-Content $script:YamlPath -Raw -ErrorAction Stop | ConvertFrom-Yaml -Ordered 
    }
    catch {
        & $script:ShowPopup -Message ($EnvYaml + "ファイルが読み込めませんでした。処理を終了します。`r`n`r`n" + $_.Exception.Message) -Title "警告" -Icon 0x30
        $script:CanExecuteProcess = $false
        return
    }

    # ====================================
    # PowerShellバージョン検証
    # ====================================
    # YAML設定のバージョンと実行バージョンを比較
    $pwsVerChk = ($PSVersionTable.PSVersion).ToString()
    $pwsAssumVer = $script:YamlOBJ.PowerShell.Version
    if ($pwsVerChk -ne $pwsAssumVer) { # バージョン不一致
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            [int]$retButton = $obj.Popup("実行中のPowerShellは " + $pwsVerChk + " です。`r`n必要なモジュールは PowerShell " + $script:YamlOBJ.PowerShell.Version + " を前提にインストールを行います。`r`n`r`n続行しますか？", 0, "警告", 0x31)
            if ($retButton -eq 2) { # キャンセル
                $script:CanExecuteProcess = $false
                return
            }
        } finally {
            if ($null -ne $obj) { # COMオブジェクト解放
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_ }
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
            & $script:ShowPopup -Message ($script:YamlOBJ.Module.$module.Name + "：" + $script:YamlOBJ.Module.$module.Version + " モジュールがインポートできませんでした。処理を終了します。") -Title "警告" -Icon 0x30
            $script:CanExecuteProcess = $false
            return
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
            Write-Information "鍵ファイル『$DecryptionKey』を読み込みました。"
        } else { # 鍵ファイルが存在しない場合
            throw "鍵ファイル『$DecryptionKey』が見つかりません。"
        }
    } catch {
        Write-Error $_.Exception.Message
        & $script:ShowPopup -Message ($_.Exception.Message + "`r`n作成した $DecryptionKey を `"$($script:ComPath)`" へ置いてください。") -Title "エラー" -Icon 0x10
        $script:CanExecuteProcess = $false
        return
    }

    # ====================================
    # パスワードの復号化
    # ====================================
    # 暗号化されたパスワードファイルを復号化して平文に変換
    try {
        if (-not (Test-Path -Path $script:PwFilePath)) { # パスワードファイルが存在しない場合
            throw "パスワードファイル『$pwFile』が見つかりません。"
        }
        $script:password = Get-Content -Path $script:PwFilePath | ConvertTo-SecureString -Key $script:EncryptedKey -ErrorAction Stop
    }
    catch {
        Write-Warning "パスワードの復号化に失敗しました。"
        Write-Error $_.Exception.Message
        Write-Warning "パスワードファイル『$pwFile』と鍵ファイル『$DecryptionKey』が正しいことを確認してください。"
        Write-Information "何かキーを押してください。"
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        $script:CanExecuteProcess = $false
        return
    }
    $script:password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:password))

}
process {

    if (-not $script:CanExecuteProcess) { # 実行不可フラグが立っている場合は終了
        return
    }
    
    # ====================================
    # 開始ログ出力
    # ====================================
    Write-Output "Script started." | Tee-Object -FilePath $script:LogPath -Append | Out-Default
    Write-Output "HOST: $env:COMPUTERNAME" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
    Write-Output "USER: $env:USERNAME" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
    Write-Output "Server: $script:ServerInstance" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
    Write-Output "Database: $script:Database" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
    Write-Output "" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
    
    # ====================================
    # SQLファイルの検出と準備
    # ====================================
    # YAML設定から SQL ファイル格納フォルダを取得
    $YamlSQL = $script:YamlOBJ.RELEASE.SQL.FolderBy[0]
    $script:SqlFolder = Join-Path -Path $script:UpperDir -ChildPath $YamlSQL
    
    # SQLフォルダの存在確認
    if (-not (Test-Path -Path $script:SqlFolder)) { # SQLフォルダ無し
        $errorMsg = "SQLフォルダ『$YamlSQL』が見つかりません。処理を終了します。"
        Write-Error $errorMsg
        Write-Output $errorMsg | Out-File -FilePath $script:LogPath -Append
        $script:CanExecuteProcess = $false
        return
    }
    
    # SQLファイルをファイル名順でソート取得
    $SqlFiles = Get-ChildItem -Path $script:SqlFolder -Filter *.sql | Sort-Object Name
    
    # SQLファイルが存在しない場合は警告
    if ($SqlFiles.Count -eq 0) { # SQLファイル無し
        $warnMsg = "SQLフォルダ内に.sqlファイルが見つかりません。"
        Write-Warning $warnMsg
        Write-Output $warnMsg | Out-File -FilePath $script:LogPath -Append
        $script:CanExecuteProcess = $false
        return
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
        Write-Warning "SQL Serverバージョンの判定に失敗しました。TrustServerCertificateを有効にします。"
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
                ErrorAction = 'Stop'
                InputFile = $sqlFile.FullName
                ServerInstance = $script:ServerInstance
                Database = $script:Database
                Username = $script:Username
                Password = $script:Password
                QueryTimeout = 0
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
            Write-Output "Error Type: $($_.Exception.GetType().FullName)" | Tee-Object -FilePath $script:LogPath -Append | Out-Default
            Write-Output $_.Exception.Message | Tee-Object -FilePath $script:LogPath -Append | Out-Default
            $errorCount++
        }
        finally {
            # ====================================
            # クリーンアップ
            # ====================================
            # 一時ファイル（UTF-8変換後）が存在すれば削除
            if ($tempFile -and (Test-Path -Path $tempFile)) { # 一時ファイルの存在チェック
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
    Write-Information $summaryMsg
    Write-Output $summaryMsg | Out-File -FilePath $script:LogPath -Append

    if ($totalCount -gt 0) { # 成功率計算
        $successRate = [math]::Round((($totalCount - $errorCount) / $totalCount) * 100, 2)
        $rateMsg = "成功率: $successRate%"
        Write-Information $rateMsg
        Write-Output $rateMsg | Out-File -FilePath $script:LogPath -Append
    }
}

end {
    $script:EndTime = Get-Date
    $elapsed = $script:EndTime - $script:StartTime

    if (-not $script:CanExecuteProcess) { # エラー終了時の処理
        Write-Warning "前段のエラーにより処理を完了できませんでした。"
        Write-Information ("処理時間: {0:D2}:Min {1:D2}:Sec" -f $elapsed.Minutes, $elapsed.Seconds)
        $script:password = $null
        # エラー時も何かキーを押すまで待機
        Write-Information "何かキーを押してください。"
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        return
    }

    Write-Information ("処理時間: {0:D2}:Min {1:D2}:Sec" -f $elapsed.Minutes, $elapsed.Seconds)
    $script:password = $null

    # 何かキーを押して終了
    Write-Information "何かキーを押してください。"   
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

    # ログを表示
    Invoke-Item -Path $script:LogPath

}