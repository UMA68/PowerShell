# 新旧DLLファイルを逆コンパイルし、差分を比較するPowerShellスクリプト
param (
    [string]$EnvYaml = "Decompile.yaml" # オプションなしの場合は「Decompile.yaml」を使用する
)
begin{
    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path       # スクリプトの実行パスを取得
    $UpperPath = $scriptPath | Split-Path -Parent                       # スクリプトの親パスを取得
    $PowerShellDir = $UpperPath | Split-Path -Parent                    # スクリプトの親パスの親パスを取得
    $YamlPath = Join-Path -Path $UpperPath"\YAML" -ChildPath $EnvYaml   # YAMLファイルのフルパスを取得
    $LogDir = Join-Path -Path $UpperPath -ChildPath "Log"               # ログファイルの格納ディレクトリを取得

    $oldDllFolder = Join-Path -Path $UpperPath -ChildPath "\Dlls\Old"   # 古いDLLファイルの格納ディレクトリを取得
    $newDllFolder = Join-Path -Path $UpperPath -ChildPath "\Dlls\New"   # 新しいDLLファイルの格納ディレクトリを取得
    $outputFolder = Join-Path -Path $UpperPath -ChildPath "\Dlls\Decompiled"    #  逆コンパイルされたDLLファイルの格納ディレクトリを取得

    # YAMLファイルの存在チェック
    if (-not (Test-Path -Path $YamlPath)) {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("YAMLファイルが存在しません。`r`n`r`n"+$YamlPath+"を確認してください。",0,"エラー",0x30)
        exit
    }
    # YAMLファイルの読み込み
    try {
        $yaml = Get-Content -Path $YamlPath -Delimiter "`0" -ErrorAction Stop | ConvertFrom-Yaml -Ordered
    } catch {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("YAMLファイルの読み込みに失敗しました。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        exit
    }

    # OSのバージョンでWinMergeのインストールパスを予想
    [String]$WinVer = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
    if ($WinVer -like "*Windows 10*") {
        $winMergePath = $yaml.InstWinMerge.Win10
    } elseif ($WinVer -like "*Windows 11*") {
        # Windows 11の場合は$HOMEを展開するためひと手間かける
        $winMergePath = $yaml.InstWinMerge.Win11 -replace '\$HOME', $HOME
    } else {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("このスクリプトはWindows 10またはWindows 11でのみ動作します。`r`n異なるバージョンで使用する場合はスクリプトとyamlを調整してください。",0,"エラー",0x30)
        exit
    }

    # ILSpyCmd(逆コンパイルコマンド)の存在チェック
    if (-not (Get-Command "ILSpyCmd" -ErrorAction SilentlyContinue)) {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("「ILSpyCmd.exe」が存在しません。インストールしてください。`r`n"+"「ILSpyCmdインストール」を実行してインストールするのも手です。",0,"エラー",0x30)
        exit
    }
    # 2025/07/04 DEL 徳永 BEGIN
    # Linuxのdiffコマンドを使わなくなったので削除
    # # WsLのLinuxパスに変換する関数
    # function Convert-ToWSLPath($winPath) {
    #     $drive = $winPath.Substring(0,1).ToLower()
    #     $rest = $winPath.Substring(2) -replace '\\', '/'
    #     return "/mnt/$drive/$rest"
    # }
    # 2025/07/04 DEL 徳永 END
}
process{
    # 一括逆コンパイル
    $oldDlls = Get-ChildItem $oldDllFolder -Filter *.dll    # 古いDLLファイルの取得
    foreach ($oldDll in $oldDlls) {
        $baseName = $oldDll.BaseName
        $newDll = Get-ChildItem $newDllFolder -Filter "$baseName*.dll" | Sort-Object LastWriteTime | Select-Object -Last 1

        # 逆コンパイル
        if ($newDll) {
            # 古いdllの逆コンパイル
            if (Test-Path $oldDll.FullName) {
                # & ILSpyCmd -o "$outputFolder\$baseName\old" "$($oldDll.FullName)"
                # & ILSpyCmd --nested-directories -p -o "$outputFolder\$baseName\old\$baseName" "$($oldDll.FullName)"
                & ILSpyCmd --nested-directories -p -o "$outputFolder\old\$baseName" "$($oldDll.FullName)"
                Write-Host "$($oldDll.Name)(Old)の逆コンパイルに成功しました"
            } else {
                Write-Error "File '$($oldDll.FullName)' does not exist!"
            }
            # 新しいdllの逆コンパイル
            if (Test-Path $newDll.FullName) {
                # & ILSpyCmd -o "$outputFolder\$baseName\new" "$($newDll.FullName)"
                # & ILSpyCmd --nested-directories -p -o  "$outputFolder\$baseName\new\$baseName" "$($newDll.FullName)"
                & ILSpyCmd --nested-directories -p -o  "$outputFolder\new\$baseName" "$($newDll.FullName)"
                Write-Host "$($newDll.Name))(New)の逆コンパイルに成功しました"
            } else {
                Write-Error "File '$($newDll.FullName)' does not exist!"
            }
        }
        else {
            # DLLが見つからない場合のエラーメッセージ
            Write-Error "No matching DLL found for '$($oldDll.Name)'"
        }
    }
}
end{
    # WinMergeの実行準備
    $oldFile = "$outputFolder\old"  # 逆コンパイルされた古いDLLファイルの格納ディレクトリ
    $newFile = "$outputFolder\new"  # 逆コンパイルされた新しいDLLファイルの格納ディレクトリ
    # $diffReport = "$reportFolder\$baseName-diff.txt"
    
    # WinMergeの実行パスの確認
    $ExecWinMerge = Join-Path -Path $winMergePath -ChildPath "WinMergeU.exe"
    if (-not (Test-Path -Path $ExecWinMerge)) {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("WinMergeがインストールされていません。`r`n`r`n"+$ExecWinMerge+"を確認してください。",0,"エラー",0x30)
        exit
    }
 
    # WinMergeの実行
    try{
        & $ExecWinMerge /r /u /dl Old /dr New "$oldFile" "$newFile"
    }catch{
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("WinMergeの実行に失敗しました。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        exit
    }
 
    # 処理の完了メッセージ
    Read-Host -Prompt "処理が完了しました。Enterキーを押して終了します"
}

