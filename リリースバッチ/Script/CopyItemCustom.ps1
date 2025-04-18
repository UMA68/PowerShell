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
            $ReleaseDestination = $yaml.RELEASE.$ReleaseType.FolderTo
            # リリース先フォルダが存在しない場合は、エラー表示
            if (!(Test-Path -Path $ReleaseDestination)) {
                Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [ERROR] RELEASE TYPE '"+$ReleaseType+"' FOLDER NOT FOUND!.").ToString()
                Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [MESSAGE] "+$_.Exception.Message).ToString()
                return
            }else{
                # フォルダが存在すればファイルをコピー
                Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [COPY] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY STARTED.").ToString()
                Write-Log ("INFO: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [COPY] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY TO '"+$ReleaseDestination+"'.").ToString()
                # ファイルのコピー
                try{
                    Copy-Item -Path $File.FullName -Destination $ReleaseDestination -Force -ErrorAction Stop
                }catch{
                    # コピーに失敗した場合は、エラーメッセージを表示
                    Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [ERROR] RELEASE TYPE '"+$ReleaseType+"' FOLDER COPY FAILED!.").ToString()
                    Write-Log ("ERROR: "+(Get-Date -Format "yyyy-MM-dd HH:mm:ss")+" [MESSAGE] "+$_.Exception.Message).ToString()
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