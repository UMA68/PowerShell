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