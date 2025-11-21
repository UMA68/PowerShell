function Copy-ItemCustom {
    param (
        $ReleaseType
    )
    
    begin{
        # リリース元フォルダ
        $ReleaseSource = $yaml.RELEASE.$ReleaseType.FolderBy
    }
    process{
        # フォルダ内ファイルのカウント
        try{
            $FileCount = (Get-ChildItem -Path $ReleaseSource -Recurse | Measure-Object).Count
        }catch{
            # フォルダ内ファイルのカウントに失敗した場合は、エラーメッセージを表示
            Write-CommonLog -Message ("[ERROR] RELEASE TYPE '"+$ReleaseSource+"' FOLDER NOT FOUND!.").ToString() -LogPath $global:glbLogPath -Level 'ERROR'
            Write-CommonLog -Message ("[MESSAGE] "+$_.Exception.Message).ToString() -LogPath $global:glbLogPath -Level 'ERROR'
            return # YAML記述が間違っている場合は、Functionを抜ける
        }
        # フォルダ内ファイルのカウントが0の場合は、Functionを抜ける
        if ($FileCount -eq 0) {
            Write-CommonLog -Message ("[SKIP] RELEASE TYPE '"+$ReleaseSource+"' FOLDER EMPTY!.").ToString() -LogPath $global:glbLogPath -Level 'WARN'
            return
        }
        # リリース開始メッセージ
        [string]$StartMessage = ("[MESSAGE] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY STARTED.").ToString()
        # $messageと同じ長さの'-'を作成
        $StartMessageLineCount = $StartMessage.Length
        $StartMessageLine = "-" * $StartMessageLineCount

        Write-CommonLog -Message $StartMessageLine -LogPath $global:glbLogPath -Level 'INFO'
        Write-CommonLog -Message ($StartMessage) -LogPath $global:glbLogPath -Level 'INFO'
        Write-CommonLog -Message $StartMessageLine -LogPath $global:glbLogPath -Level 'INFO'

        # リリース実行
        foreach ($File in (Get-ChildItem -Path $ReleaseSource -Recurse)) {
            # リリース先フォルダ
            $ReleaseDestination = $yaml.RELEASE.$ReleaseType.ReleaseTo
            # リリース先フォルダが存在しない場合は、エラーをログに記述
            if(-not (Test-Path -Path $ReleaseDestination)) {
                Write-CommonLog -Message ("[ERROR] RELEASE TYPE '"+$ReleaseType+"' FOLDER NOT FOUND!.").ToString() -LogPath $global:glbLogPath -Level 'ERROR'
                Write-CommonLog -Message ("[MESSAGE] "+$_.Exception.Message).ToString() -LogPath $global:glbLogPath -Level 'ERROR'
                return
            }else{
                # リリースルールに従い実行
                Invoke-ReleaseRules -ReleaseTypeName $ReleaseType
            }
        }
        # リリース完了メッセージ
        [string]$EndMessage = ("[MESSAGE] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY COMPLETED.").ToString()
        # $Messageと同じ長さの'-'を作成
        $EndMessageCount = $EndMessage.Length
        $EndMessageLine = "-" * $EndMessageCount
        Write-CommonLog -Message ($EndMessageLine) -LogPath $global:glbLogPath -Level 'INFO'
        Write-CommonLog -Message ($EndMessage) -LogPath $global:glbLogPath -Level 'INFO'
        Write-CommonLog -Message ($EndMessageLine) -LogPath $global:glbLogPath -Level 'INFO'
    }
    end{
    }
}
# リリースルールのスクリプト化
function Invoke-ReleaseRules{
    param (
        $ReleaseTypeName
    )
    # リリース先の既存リネームファイルを削除する
    $FileBaseName = $File.BaseName      # ファイル名
    $FileExtension = $File.Extension    # 拡張子
    $FilePath = $File.DirectoryName     # ファイルパス
    $FileNameWithDatePattern = $FileBaseName + "_????????-??????"+$FileExtension    # リネームファイルの検索パターン
    # リネームファイルの検索
    $FileNameWithDate = Get-ChildItem -Path $ReleaseDestination -Filter $FileNameWithDatePattern -ErrorAction SilentlyContinue
    # 検索したリネームファイルを削除
    foreach($RenamedFileName in $FileNameWithDate){
        # リネームファイルの削除処理
        try{
            Remove-Item -Path $RenamedFileName.FullName -Force -ErrorAction Stop
            # 削除結果をログに記述
            Write-CommonLog -Message ("[DELETE] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER DELETE STARTED.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
            Write-CommonLog -Message ("[DELETE] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER DELETE TO '"+$FileNameWithDate.FullName+"'.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
            Write-CommonLog -Message ("[DELETE] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER DELETE COMPLETED.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
        }catch{
            # 削除に失敗した場合は、エラーメッセージをログに記述
            Write-CommonLog -Message ("[ERROR] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER DELETE FAILED!.").ToString() -LogPath $global:glbLogPath -Level 'ERROR'
            Write-CommonLog -Message ("[MESSAGE] "+$_.Exception.Message).ToString() -LogPath $global:glbLogPath -Level 'ERROR'
        }
    }

    # ファイルのコピー
    foreach($ReleaseDir in $ReleaseDestination){
        try{
            # もし、同一のフィルがあれば、yyyyMMdd-HHmmss形式でリネームを実施
            $ReleaseToFileName = Join-Path -Path $ReleaseDir -ChildPath $File.Name  
            $FileNameWithDate = $FileBaseName + "_" + (Get-Date -Format "yyyyMMdd-HHmmss")+$FileExtension
            $FileNameWithDatePath = Join-Path -Path $ReleaseDir -ChildPath $FileNameWithDate
            $FileExist = Get-ChildItem -Path $ReleaseDir -Filter $File.Name -ErrorAction SilentlyContinue
            if ($FileExist) {
                # リネーム処理
                Rename-Item -Path $ReleaseToFileName -NewName $FileNameWithDate -Force -ErrorAction Stop
                # リネーム結果をログに記述
                Write-CommonLog -Message ("[RENAME] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER RENAME STARTED.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
                Write-CommonLog -Message ("[RENAME] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER RENAME TO '"+$FileNameWithDatePath+"'.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
                Write-CommonLog -Message ("[RENAME] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER RENAME COMPLETED.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
            }
            # コピー処理
            Copy-Item -Path $File.FullName -Destination $ReleaseDir -Force -ErrorAction Stop
            # コピー結果をログに記述
            Write-CommonLog -Message ("[COPY] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER COPY STARTED.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
            Write-CommonLog -Message ("[COPY] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER COPY TO "+$File.Name+".").ToString() -LogPath $global:glbLogPath -Level 'INFO'
            Write-CommonLog -Message ("[COPY] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER COPY COMPLETED.").ToString() -LogPath $global:glbLogPath -Level 'INFO'
        }catch{
            # コピーに失敗した場合は、エラーメッセージをログに記述
            Write-CommonLog -Message ("[ERROR] RELEASE TYPE '"+$ReleaseTypeName+"' FOLDER COPY TO "+$File.Name+" FAILED!.").ToString() -LogPath $global:glbLogPath -Level 'ERROR'
            Write-CommonLog -Message ("[MESSAGE] "+$_.Exception.Message).ToString() -LogPath $global:glbLogPath -Level 'ERROR'
        
        }
    }
}