function Copy-ItemCustom {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReleaseType,
        [Parameter(Mandatory=$true)]
        [object]$Yaml,
        [Parameter(Mandatory=$true)]
        [string]$LogPath
    )
    
    begin{
        # リリース元フォルダ
        $ReleaseSource = $Yaml.RELEASE.$ReleaseType.FolderBy
    }
    process{
        # フォルダ内ファイルのカウント
        try{
            $FileCount = (Get-ChildItem -Path $ReleaseSource -Recurse | Measure-Object).Count
        }catch{
            # フォルダ内ファイルのカウントに失敗した場合は、エラーメッセージを表示
            Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseSource' FOLDER NOT FOUND!." -LogPath $LogPath -Level 'ERROR'
            Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR'
            return # YAML記述が間違っている場合は、Functionを抜ける
        }
        # フォルダ内ファイルのカウントが0の場合は、Functionを抜ける
        if ($FileCount -eq 0) {
            Write-CommonLog -Message "[SKIP] RELEASE TYPE '$ReleaseSource' FOLDER EMPTY!." -LogPath $LogPath -Level 'WARN'
            return
        }
        # リリース開始メッセージ
        [string]$StartMessage = "[MESSAGE] RELEASE TYPE '$ReleaseType' FOLDER COPY STARTED."
        # $messageと同じ長さの'-'を作成
        $StartMessageLineCount = $StartMessage.Length
        $StartMessageLine = "-" * $StartMessageLineCount

        Write-CommonLog -Message $StartMessageLine -LogPath $LogPath -Level 'INFO'
        Write-CommonLog -Message $StartMessage -LogPath $LogPath -Level 'INFO'
        Write-CommonLog -Message $StartMessageLine -LogPath $LogPath -Level 'INFO'

        # リリース先フォルダ
        $ReleaseDestination = $Yaml.RELEASE.$ReleaseType.ReleaseTo
        # リリース先フォルダが存在しない場合は、エラーをログに記述
        if(-not (Test-Path -Path $ReleaseDestination)) {
            Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseType' FOLDER NOT FOUND!." -LogPath $LogPath -Level 'ERROR'
            return
        }

        # リリース実行
        foreach ($File in (Get-ChildItem -Path $ReleaseSource -Recurse)) {
            # リリースルールに従い実行
            Invoke-ReleaseRules -ReleaseTypeName $ReleaseType -FileObject $File -ReleaseDestination $ReleaseDestination -LogPath $LogPath
        }
        # リリース完了メッセージ
        [string]$EndMessage = "[MESSAGE] RELEASE TYPE '$ReleaseType' FOLDER COPY COMPLETED."
        # $Messageと同じ長さの'-'を作成
        $EndMessageCount = $EndMessage.Length
        $EndMessageLine = "-" * $EndMessageCount
        Write-CommonLog -Message $EndMessageLine -LogPath $LogPath -Level 'INFO'
        Write-CommonLog -Message $EndMessage -LogPath $LogPath -Level 'INFO'
        Write-CommonLog -Message $EndMessageLine -LogPath $LogPath -Level 'INFO'
    }
    end{
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
        [string]$LogPath
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
            Write-CommonLog -Message "[DELETE] RELEASE TYPE '$ReleaseTypeName' FOLDER DELETE STARTED." -LogPath $LogPath -Level 'INFO'
            Write-CommonLog -Message "[DELETE] RELEASE TYPE '$ReleaseTypeName' FOLDER DELETE TO '$($FileNameWithDate.FullName)'." -LogPath $LogPath -Level 'INFO'
            Write-CommonLog -Message "[DELETE] RELEASE TYPE '$ReleaseTypeName' FOLDER DELETE COMPLETED." -LogPath $LogPath -Level 'INFO'
        }catch{
            # 削除に失敗した場合は、エラーメッセージをログに記述
            Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseTypeName' FOLDER DELETE FAILED!." -LogPath $LogPath -Level 'ERROR'
            Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR'
        }
    }

    # ファイルのコピー
    try{
        # もし、同一のファイルがあれば、yyyyMMdd-HHmmss形式でリネームを実施
        $ReleaseToFileName = Join-Path -Path $ReleaseDestination -ChildPath $FileObject.Name  
        $FileNameWithDate = $FileBaseName + "_" + (Get-Date -Format "yyyyMMdd-HHmmss")+$FileExtension
        $FileNameWithDatePath = Join-Path -Path $ReleaseDestination -ChildPath $FileNameWithDate
        $FileExist = Get-ChildItem -Path $ReleaseDestination -Filter $FileObject.Name -ErrorAction SilentlyContinue
        if ($FileExist) {
            # リネーム処理
            Rename-Item -Path $ReleaseToFileName -NewName $FileNameWithDate -Force -ErrorAction Stop
            # リネーム結果をログに記述
            Write-CommonLog -Message "[RENAME] RELEASE TYPE '$ReleaseTypeName' FOLDER RENAME STARTED." -LogPath $LogPath -Level 'INFO'
            Write-CommonLog -Message "[RENAME] RELEASE TYPE '$ReleaseTypeName' FOLDER RENAME TO '$FileNameWithDatePath'." -LogPath $LogPath -Level 'INFO'
            Write-CommonLog -Message "[RENAME] RELEASE TYPE '$ReleaseTypeName' FOLDER RENAME COMPLETED." -LogPath $LogPath -Level 'INFO'
        }
        # コピー処理
        Copy-Item -Path $FileObject.FullName -Destination $ReleaseDestination -Force -ErrorAction Stop
        # コピー結果をログに記述
        Write-CommonLog -Message "[COPY] RELEASE TYPE '$ReleaseTypeName' FOLDER COPY STARTED." -LogPath $LogPath -Level 'INFO'
        Write-CommonLog -Message "[COPY] RELEASE TYPE '$ReleaseTypeName' FOLDER COPY TO $($FileObject.Name)." -LogPath $LogPath -Level 'INFO'
        Write-CommonLog -Message "[COPY] RELEASE TYPE '$ReleaseTypeName' FOLDER COPY COMPLETED." -LogPath $LogPath -Level 'INFO'
    }catch{
        # コピーに失敗した場合は、エラーメッセージをログに記述
        Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseTypeName' FOLDER COPY TO $($FileObject.Name) FAILED!." -LogPath $LogPath -Level 'ERROR'
        Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR'
    }
}