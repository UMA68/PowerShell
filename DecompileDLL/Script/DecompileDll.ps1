<#
.SYNOPSIS
    新旧DLLファイルを逆コンパイルし、WinMergeで差分を比較します。

.DESCRIPTION
    指定されたフォルダ内の新旧DLLファイルをILSpyCmdで逆コンパイルし、
    WinMergeを使用して差分を視覚的に比較するスクリプトです。
    
    主な機能:
    - 複数DLLの一括逆コンパイル
    - 進捗状況の表示
    - OS自動判定によるWinMergeパス解決
    - YAML設定による柔軟な設定管理

.PARAMETER EnvYaml
    使用するYAML設定ファイル名。デフォルトは"Decompile.yaml"。
    YAMLフォルダー内に配置する必要があります。

.PARAMETER CleanOutput
    実行前に出力フォルダーの内容をクリアします。前回の逆コンパイル結果を削除したい場合に使用します。

.PARAMETER ShowConfig
    YAML設定ファイルの内容を表示して終了します。設定確認用です。

.PARAMETER DiffTool
    使用する差分比較ツールを指定します。選択能: WinMerge(デフォルト), VSCode, Custom。

.PARAMETER WhatIf
    実際には処理を実行せず、実行される内容を表示します。

.EXAMPLE
    .\DecompileDll.ps1
    デフォルト設定で実行します。

.EXAMPLE
    .\DecompileDll.ps1 -EnvYaml "CustomConfig.yaml"
    カスタム設定ファイルを使用して実行します。

.EXAMPLE
    .\DecompileDll.ps1 -Verbose
    詳細ログを表示しながら実行します。

.EXAMPLE
    .\DecompileDll.ps1 -CleanOutput
    出力フォルダーをクリアしてから逆コンパイルを実行します。

.EXAMPLE
    .\DecompileDll.ps1 -WhatIf
    実際には実行せず、処理内容を確認します。

.EXAMPLE
    .\DecompileDll.ps1 -ShowConfig
    YAML設定内容を表示して終了します。

.EXAMPLE
    .\DecompileDll.ps1 -DiffTool VSCode
    VSCodeを使用して差分を表示します。

.NOTES
    File Name      : DecompileDll.ps1
    Author         : UMA
    Prerequisite   : PowerShell 7.x, ILSpyCmd, WinMerge, powershell-yaml module
    
    前提条件:
    - ILSpyCmdがインストールされていること
    - WinMergeがインストールされていること
    - powershell-yamlモジュールがインストールされていること
    - Dlls\OldとDlls\Newフォルダーに比較対象のDLLが配置されていること

.LINK
    https://github.com/UMA68/PowerShell
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$false)]
    [string]$EnvYaml = "Decompile.yaml",
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanOutput,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowConfig,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("WinMerge", "VSCode", "Custom")]
    [string]$DiffTool = "WinMerge"
)

begin{
    # カスタムログ初期化
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $UpperPath = Split-Path -Parent $scriptPath
    $LogDir = Join-Path -Path $UpperPath -ChildPath "Log"
    
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:logPath = Join-Path $LogDir "DecompileDll_$timestamp.log"
    
    # ログヘルパー関数
    function Write-Log {
        param(
            [string]$Message,
            [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
            [string]$Level = "INFO"
        )
        $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timeStamp] [$Level] $Message"
        Add-Content -Path $script:logPath -Value $logMessage -Encoding UTF8
    }
    
    # ログ開始
    Write-Log "────────────────────────────────────────" "INFO"
    Write-Log "DLL逆コンパイルスクリプトを開始" "INFO"
    Write-Log "YAML設定ファイル: $EnvYaml" "INFO"
    Write-Host "ログファイル: $script:logPath" -ForegroundColor Cyan
    
    # 処理時間計測開始
    $script:startTime = Get-Date
    
    # エラー表示用ヘルパー関数
    function Show-ErrorPopup {
        param([string]$Message)
        $shell = New-Object -ComObject WScript.Shell
        $shell.Popup($Message, 0, "エラー", 0x30) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    }

    # スクリプトの実行環境を取得
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $UpperPath = Split-Path -Parent $scriptPath
    $PowerShellDir = Split-Path -Parent $UpperPath
    $YamlPath = Join-Path -Path $UpperPath -ChildPath "YAML\$EnvYaml"
    $LogDir = Join-Path -Path $UpperPath -ChildPath "Log"

    $oldDllFolder = Join-Path -Path $UpperPath -ChildPath "Dlls\Old"
    $newDllFolder = Join-Path -Path $UpperPath -ChildPath "Dlls\New"
    $outputFolder = Join-Path -Path $UpperPath -ChildPath "Dlls\Decompiled"
    
    Write-Verbose "スクリプトパス: $scriptPath"
    Write-Verbose "YAML設定ファイル: $YamlPath"
    Write-Verbose "出力フォルダー: $outputFolder"
    
    # powershell-yamlモジュールの確認(終了コードは固定値)
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Show-ErrorPopup "powershell-yamlモジュールがインストールされていません。`r`n`r`n以下のコマンドを実行してインストールしてください:`r`nInstall-Module powershell-yaml -Scope CurrentUser"
        exit 4  # YAML読み込み前なので固定値
    }
    Import-Module powershell-yaml -ErrorAction Stop

    # YAMLファイルの存在チェック(終了コードは固定値)
    if (-not (Test-Path $YamlPath)) {
        Show-ErrorPopup "YAML設定ファイルが見つかりません。`r`n`r`n$YamlPath`r`nを確認してください。"
        exit 4  # YAML読み込み前なので固定値
    }
    
    # YAMLファイルの読み込み
    try {
        $config = Get-Content -Path $YamlPath -Raw -ErrorAction Stop | ConvertFrom-Yaml -Ordered
        Write-Verbose "YAML設定を読み込みました"
        Write-Log "YAML設定を読み込みました: $YamlPath" "SUCCESS"
    } catch {
        $errorMsg = "YAMLファイルの読み込みに失敗しました: $($_.Exception.Message)"
        Write-Log $errorMsg "ERROR"
        Show-ErrorPopup "YAMLファイルの読み込みに失敗しました。`r`n`r`n$($_.Exception.Message)"
        exit 1
    }
    
    # YAML設定値の取得(デフォルト値あり) - スクリプトスコープで定義
    $script:folderOld = if ($config.Folders.Old) { $config.Folders.Old } else { "old" }
    $script:folderNew = if ($config.Folders.New) { $config.Folders.New } else { "new" }
    $script:win11MinBuild = if ($config.OSDetection.Win11MinBuild) { $config.OSDetection.Win11MinBuild } else { 22000 }
    $script:win10MinBuild = if ($config.OSDetection.Win10MinBuild) { $config.OSDetection.Win10MinBuild } else { 10240 }
    $script:exitSuccess = if ($config.ExitCodes.Success -ne $null) { $config.ExitCodes.Success } else { 0 }
    $script:exitGeneralError = if ($config.ExitCodes.GeneralError) { $config.ExitCodes.GeneralError } else { 1 }
    $script:exitOSNotSupported = if ($config.ExitCodes.OSNotSupported) { $config.ExitCodes.OSNotSupported } else { 3 }
    $script:exitFileNotFound = if ($config.ExitCodes.FileNotFound) { $config.ExitCodes.FileNotFound } else { 4 }
    $script:exitDecompileFailed = if ($config.ExitCodes.DecompileFailed) { $config.ExitCodes.DecompileFailed } else { 5 }
    
    # 色設定の読み込み（nullチェックを強化）
    $script:colorInfo = "Cyan"
    $script:colorSuccess = "Green"
    $script:colorWarning = "Yellow"
    $script:colorError = "Red"
    
    if ($config.Colors) {
        if ($config.Colors.Info) { $script:colorInfo = $config.Colors.Info }
        if ($config.Colors.Success) { $script:colorSuccess = $config.Colors.Success }
        if ($config.Colors.Warning) { $script:colorWarning = $config.Colors.Warning }
        if ($config.Colors.Error) { $script:colorError = $config.Colors.Error }
    }
    
    Write-Verbose "YAML設定値を読み込みました: Folders(Old=$script:folderOld, New=$script:folderNew), Colors(Info=$script:colorInfo, Success=$script:colorSuccess)"
    
    # YAML構造の検証
    if (-not $config.InstWinMerge) {
        Show-ErrorPopup "YAMLに'InstWinMerge'セクションがありません。`r`n設定ファイルを確認してください。"
        exit $exitGeneralError
    }

    # OSバージョンの判定（BuildNumberベース - ローカライズに依存しない）
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $osBuild = [int]$osInfo.BuildNumber
    
    Write-Verbose "OS: $($osInfo.Caption) (Build: $osBuild)"
    
    if ($osBuild -ge $win11MinBuild) {
        # Windows 11 (YAML設定のビルド番号以降)
        $winMergePath = $config.InstWinMerge.Win11 -replace '\$HOME', $HOME
        Write-Verbose "Windows 11を検出しました (Build: $osBuild >= $win11MinBuild)"
    } elseif ($osBuild -ge $win10MinBuild) {
        # Windows 10 (YAML設定のビルド番号以降)
        $winMergePath = $config.InstWinMerge.Win10
        Write-Verbose "Windows 10を検出しました (Build: $osBuild >= $win10MinBuild)"
    } else {
        Show-ErrorPopup "このスクリプトはWindows 10またはWindows 11でのみ動作します。`r`n現在のビルド: $osBuild (Win10最小: $win10MinBuild)`r`n異なるバージョンで使用する場合はYAMLのOSDetection設定を調整してください。"
        exit $exitOSNotSupported
    }
    
    Write-Verbose "WinMergeパス: $winMergePath"

    # ILSpyCmd(逆コンパイルコマンド)の存在チェック
    $ilspyCmd = Get-Command "ILSpyCmd" -ErrorAction SilentlyContinue
    if (-not $ilspyCmd) {
        Show-ErrorPopup "「ILSpyCmd.exe」が存在しません。インストールしてください。`r`n`r`n「ILSpyCmdインストール」スクリプトを実行してインストールすることもできます。"
        exit $exitFileNotFound
    }
    Write-Verbose "ILSpyCmd場所: $($ilspyCmd.Source)"
    
    # 必要なフォルダーの存在確認
    if (-not (Test-Path $oldDllFolder)) {
        Show-ErrorPopup "Oldフォルダーが存在しません。`r`n`r`n$oldDllFolder`r`nを作成してDLLファイルを配置してください。"
        exit $exitFileNotFound
    }
    
    if (-not (Test-Path $newDllFolder)) {
        Show-ErrorPopup "Newフォルダーが存在しません。`r`n`r`n$newDllFolder`r`nを作成してDLLファイルを配置してください。"
        exit $exitFileNotFound
    }
    
    # 出力フォルダーの作成(存在しない場合)
    if (-not (Test-Path $outputFolder)) {
        try {
            New-Item -Path $outputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "出力フォルダーを作成しました: $outputFolder"
        } catch {
            Show-ErrorPopup "出力フォルダーの作成に失敗しました。`r`n`r`n$($_.Exception.Message)"
            exit $exitGeneralError
        }
    }
    
    # CleanOutput オプション: 出力フォルダーのクリーンアップ
    if ($CleanOutput) {
        $oldOutputPath = Join-Path $outputFolder $folderOld
        $newOutputPath = Join-Path $outputFolder $folderNew
        
        if ($PSCmdlet.ShouldProcess($oldOutputPath, "出力フォルダー($folderOld)の削除")) {
            if (Test-Path $oldOutputPath) {
                try {
                    Remove-Item -Path $oldOutputPath -Recurse -Force -ErrorAction Stop
                    Write-Host "出力フォルダー($folderOld)をクリアしました: $oldOutputPath" -ForegroundColor $colorSuccess
                } catch {
                    Write-Warning "出力フォルダー($folderOld)のクリアに失敗しました: $($_.Exception.Message)"
                }
            }
        }
        
        if ($PSCmdlet.ShouldProcess($newOutputPath, "出力フォルダー($folderNew)の削除")) {
            if (Test-Path $newOutputPath) {
                try {
                    Remove-Item -Path $newOutputPath -Recurse -Force -ErrorAction Stop
                    Write-Host "出力フォルダー($folderNew)をクリアしました: $newOutputPath" -ForegroundColor $colorSuccess
                } catch {
                    Write-Warning "出力フォルダー($folderNew)のクリアに失敗しました: $($_.Exception.Message)"
                }
            }
        }
    }
}
process{
    # 一括逆コンパイル
    Write-Verbose "古いDLLフォルダーをスキャン: $oldDllFolder"
    $oldDlls = Get-ChildItem $oldDllFolder -Filter *.dll -ErrorAction SilentlyContinue
    
    if (-not $oldDlls) {
        Show-ErrorPopup "古いDLLファイルが見つかりません。`r`n`r`n$oldDllFolder`r`nにDLLファイルを配置してください。"
        exit $script:exitFileNotFound
    }
    
    $totalCount = $oldDlls.Count
    $currentCount = 0
    $successCount = 0
    $failCount = 0
    $skipCount = 0
    $script:errorList = @()  # エラー詳細のリスト
    
    Write-Host "逆コンパイル対象: $totalCount 個のDLLファイル" -ForegroundColor $script:colorInfo
    Write-Log "逆コンパイル開始: $totalCount 個のDLLファイル" "INFO"

    foreach ($oldDll in $oldDlls) {
        $baseName = $oldDll.BaseName
        $newDll = Get-ChildItem $newDllFolder -Filter "$baseName.dll" -ErrorAction SilentlyContinue
        
        # 厳密マッチでない場合はワイルドカード検索
        if (-not $newDll) {
            $newDll = Get-ChildItem $newDllFolder -Filter "$baseName*.dll" -ErrorAction SilentlyContinue | 
                      Sort-Object LastWriteTime | Select-Object -Last 1
            if ($newDll) {
                Write-Warning "完全一致なし。'$($newDll.Name)'を使用します（最新）"
            }
        }

        $currentCount++
        $progress = [Math]::Round(($currentCount / $totalCount) * 100, 2)
        Write-Progress -Activity "逆コンパイル中" -Status "$baseName ($currentCount/$totalCount)" -PercentComplete $progress
        Write-Verbose "処理中: $baseName"

        # 逆コンパイル
        if ($newDll -and $PSCmdlet.ShouldProcess("$($oldDll.Name) と $($newDll.Name)", "逆コンパイル")) {
            # 古いDLLの逆コンパイル
            $oldOutput = Join-Path $outputFolder "$folderOld\$baseName"
            $oldDecompileSuccess = $false
            try {
                $ilspyArgsOld = @(
                    "--nested-directories"
                    "-p"
                    "-o", $oldOutput
                    $oldDll.FullName
                )
                
                $oldProcess = Start-Process -FilePath "ILSpyCmd" `
                    -ArgumentList $ilspyArgsOld `
                    -NoNewWindow -Wait -PassThru -ErrorAction Stop
                
                if ($oldProcess.ExitCode -eq 0) {
                    Write-Verbose "✓ $($oldDll.Name) (Old) 逆コンパイル成功"
                    $oldDecompileSuccess = $true
                } else {
                    Write-Warning "ILSpyCmd終了コード: $($oldProcess.ExitCode) - $($oldDll.Name) (Old)"
                    $failCount++
                    $errorMsg = "ILSpyCmd終了コード: $($oldProcess.ExitCode)"
                    Write-Log "[$($oldDll.Name)] Old逆コンパイル失敗: $errorMsg" "ERROR"
                    $script:errorList += [PSCustomObject]@{
                        DllName = $oldDll.Name
                        Type = "Old"
                        Error = $errorMsg
                    }
                }
            } catch {
                Write-Error "$($oldDll.Name) (Old)の逆コンパイルに失敗: $($_.Exception.Message)"
                $failCount++
                Write-Log "[$($oldDll.Name)] Old逆コンパイル例外: $($_.Exception.Message)" "ERROR"
                $script:errorList += [PSCustomObject]@{
                    DllName = $oldDll.Name
                    Type = "Old"
                    Error = $_.Exception.Message
                }
            }
            
            # 新しいDLLの逆コンパイル
            $newOutput = Join-Path $outputFolder "$folderNew\$baseName"
            $newDecompileSuccess = $false
            try {
                $ilspyArgsNew = @(
                    "--nested-directories"
                    "-p"
                    "-o", $newOutput
                    $newDll.FullName
                )
                
                $newProcess = Start-Process -FilePath "ILSpyCmd" `
                    -ArgumentList $ilspyArgsNew `
                    -NoNewWindow -Wait -PassThru -ErrorAction Stop
                
                if ($newProcess.ExitCode -eq 0) {
                    Write-Verbose "✓ $($newDll.Name) (New) 逆コンパイル成功"
                    $newDecompileSuccess = $true
                } else {
                    Write-Warning "ILSpyCmd終了コード: $($newProcess.ExitCode) - $($newDll.Name) (New)"
                    $failCount++
                    $errorMsg = "ILSpyCmd終了コード: $($newProcess.ExitCode)"
                    Write-Log "[$($newDll.Name)] New逆コンパイル失敗: $errorMsg" "ERROR"
                    $script:errorList += [PSCustomObject]@{
                        DllName = $newDll.Name
                        Type = "New"
                        Error = $errorMsg
                    }
                }
            } catch {
                Write-Error "$($newDll.Name) (New)の逆コンパイルに失敗: $($_.Exception.Message)"
                $failCount++
                Write-Log "[$($newDll.Name)] New逆コンパイル例外: $($_.Exception.Message)" "ERROR"
                $script:errorList += [PSCustomObject]@{
                    DllName = $newDll.Name
                    Type = "New"
                    Error = $_.Exception.Message
                }
            }
            
            # 両方成功した場合のみ成功カウント
            if ($oldDecompileSuccess -and $newDecompileSuccess) {
                $successCount++
                Write-Log "[$($oldDll.Name)] 逆コンパイル成功" "SUCCESS"
            }
        } else {
            Write-Warning "'$($oldDll.Name)'に対応する新しいDLLが見つかりません - スキップ"
            Write-Log "[$($oldDll.Name)] 対応DLLが見つからずスキップ" "WARNING"
            $skipCount++
        }
    }
}
end{
    Write-Progress -Activity "逆コンパイル中" -Completed
    
    # 処理統計の表示
    Write-Host "`n========================================" -ForegroundColor $colorInfo
    Write-Host "           処理サマリー" -ForegroundColor $colorInfo
    Write-Host "========================================" -ForegroundColor $colorInfo
    Write-Host "処理DLL数:      $totalCount"
    Write-Host "成功:           " -NoNewline
    Write-Host "$successCount" -ForegroundColor $colorSuccess
    Write-Host "失敗:           " -NoNewline
    if ($failCount -gt 0) {
        Write-Host "$failCount" -ForegroundColor $colorError
    } else {
        Write-Host "$failCount"
    }
    Write-Host "スキップ:       " -NoNewline
    if ($skipCount -gt 0) {
        Write-Host "$skipCount" -ForegroundColor $colorWarning
    } else {
        Write-Host "$skipCount"
    }
    Write-Host "========================================`n" -ForegroundColor $script:colorInfo
    
    # 処理統計をログに記録
    Write-Log "──────── 処理結果 ────────" "INFO"
    Write-Log "処理DLL数: $totalCount" "INFO"
    Write-Log "成功: $successCount" "SUCCESS"
    if ($failCount -gt 0) {
        Write-Log "失敗: $failCount" "ERROR"
    } else {
        Write-Log "失敗: $failCount" "INFO"
    }
    if ($skipCount -gt 0) {
        Write-Log "スキップ: $skipCount" "WARNING"
    } else {
        Write-Log "スキップ: $skipCount" "INFO"
    }
    
    # エラーレポートの表示(エラーがある場合)
    if ($script:errorList.Count -gt 0) {
        Write-Host "========================================" -ForegroundColor $colorError
        Write-Host "         エラー詳細" -ForegroundColor $colorError
        Write-Host "========================================" -ForegroundColor $colorError
        foreach ($error in $errorList) {
            Write-Host "DLL: " -NoNewline
            Write-Host "$($error.DllName)" -ForegroundColor $colorWarning -NoNewline
            Write-Host " [$($error.Type)]"
            Write-Host "  エラー: $($error.Error)" -ForegroundColor Gray
        }
        Write-Host "========================================`n" -ForegroundColor $colorError
        
        # エラーレポートをファイルに保存
        $errorReportPath = Join-Path $LogDir "DecompileErrors_$timestamp.txt"
        $errorList | Format-Table -AutoSize | Out-File -FilePath $errorReportPath -Encoding UTF8
        Write-Host "エラーレポートを保存しました: " -NoNewline
        Write-Host "$errorReportPath" -ForegroundColor $colorWarning
        Write-Host ""
    }
    
    # 処理時間の計算と表示
    $endTime = Get-Date
    $elapsedTime = $endTime - $script:startTime
    Write-Host "処理時間: " -NoNewline
    Write-Host "$($elapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor $script:colorInfo
    Write-Host ""
    Write-Log "処理時間: $($elapsedTime.ToString('hh\:mm\:ss'))" "INFO"
    
    # WinMergeの実行準備
    $oldFile = Join-Path $outputFolder $folderOld
    $newFile = Join-Path $outputFolder $folderNew
    
    Write-Verbose "比較元: $oldFile"
    Write-Verbose "比較先: $newFile"
    
    # 差分ツールの選択と起動
    if ($DiffTool -eq "VSCode") {
        Write-Host "`nVSCodeを起動しています..." -ForegroundColor $script:colorInfo
        Write-Log "VSCodeで差分比較を起動" "INFO"
        if ($PSCmdlet.ShouldProcess("VSCode", "差分比較起動")) {
            try {
                Start-Process -FilePath "code" -ArgumentList "--diff","`"$oldFile`"","`"$newFile`"" -ErrorAction Stop
                Write-Host "VSCodeを起動しました。" -ForegroundColor $script:colorSuccess
                Write-Log "VSCode起動成功" "SUCCESS"
            } catch {
                Write-Warning "VSCodeの起動に失敗しました: $($_.Exception.Message)"
                Write-Log "VSCode起動失敗: $($_.Exception.Message)" "ERROR"
                Write-Host "VSCodeがインストールされているか、PATHに追加されているか確認してください。" -ForegroundColor $script:colorWarning
            }
        }
    } elseif ($DiffTool -eq "Custom") {
        Write-Host "`nカスタム差分ツールモード: 手動で以下のパスを比較してください" -ForegroundColor $script:colorInfo
        Write-Log "カスタム差分ツールモード" "INFO"
        Write-Host "Old: " -NoNewline
        Write-Host "$oldFile" -ForegroundColor $colorWarning
        Write-Host "New: " -NoNewline
        Write-Host "$newFile" -ForegroundColor $colorWarning
    } else {
        # WinMerge (デフォルト)
        # WinMergeの実行パスの確認
        # WinMerge (デフォルト)
        # WinMergeの実行パスの確認
        $ExecWinMerge = Join-Path -Path $winMergePath -ChildPath "WinMergeU.exe"
        if (-not (Test-Path -Path $ExecWinMerge)) {
            Show-ErrorPopup "WinMergeが見つかりませんでした。`r`n`r`n$ExecWinMerge`r`nを確認してください。"
            exit $exitFileNotFound
        }
        
        Write-Verbose "WinMerge実行ファイル: $ExecWinMerge"
    
        # WinMergeの実行
        Write-Host "`nWinMergeを起動しています..." -ForegroundColor $script:colorInfo
        Write-Log "WinMergeで差分比較を起動" "INFO"
        if ($PSCmdlet.ShouldProcess($ExecWinMerge, "WinMerge起動")) {
            try {
                $winMergeArgs = @(
                    "/r",
                    "/u",
                    "/dl", "Old",
                    "/dr", "New",
                    "`"$oldFile`"",
                    "`"$newFile`""
                )
                
                Start-Process -FilePath $ExecWinMerge -ArgumentList $winMergeArgs -ErrorAction Stop
                Write-Host "WinMergeを起動しました。" -ForegroundColor $script:colorSuccess
                Write-Log "WinMerge起動成功" "SUCCESS"
            } catch {
                Write-Log "WinMerge起動失敗: $($_.Exception.Message)" "ERROR"
                Show-ErrorPopup "WinMergeの実行に失敗しました。`r`n`r`n$($_.Exception.Message)"
                exit $exitGeneralError
            }
        }
    }
    
    # 処理の完了メッセージ
    Write-Host "`n処理が完了しました。" -ForegroundColor $script:colorSuccess
    if (-not $WhatIfPreference) {
        if ($DiffTool -ne "Custom") {
            Write-Host "差分比較ツールで差分を確認してください。" -ForegroundColor $script:colorInfo
        }
    }
    
    # ログ完了
    if ($failCount -gt 0) {
        Write-Log "DLL逆コンパイルスクリプトを終了（一部失敗）" "WARNING"
    } else {
        Write-Log "DLL逆コンパイルスクリプトを正常終了" "SUCCESS"
    }
    Write-Log "────────────────────────────────────────" "INFO"
    
    # 失敗があった場合は適切な終了コードを返す
    if ($failCount -gt 0) {
        Write-Warning "一部のDLL処理に失敗しました。詳細はログを確認してください。"
        exit $exitDecompileFailed
    }
}

