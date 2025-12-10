<#
.SYNOPSIS
    リリースバッチのカスタムファイルコピー処理を実行します

.DESCRIPTION
    指定されたリリースタイプに基づいて、リリース元フォルダからリリース先フォルダへ
    ファイルをコピーします。既存ファイルがある場合はタイムスタンプ付きでリネームします。
    
    処理フロー:
    1. リリース元フォルダのファイル確認
    2. リリース先フォルダの既存ファイルをリネーム（yyyyMMdd-HHmmss形式）
    3. 新しいファイルをリリース先へコピー
    4. ログ記録

.PARAMETER ReleaseType
    リリースタイプ名。YAML設定ファイルで定義されたタイプを指定します。
    例: 'TYPE_A', 'TYPE_B', 'TYPE_C'

.PARAMETER Yaml
    YAML設定オブジェクト。ConvertFrom-Yaml で解析されたハッシュテーブル

.PARAMETER LogPath
    ログファイルの完全パス

.PARAMETER SensitivePatterns
    ログに出力する際にマスキング対象とする機密情報キーワード配列
    デフォルト: @()

.EXAMPLE
    Copy-ItemCustom -ReleaseType "TYPE_A" -Yaml $yamlConfig -LogPath "C:\Logs\release.log"

.NOTES
    File Name      : CopyItemCustom.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2025-12-10
    Last Modified  : 2025-12-10
    
    依存関数:
    - Write-CommonLog : ログ出力関数
    - Invoke-ReleaseRules : リリースルール適用
    
    変更履歴:
    v1.2.0 (2025-12-10)
        - 機密情報マスキング機能追加
        - SensitivePatterns パラメータ対応
        
    v1.1.0 (2025-11-20)
        - 初版リリース
#>

function Copy-ItemCustom {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReleaseType,
        [Parameter(Mandatory=$true)]
        [object]$Yaml,
        [Parameter(Mandatory=$true)]
        [string]$LogPath,
        [Parameter(Mandatory=$false)]
        [string[]]$SensitivePatterns = @()
    )
    
    begin{
        # リリース元フォルダ
        $ReleaseSource = $Yaml.RELEASE.$ReleaseType.FolderBy
    }
    process{
        # フォルダ内ファイルのカウント
        try{
            $FileCount = (Get-ChildItem -Path $ReleaseSource -Recurse -File | Measure-Object).Count
        }catch{
            # フォルダ内ファイルのカウントに失敗した場合は、エラーメッセージを表示
            Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseSource' FOLDER NOT FOUND!." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            return # YAML記述が間違っている場合は、Functionを抜ける
        }
        # フォルダ内ファイルのカウントが0の場合は、Functionを抜ける
        if ($FileCount -eq 0) {
            Write-CommonLog -Message "[SKIP] RELEASE TYPE '$ReleaseSource' FOLDER EMPTY!." -LogPath $LogPath -Level 'WARN' -SensitivePatterns $SensitivePatterns
            return
        }
        # リリース開始メッセージ
        [string]$StartMessage = "[MESSAGE] RELEASE TYPE '$ReleaseType' FOLDER COPY STARTED."
        # $StartMessageと同じ長さの'-'を作成
        $StartMessageLineCount = $StartMessage.Length
        $StartMessageLine = "-" * $StartMessageLineCount

        Write-CommonLog -Message $StartMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $StartMessage -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $StartMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns

        # リリース先フォルダ
        $ReleaseDestination = $Yaml.RELEASE.$ReleaseType.ReleaseTo
        # リリース先フォルダが存在しない場合は、エラーをログに記述
        if(-not (Test-Path -Path $ReleaseDestination)) {
            Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseType' FOLDER NOT FOUND!." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            return
        }

        # リリース実行
        foreach ($File in (Get-ChildItem -Path $ReleaseSource -Recurse -File)) {
            # リリースルールに従い実行
            Invoke-ReleaseRules -ReleaseTypeName $ReleaseType -FileObject $File -ReleaseDestination $ReleaseDestination -LogPath $LogPath -SensitivePatterns $SensitivePatterns
        }
        # リリース完了メッセージ
        [string]$EndMessage = "[MESSAGE] RELEASE TYPE '$ReleaseType' FOLDER COPY COMPLETED."
        # $EndMessageと同じ長さの'-'を作成
        $EndMessageCount = $EndMessage.Length
        $EndMessageLine = "-" * $EndMessageCount
        Write-CommonLog -Message $EndMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $EndMessage -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $EndMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
    }
}
# リリースルールのスクリプト化
<#
.SYNOPSIS
    リリースルールを適用してファイルをコピーします

.DESCRIPTION
    指定されたファイルに対してリリースルールを適用し、リリース先へコピーします。
    既存ファイルが存在する場合はタイムスタンプ付きでリネーム・削除します。

.PARAMETER ReleaseTypeName
    リリースタイプ名（ログ出力用）

.PARAMETER FileObject
    コピー対象のファイルシステム情報オブジェクト

.PARAMETER ReleaseDestination
    リリース先フォルダパス

.PARAMETER LogPath
    ログファイルの完全パス

.PARAMETER SensitivePatterns
    ログに出力する際にマスキング対象とする機密情報キーワード配列

.NOTES
    内部用関数 - Copy-ItemCustom から呼び出されます
    File Name: relMain.ps1 の Copy-ItemCustom 内部関数
    Version: 1.2.0
#>
function Invoke-ReleaseRules{
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReleaseTypeName,
        [Parameter(Mandatory=$true)]
        [System.IO.FileSystemInfo]$FileObject,
        [Parameter(Mandatory=$true)]
        [string]$ReleaseDestination,
        [Parameter(Mandatory=$true)]
        [string]$LogPath,
        [Parameter(Mandatory=$false)]
        [string[]]$SensitivePatterns = @()
    )
    # リリース先の既存リネームファイルを削除する
    $FileBaseName = $FileObject.BaseName      # ファイル名
    $FileExtension = $FileObject.Extension    # 拡張子
    $FileNameWithDatePattern = $FileBaseName + "_????????-??????"+$FileExtension    # リネームファイルの検索パターン
    # リネームファイルの検索
    $FileNameWithDate = Get-ChildItem -Path $ReleaseDestination -Filter $FileNameWithDatePattern -ErrorAction SilentlyContinue
    # 検索したリネームファイルを削除
    foreach($RenamedFileName in $FileNameWithDate){
        # リネームファイルの削除処理
        try{
            Remove-Item -Path $RenamedFileName.FullName -Force -ErrorAction Stop
            # 削除結果をログに記述
            Write-CommonLog -Message "[DELETE] RELEASE TYPE '$ReleaseTypeName' FILE DELETE STARTED." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[DELETE] RELEASE TYPE '$ReleaseTypeName' FILE DELETE TO '$($RenamedFileName.FullName)'." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[DELETE] RELEASE TYPE '$ReleaseTypeName' FILE DELETE COMPLETED." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        }catch{
            # 削除に失敗した場合は、エラーメッセージをログに記述
            Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseTypeName' FILE DELETE FAILED!." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
        }
    }

    # ファイルのコピー
    try{
        # もし、同一のファイルがあれば、yyyyMMdd-HHmmss形式でリネームを実施
        $ReleaseToFileName = Join-Path -Path $ReleaseDestination -ChildPath $FileObject.Name  
        $NewFileNameWithDate = $FileBaseName + "_" + (Get-Date -Format "yyyyMMdd-HHmmss")+$FileExtension
        $FileNameWithDatePath = Join-Path -Path $ReleaseDestination -ChildPath $NewFileNameWithDate
        $FileExist = Get-ChildItem -Path $ReleaseDestination -Filter $FileObject.Name -ErrorAction SilentlyContinue
        if ($FileExist) {
            # リネーム処理
            Rename-Item -Path $ReleaseToFileName -NewName $NewFileNameWithDate -Force -ErrorAction Stop
            # リネーム結果をログに記述
            Write-CommonLog -Message "[RENAME] RELEASE TYPE '$ReleaseTypeName' FILE RENAME STARTED." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[RENAME] RELEASE TYPE '$ReleaseTypeName' FILE RENAME TO '$FileNameWithDatePath'." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[RENAME] RELEASE TYPE '$ReleaseTypeName' FILE RENAME COMPLETED." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        }
        # コピー処理
        Copy-Item -Path $FileObject.FullName -Destination $ReleaseDestination -Force -ErrorAction Stop
        # コピー結果をログに記述
        Write-CommonLog -Message "[COPY] RELEASE TYPE '$ReleaseTypeName' FILE COPY STARTED." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message "[COPY] RELEASE TYPE '$ReleaseTypeName' FILE COPY TO $($FileObject.Name)." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message "[COPY] RELEASE TYPE '$ReleaseTypeName' FILE COPY COMPLETED." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
    }catch{
        # コピーに失敗した場合は、エラーメッセージをログに記述
        Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseTypeName' FILE COPY TO $($FileObject.Name) FAILED!." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
    }
}