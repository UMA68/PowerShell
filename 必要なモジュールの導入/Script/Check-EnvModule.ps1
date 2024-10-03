<#
.SYNOPSIS
   モジュールがインストール済みか確認し、存在しない場合はインストールします。

.DESCRIPTION
   Check-EnvModule関数は指定されたモジュールが既にインストールされているかどうかを確認します。
   もし指定されたバージョンのモジュールが存在しない場合は、そのモジュールをインストールします。

.EXAMPLE
    Check-EnvModule -ModuleName "モジュール名" -ModuleVersion "バージョン"

.PARAMETER ModuleName
   確認またはインストールするモジュールの名前。

.PARAMETER ModuleVersion
   確認またはインストールするモジュールのバージョン。

.FUNCTIONALITY
    モジュールの存在チェック
    なければインストールする

.NOTES
    File Name      : Check-EnvModule.ps1
    Author         : UMA
    Prerequisite   : PowerShell Gallery
    URL            : https://www.powershellgallery.com/
#>
function Check-EnvModule {
    param(
        [string]$ModuleName,
        [string]$ModuleVersion
    )
  # モジュールがインストール済みか確認
    $cnt = ((Get-Module -ListAvailable -Name $ModuleName).Name).Count
    $flg = $false   # yaml記述バージョンのモジュール存在フラグ
    if(!($cnt -eq 0)){
        $getVer = (Get-Module -ListAvailable -Name $ModuleName).Version
        foreach($ver in $getVer){
            if($ver.ToString() -eq $ModuleVersion){
                $flg = $true    # 存在したらフラグを立てる
                Write-Log ("INFO: "+(Get-Date -Format "yyyyMMdd HH:mm:ss")+" [EXIST] "+$ModuleName+" Version: "+$ver.ToString())
            }else{
                Write-Log ("INFO: "+(Get-Date -Format "yyyyMMdd HH:mm:ss")+" [OTHER] "+$ModuleName+" Version: "+$ver.ToString())
            }
        }
    }else{
        Write-Log ("WARN: "+(Get-Date -Format "yyyyMMdd HH:mm:ss")+" [NOTHING] "+$ModuleName)
    }
    # yaml記述バージョンのモジュールが存在しない場合はインストール
    if($flg -eq $false){
        Write-Log ("WARN: "+(Get-Date -Format "yyyyMMdd HH:mm:ss")+" [INSTALL] "+$ModuleName+" Version: "+$ModuleVersion.ToString())
        Install-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force # | Tee-Object -FilePath $glbLog -Append | Out-Default
    }
}
