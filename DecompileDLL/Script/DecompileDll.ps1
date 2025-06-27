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

    # $ilspyPath = "C:\Tools\ILSpyCmd.exe"
    $oldDllFolder = Join-Path -Path $UpperPath -ChildPath "\Dlls\Old"
    $newDllFolder = Join-Path -Path $UpperPath -ChildPath "\Dlls\New"
    $outputFolder = Join-Path -Path $UpperPath -ChildPath "\Dlls\Decompiled"
    $reportFolder = Join-Path -Path $UpperPath -ChildPath "\Dlls\Reports"

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
        $obj.Popup("このスクリプトはWindows 10またはWindows 11でのみ動作します。異なるバージョンで使用する場合はスクリプトを調整してください。",0,"エラー",0x30)
        exit
    }

    # ILSpyCmdの存在チェック
    if (-not (Get-Command "ILSpyCmd" -ErrorAction SilentlyContinue)) {
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("「ILSpyCmd.exe」が存在しません。インストールしてください。`r`n"+"「ILSpyCmdインストール」を実行してインストールするのも手です。",0,"エラー",0x30)
        exit
    }


}
process{
    # DLLファイルの一覧取得
    $oldDlls = Get-ChildItem $oldDllFolder -Filter *.dll
    foreach ($oldDll in $oldDlls) {
        $baseName = $oldDll.BaseName
        $newDll = Get-ChildItem $newDllFolder -Filter "$baseName*.dll" | Sort-Object LastWriteTime | Select-Object -Last 1

        if ($newDll) {
            # 逆コンパイル
            # & $ilspyPath -o "$outputFolder\$baseName\old" "$oldDll.FullName"
            # & $ilspyPath -o "$outputFolder\$baseName\new" "$newDll.FullName"
            & ILSpyCmd -o "$outputFolder\$baseName\old" "$oldDll.FullName"
            & ILSpyCmd -o "$outputFolder\$baseName\new" "$newDll.FullName"

            # 差分比較（例：WinMerge CLI）
            $diffReport = "$reportFolder\$baseName-diff.txt"
            # & "C:\Tools\WinMerge\WinMergeU.exe" "$outputFolder\$baseName\old" "$outputFolder\$baseName\new" /r /u /dl Old /dr New /wr "$diffReport"
            $ExecWinMerge = Join-Path -Path $winMergePath -ChildPath "WinMergeU.exe"
            if (-not (Test-Path -Path $ExecWinMerge)) {
                $obj = New-Object -ComObject WScript.Shell
                $obj.Popup("WinMergeがインストールされていません。`r`n`r`n"+$ExecWinMerge+"を確認してください。",0,"エラー",0x30)
                exit
            }
            & $ExecWinMerge "$outputFolder\$baseName\old" "$outputFolder\$baseName\new" /r /u /dl Old /dr New /wr "$diffReport"
        }
    }
}
end{

}

