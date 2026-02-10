<#
.SYNOPSIS
    YAMLファイルに記述されたPowerShellモジュールを一括インストールするスクリプト

.DESCRIPTION
    このスクリプトは、YAML設定ファイルに定義されたPowerShellモジュールを自動的にインストールします。
    begin-process-end パイプライン構造により、エラーハンドリングと制御フローを適切に管理します。
    
    以下の機能を提供します：
    
    1. YAMLファイルからモジュール情報を読み込み
    2. 指定されたバージョンのモジュール存在チェック
    3. 不足しているモジュールの自動インストール
    4. PowerShellバージョンの検証と警告表示
    5. 二重起動の防止（最優先チェック）
    6. インストール結果の詳細ログ記録
    7. エラー時・二重起動時の適切な処理

.PARAMETER envFileName
    使用する環境設定YAMLファイル名を指定します。
    省略時は "Env.yaml" が使用されます。
    
    ファイルは YAML フォルダ内に配置する必要があります。
.PARAMETER ShowInConsole
    コンソールに詳しいログを表示します。
    省略時は $false （ログファイルを作成して表示しない）。
    
    次の場合に役立つです：
    - デバッグ時のリアルタイム追記の確認
    - インストール細控の空運での事実確認
.EXAMPLE
    .\InstMain.ps1
    
    デフォルトの Env.yaml を使用してモジュールをインストールします。
    1. 二重起動チェックが最優先で実行されます
    2. PowerShell-Yaml モジュールを自動検証・インストール
    3. YAML ファイルからモジュール定義を読み込み
    4. PowerShell バージョンを検証（不一致時は警告表示）
    5. 各モジュールの存在確認とインストール実行
    6. 結果をログファイルに記録
    7. 完了ダイアログ表示後、ログファイルを自動で開く

.EXAMPLE
    .\InstMain.ps1 -envFileName "Production.yaml"
    
    カスタム設定ファイル Production.yaml を使用してインストールします。

.EXAMPLE
    .\InstMain.ps1 -ShowInConsole
    
    コンソールに詳しいログを表示しながらインストールを実行します。
    デバッグ時や処理細控の確認に宇いです。

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    None
    標準出力はありません。結果はログファイルに記録され、自動的に表示されます。

.NOTES
    FileName:      InstMain.ps1
    Author:        UMA68
    Version:       1.2.0
    LastModified:  2026-01-20
    Prerequisites: - PowerShell 5.1以上
                   - NoDoubleActivation.ps1 がCommonフォルダーに存在すること
                   - Write-CommonLog.ps1 がCommonフォルダーに存在すること
                   - Check-EnvModule.ps1 が同じScriptフォルダーに存在すること
                   - Check-YamlModule.ps1 が同じScriptフォルダーに存在すること
    RequiredModules: powershell-yaml (自動インストール)
    
    変更履歴:
    v1.2.0 (2026-01-20)
        - -ShowInConsole スイッチパラメータを追加
        - コンソールへの詳しいログ表示に対応
        - Check-EnvModule.ps1、Check-YamlModule.ps1を-Quietパラメータで制御
        - ScriptAnalyzer専颁の修正（空のcatchブロック、スペースを追加）
    
    v1.1.0 (2025-12-11)
        - begin-process-end 構造に変更
        - 二重起動チェックを begin ブロックで最優先実行
        - 制御フローフラグ（$script:CanExecuteProcess）を導入
        - エラー時・二重起動時の適切なハンドリングを実装
        - YAML読み込みとモジュール検証を Process ブロックに移動
        - end ブロックでのフラグチェックによる条件分岐
        - COM オブジェクトのリソース解放を強化
    
    v1.0.0 (初版)
        - 基本的なモジュールインストール機能を実装
    
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
    
    実行フロー:
    【begin ブロック】
        1. 制御フローフラグを初期化（$script:CanExecuteProcess = $true）
        2. ディレクトリパスを構築
        3. 環境変数を取得（ユーザー名、ホスト名）
        4. NoDoubleActivation.ps1 を読み込み
        5. 二重起動チェックを実行（最優先）
           → 二重起動の場合: フラグを $false に設定して return
        6. ログファイルパスを初期化
        7. その他の共通スクリプトを読み込み
           → エラー時: フラグを $false に設定
    
    【Process ブロック】
        1. フラグをチェック（$false の場合は return でスキップ）
        2. PowerShell-Yaml モジュールを検証・インストール
        3. YAML ファイルを読み込み
           → エラー時: フラグを $false に設定して return
        4. PowerShell バージョンを検証
           → 不一致時: 警告ダイアログを表示、キャンセル時は return
        5. ログ記録を開始（ホスト名、ユーザー名、バージョン情報）
        6. 各モジュールをチェック・インストール
        7. ログに終了マーカーを記録
    
    【end ブロック】
        1. フラグをチェック（$false の場合は何もせず return）
        2. 完了ダイアログを表示
        3. ログファイル末尾にログの見方を追記
        4. ログファイルを自動で開く
    
    セキュリティ:
        - 管理者権限が必要な場合があります
        - 二重起動防止機構により、同時実行を制限します
        - 二重起動時はダイアログで警告し、処理をスキップします
    
    エラーハンドリング:
        - スクリプト読み込みエラー: エラーダイアログ表示 → end ブロックスキップ
        - YAML 読み込みエラー: エラーダイアログ表示 → end ブロックスキップ
        - 二重起動検出: 警告ダイアログ表示 → end ブロックスキップ
        - バージョン不一致でキャンセル: end ブロックスキップ

.LINK
    https://github.com/UMA68/PowerShell
    関連スクリプト: NoDoubleActivation.ps1 (二重起動防止)
    関連スクリプト: Write-CommonLog.ps1 (ログ記録)
    関連スクリプト: Check-EnvModule.ps1 (モジュールチェック)
    関連スクリプト: Check-YamlModule.ps1 (YAMLモジュールチェック)

#>

# ================================================
# yamlファイルに記述したモジュールをインストールする
# ================================================

param (
    [string]$envFileName = "Env.yaml", # オプションなしの場合は「Env.yaml」を使用する
    [switch]$ShowInConsole = $false     # コンソールにログを表示するかどうか
)

begin {
    # ====================================
    # 制御フローフラグの初期化
    # ====================================
    $script:CanExecuteProcess = $true  # Process ブロックを実行するかどうかのフラグ
    $script:ShowInConsoleFlag = $ShowInConsole  # ShowInConsoleパラメータをスクリプトスコープに保存
    
    # ====================================
    # ディレクトリとパスの初期化
    # ====================================
    # スクリプト実行に必要な各種ディレクトリパスを構築
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path    # スクリプト実行ディレクトリ取得
    $UpperDir = Split-Path $scriptDir -Parent               # スクリプト実行ディレクトリの親ディレクトリ取得
    $PowerShellDir = Split-Path $UpperDir -Parent           # PowerShellディレクトリ
    $yamlDir = Join-Path -Path $UpperDir -ChildPath "YAML"  # Yamlファイル格納ディレクトリ
    $LogDir = Join-Path -Path $UpperDir -ChildPath "Log"    # Logファイル格納ディレクトリ
    $envPath = Join-Path -Path $yamlDir -ChildPath $envFileName  # yamlファイルのパス
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"  # 共通スクリプト格納ディレクトリ
    
    # ====================================
    # 環境変数の取得
    # ====================================
    # 実行環境情報を取得し、ログに記録
    $UserName = $env:USERNAME       # ユーザ名取得
    $HostName = $env:COMPUTERNAME   # ホスト名取得

    # ====================================
    # 共通スクリプト（二重起動チェック）の読み込み
    # ====================================
    # 二重起動チェック関数を最優先で読み込み
    try {
        . $comPath"\NoDoubleActivation.ps1" -ErrorAction Stop    # 二重起動チェック
    } catch {
        $script:CanExecuteProcess = $false
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $scriptName = $_.InvocationInfo.MyCommand.Name
            $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x30)
        } finally {
            if ($null -ne $obj) { # COMオブジェクトが存在する場合
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
                $obj = $null
            }
        }
        return
    }
    
    # ====================================
    # 二重起動の防止（最優先チェック）
    # ====================================
    # 同じスクリプトが複数同時実行されないようチェック
    if (-not (Test-NoDoubleActivation -Thread "InstMain" -ShowDialog)) { # 二重起動検出時
        # 既に起動中のため処理を終了
        Write-Warning "既に起動中のため処理を終了します"
        $script:CanExecuteProcess = $false
        return
    }
    
    # ====================================
    # ログファイルの初期化
    # ====================================
    # ログディレクトリとログファイルパスの作成
    $Log = Join-Path -Path $LogDir -ChildPath ($HostName + "_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
    # ログディレクトリがなければ作成
    if (-not (Test-Path -Path $LogDir)) { # ログディレクトリがなければ作成
        New-Item -Path $LogDir -ItemType Directory | Out-Null
    }
    
    # ====================================
    # 共通スクリプト（その他）の読み込み
    # ====================================
    # 必要な.ps1ファイルをドットソーシングで読み込み
    try {
        . $comPath"\Write-CommonLog.ps1" -ErrorAction Stop       # ログ記録機能
        . $scriptDir"\Check-EnvModule.ps1" -ErrorAction Stop     # 環境モジュールチェック
        . $scriptDir"\Check-YamlModule.ps1" -ErrorAction Stop    # YAMLモジュールチェック
    } catch {
        $script:CanExecuteProcess = $false
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $scriptName = $_.InvocationInfo.MyCommand.Name
            $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x30)
        } finally {
            if ($null -ne $obj) { # COMオブジェクトが存在する場合
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
                $obj = $null
            }
        }
    }

}
Process {
    if (-not $script:CanExecuteProcess) { # エラーまたは二重起動の場合はスキップ
        return  # begin ブロックでエラーが発生した場合はスキップ
    }
    
    # ====================================
    # Powershell-Yamlモジュールの検証
    # ====================================
    # YAMLファイル読み込みに必須のモジュールを事前確認・インストール
    # Test-YamlModule -Ver 'x.x.x'
    Test-YamlModule

    # ====================================
    # 設定ファイルの読み込み
    # ====================================
    # YAMLファイルからモジュール情報を読み込み
    try {
        $yaml = Get-Content $envPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    } catch {
        $script:CanExecuteProcess = $false
        $obj = $null
        try {
            $obj = New-Object -ComObject WScript.Shell
            $obj.Popup($envFileName + "の読み込みに失敗しました。処理を終了します。`r`n`r`n" + $_.Exception.Message, 0, "エラー", 0x30)
        } finally {
            if ($null -ne $obj) { # COMオブジェクトが存在する場合
                # COMオブジェクトの解放
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
                $obj = $null
            }
        }
        return
    }

    # ====================================" 
    # PowerShellバージョンの検証
    # ====================================
    # 実行中のPowerShellバージョンとYAMLで指定されたバージョンを比較
    $pwsVerChk = ($PSVersionTable.PSVersion).ToString()
    $obj = $null
    if ($pwsVerChk -ne $yaml.PowerShell.Version) { # バージョン不一致の場合
        # yaml記述のバージョンと違ったら警告表示
        try {
            $obj = New-Object -ComObject WScript.Shell
            [int]$retButton = $obj.Popup("実行中のPowerShellは " + $pwsVerChk + " です。`r`nPowerShell " + $yaml.PowerShell.Version + " を前提にインストールを行います。続行しますか？", 0, "警告", 4)   # はい=6 いいえ=7
            switch ($retButton) {
                6 { break } # はい
                7 { # いいえ
                    if ($null -ne $obj) { # COMオブジェクトが存在する場合
                        # COMオブジェクトの解放
                        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
                        $obj = $null
                    }
                    $script:CanExecuteProcess = $false
                    return  # いいえ
                }
            }
        } finally {
            if ($null -ne $obj) { # COMオブジェクトが存在する場合
                # COMオブジェクトの解放
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
                $obj = $null
            }
        }
    }

    # ====================================
    # ログ記録の開始
    # ====================================
    # 実行環境情報をログファイルに記録
    Write-CommonLog -Message ("HOST: " + $HostName) -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)   # ホスト名
    Write-CommonLog -Message ("USER: " + $userName) -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)   # ユーザ名

    Write-CommonLog -Message ("Running PowerShell Version: " + $pwsVerChk) -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "============================" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message ($yaml.Project) -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message ("Version: " + $yaml.Version) -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "============================" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)

    Write-CommonLog -Message ("[[[START]]]") -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)

    # ====================================
    # モジュールのインストール処理
    # ====================================
    # YAMLファイルで定義された全モジュールを順次チェック・インストール
    foreach ($module in $yaml.Module.Keys) { # 各モジュールを処理
        Test-EnvModule -ModuleName $yaml.Module.$module.Name -ModuleVersion $yaml.Module.$module.Version  # モジュールのインストール
    }

    Write-CommonLog -Message ("[[[END]]]") -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "-----------------------------" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
}
end {
    # エラーまたは二重起動の場合は何もせず終了 
    if (-not $script:CanExecuteProcess) {
        return
    }
    
    # ====================================
    # 完了メッセージの表示
    # ====================================
    # 処理終了をポップアップで通知
    $obj = $null
    try {
        $obj = New-Object -ComObject WScript.Shell
        $obj.popup("処理を終了しました。ログを表示します", 0, "完了", 0x40)   # 0x40:情報
    } finally {
        if ($null -ne $obj) { # COMオブジェクトが存在する場合
            # COMオブジェクトの解放
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch { Write-Error $_.Exception.Message }
            $obj = $null
        }
    }

    # ====================================
    # ログの見方を追記
    # ====================================
    # ログファイル末尾に凡例を追加
    Write-CommonLog -Message " " -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "ログの見方" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "[EXIST] : yaml記述バージョンのモジュールを発見" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "[OTHER] : yaml記述バージョン以外のモジュールを発見" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "[NOTHING] : yaml記述モジュールが存在しない" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    Write-CommonLog -Message "[INSTALL] : yaml記述バージョンのモジュールが存在しないのでインストール" -LogPath $Log -Level 'INFO' -Quiet:(-not $ShowInConsole)
    
    # ====================================
    # ログファイルを開く
    # ====================================
    # 処理結果を確認するためログファイルを自動で開く
    Invoke-Item $Log
}
