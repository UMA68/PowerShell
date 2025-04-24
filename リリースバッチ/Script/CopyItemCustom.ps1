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
            Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [ERROR] RELEASE TYPE '"+$ReleaseSource+"' FOLDER NOT FOUND!.").ToString()
            Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [MESSAGE] "+$_.Exception.Message).ToString()
            return # YAML記述が間違っている場合は、Functionを抜ける
        }
        # フォルダ内ファイルのカウントが0の場合は、Functionを抜ける
        if ($FileCount -eq 0) {
            Write-Log ("WARN: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [SKIP] RELEASE TYPE '"+$ReleaseSource+"' FOLDER EMPTY!.").ToString()
            return
        }
        # リリース実行
        foreach ($File in (Get-ChildItem -Path $ReleaseSource -Recurse)) {
            # リリース先フォルダ
            $ReleaseDestination = $yaml.RELEASE.$ReleaseType.ReleaseTo
            # リリース先フォルダが存在しない場合は、エラー表示
            if (!(Test-Path -Path $ReleaseDestination)) {
                Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [ERROR] RELEASE TYPE '"+$ReleaseType+"' FOLDER NOT FOUND!.").ToString()
                Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [MESSAGE] "+$_.Exception.Message).ToString()
                return
            }else{
                # リリース先の既存リネームファイルを削除する
                $FileBaseName = $File.BaseName
                $FileExtension = $File.Extension
                $FilePath = $File.DirectoryName
                $FileNameWithDatePattern = $FileBaseName + "_????????-??????"+$FileExtension
                $FileNameWithDate = Get-ChildItem -Path $ReleaseDestination -Filter $FileNameWithDatePattern -ErrorAction SilentlyContinue
                # リネームファイルの削除
                foreach($FileNameWithDate in $FileNameWithDate){
                    # リネームファイルの削除処理
                    try{
                        Remove-Item -Path $FileNameWithDate.FullName -Force -ErrorAction Stop
                        # 削除結果をログに記述
                        Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [DELETE] RELEASE TYPE '"+$ReleaseType+"' FOLDER DELETE STARTED.").ToString()
                        Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [DELETE] RELEASE TYPE '"+$ReleaseType+"' FOLDER DELETE TO '"+$FileNameWithDate.FullName+"'.").ToString()
                    }catch{
                        # 削除に失敗した場合は、エラーメッセージを表示
                        Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [ERROR] RELEASE TYPE '"+$ReleaseType+"' FOLDER DELETE FAILED!.").ToString()
                        Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [MESSAGE] "+$_.Exception.Message).ToString()
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
                            Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [RENAME] RELEASE TYPE '"+$ReleaseType+"' FOLDER RENAME STARTED.").ToString()
                            Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [RENAME] RELEASE TYPE '"+$ReleaseType+"' FOLDER RENAME TO '"+$FileNameWithDatePath+"'.").ToString()
                        }
                        # コピー処理
                        Copy-Item -Path $File.FullName -Destination $ReleaseDir -Force -ErrorAction Stop
                        # コピー結果をログに記述
                        Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [COPY] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY COMPLETED.").ToString()
                        Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [COPY] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY TO '"+$ReleaseDestination+"'.").ToString()
                    }catch{
                        # コピーに失敗した場合は、エラーメッセージを表示
                        Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [ERROR] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY FAILED!.").ToString()
                        Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [MESSAGE] "+$_.Exception.Message).ToString()
                    }
                }
            }
        }
        # リリース完了メッセージ
        Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [COPY] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY COMPLETED.").ToString()
        Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [COPY] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY TO '"+$ReleaseDestination+"'.").ToString()
    }
    end{
    }
}