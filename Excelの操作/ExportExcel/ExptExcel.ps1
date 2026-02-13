# =============================
# SqlServerから取得したデータを
# Excelに出力する
# =============================

<#
.SYNOPSIS
指定されたモジュールが利用可能かチェックします。

.PARAMETER ModuleName
確認するモジュールの名前

.OUTPUTS
Boolean
#>
function Test-ModuleAvailable {
    param([string]$ModuleName)
    $null -ne (Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue)
}

# ========================================
# メイン処理開始
# ========================================

# モジュール確認（簡潔版）
if (-not (Test-ModuleAvailable -ModuleName "SqlServer")) {
    Write-Warning "SqlServerモジュールがインストールされていません。処理を終了します。"
    exit 1
}
if (-not (Test-ModuleAvailable -ModuleName "ImportExcel")) {
    Write-Warning "ImportExcelモジュールがインストールされていません。処理を終了します。"
    exit 1
}

# モジュールのインポート
Import-Module SqlServer
Import-Module ImportExcel

# スクリプトのディレクトリ取得
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UpperDir = $scriptDir | Split-Path -Parent
$CommonDir = Join-Path (Split-Path -Parent $UpperDir) "Common"

# パラメータの定義
[string]$serverName = "127.0.0.1,11433"   # サーバー名またはIPアドレス、ポート番号
[string]$databaseName = "appdb"          # データベース名
[string]$userId = "sa"
[string]$TableName = "Customers"          # テーブル名

# 暗号化キーのパス（キャッシュ）
[string]$EncryptionKeyPath = Join-Path $CommonDir "Encryption.Key"
[string]$PasswordFilePath = Join-Path $UpperDir "mssql2022-dev-db.pass"

# 暗号化キーの読み込み
try {
    [byte[]]$EncryptedKey = [System.IO.File]::ReadAllBytes($EncryptionKeyPath)
}
catch {
    Write-Warning "鍵の読み込みに失敗しました。"
    Write-Error $_.Exception.Message
    Write-Warning "鍵ファイル($EncryptionKeyPath)が正しいことを確認してください。"
    exit 1
}

# パスワード復号化
try {
    $password = Get-Content -Path $PasswordFilePath | ConvertTo-SecureString -Key $EncryptedKey -ErrorAction Stop
}
catch {
    Write-Warning "パスワードの復号化に失敗しました。"
    Write-Error $_.Exception.Message
    Write-Warning "パスワードファイル,鍵ファイル(Encryption.Key)が正しいことを確認してください。"
    exit 1
}
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

# 出力先の定義
[string]$outputPath = Join-Path $UpperDir "Excel" | Join-Path -ChildPath "ExptExcel.xlsx"

# SQL文の定義（全カラム取得、不要なカラムは後で除外）
[string]$sql = "SELECT * FROM [$databaseName].dbo.[$TableName] ;"

# 出力ファイルの存在確認と削除
if (Test-Path $outputPath) {
    # 出力先のファイルが存在します。削除してもよろしいですか？
    $outputFileName = Split-Path -Leaf $outputPath
         
        # ダイアログ表示を行う
        $obj = New-Object -ComObject WScript.Shell
        try {
            $ret = $obj.Popup($outputFileName + "が存在します。削除してもよろしいですか？", 0, "確認", 0x4) # YesとNoのボタンを表示
        } finally {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($obj) | Out-Null
        }
        if ($ret -eq 6) { # Yesが押された場合
            try {
                Remove-Item $outputPath -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "ファイルの削除に失敗しました。ファイルが開かれている可能性があります。"
                Write-Error $_.Exception.Message
                
                $obj = New-Object -ComObject WScript.Shell
                try {
                    $obj.Popup("ファイルが他のプロセスで使用中です。Excelを閉じてから再実行してください。", 0, "エラー", 0x10)
                } finally {
                    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($obj) | Out-Null
                }
                exit 1
            }
        } else { # Noが押された場合
            # 処理を終了します
            $obj = New-Object -ComObject WScript.Shell
            try {
                $obj.Popup("処理を終了します。" + $outputFileName + "を退避してください", 0, "警告", 0x30)   # OKボタンを表示
            } finally {
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($obj) | Out-Null
            }
            Exit   # 終了
    }
}

# SQLの実行（エラーハンドリング付き）
try {
    $data = Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $serverName -Database $databaseName -User $userId -Password $password -Query $sql -ErrorAction Stop 
} catch {
    Write-Warning "SQLの実行に失敗しました。"
    Write-Error $_.Exception.Message

    # ダイアログ表示を行う
    $obj = New-Object -ComObject WScript.Shell
    try {
        $obj.Popup("SQLの実行に失敗しました。処理を終了します", 0, "エラー", 0x10)
    } finally {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($obj) | Out-Null
    }

    # モジュールのアンインポート
    Remove-Module SqlServer -ErrorAction SilentlyContinue
    Remove-Module ImportExcel -ErrorAction SilentlyContinue
    # 変数の削除（パスワードを含む、エラー抑制付き）
    Remove-Variable serverName, databaseName, userId, password, outputPath, scriptDir, UpperDir, EncryptionKeyPath, PasswordFilePath, TableName, sql, data -ErrorAction SilentlyContinue
    exit 1
}
    
# データ取得結果の検証（空データチェック）
if ($null -eq $data -or $data.Count -eq 0) {
    Write-Warning "データが取得できませんでした。"
    Write-Warning "テーブルデータが存在するか確認してください。"

    # ダイアログ表示を行う
    $obj = New-Object -ComObject WScript.Shell
    try {
        $obj.Popup("データが取得できません。処理を終了します", 0, "警告", 0x30)
    } finally {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($obj) | Out-Null
    }

    # モジュールのアンインポート
    Remove-Module SqlServer -ErrorAction SilentlyContinue
    Remove-Module ImportExcel -ErrorAction SilentlyContinue
    # 変数の削除（パスワードを含む、エラー抑制付き）
    Remove-Variable serverName, databaseName, userId, password, outputPath, scriptDir, UpperDir, EncryptionKeyPath, PasswordFilePath, TableName, sql, data -ErrorAction SilentlyContinue
    exit 1
}

# Excelファイルの作成
try {
    $data = $data | Select-Object -ExcludeProperty CreatedAt, RowError, RowState, Table, ItemArray, HasErrors   # 不要な列を除外
    # データをExcelファイルにエクスポート
    $data | Export-Excel -Path $outputPath -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow -TableName $TableName -NumberFormat '@'
    # Excelファイルの表示
    Invoke-Item $outputPath
    Write-Information "Excelファイルを出力しました。"
}
catch {
    Write-Warning "Excelファイルの作成に失敗しました。"
    Write-Error $_.Exception.Message
    
    # ダイアログ表示を行う
    $obj = New-Object -ComObject WScript.Shell
    try {
        $obj.Popup("Excelファイルの作成に失敗しました。処理を終了します", 0, "エラー", 0x10)
    } finally {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($obj) | Out-Null
    }
    
    # モジュールのアンインポート
    Remove-Module SqlServer -ErrorAction SilentlyContinue
    Remove-Module ImportExcel -ErrorAction SilentlyContinue
    # 変数の削除
    Remove-Variable serverName, databaseName, userId, password, outputPath, scriptDir, UpperDir, EncryptionKeyPath, PasswordFilePath, TableName, sql, data -ErrorAction SilentlyContinue
    exit 1
}

# ========================================
# 終了処理
# ========================================
# モジュールのアンインポート
Remove-Module SqlServer -ErrorAction SilentlyContinue
Remove-Module ImportExcel -ErrorAction SilentlyContinue
# 変数の削除（パスワードを含む、エラー制御付き）
Remove-Variable serverName, databaseName, userId, password, outputPath, scriptDir, UpperDir, EncryptionKeyPath, PasswordFilePath, TableName, sql, data, obj -ErrorAction SilentlyContinue
# 終了
Write-Information "処理が完了しました。"


