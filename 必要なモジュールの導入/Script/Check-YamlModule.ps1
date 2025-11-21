<#
.SYNOPSIS
    モジュールPowershell-Yamlがインストール済みか確認し、存在しない場合はインストールします。

.DESCRIPTION
    Test-YamlModule関数はPowershell-Yaml 0.4.7が既にインストールされているかどうかを確認します。
    もし指定されたバージョンのモジュールが存在しない場合は、そのモジュールをインストールします。
    -Verオプションでバージョン指定が可能です。

.EXAMPLE
    Test-YamlModule

.EXAMPLE
    Test-YamlModule -Ver '0.4.6'

.PARAMETER Ver
   確認またはインストールするモジュールのバージョン。

.FUNCTIONALITY
    Powershell-Yamlモジュールの存在チェック
    なければインストールする(無指定だと0.4.7をインストールする)
    違うバージョンをインストールしたい場合は、以下のコメントアウトを参考にバージョン指定する
    Test-YamlModule -Ver 'x.x.x

.NOTES
    File Name      : Check-YamlModule.ps1
    Author         : UMA
    Prerequisite   : Powershell-Yaml(PowerShell Gallery)
    URL            : https://www.powershellgallery.com/packages/Powershell-Yaml 
#>

function Test-YamlModule {
    Param(
        [string]$Ver = '0.4.7'
    )
    $yamlCnt = ((Get-Module -ListAvailable -Name "Powershell-Yaml").Name).Count
    if($yamlCnt -eq 0){
        $obj = New-Object -ComObject WScript.Shell
        $obj.Popup("Powershell-Yamlがインストールされていません。インストールします。",0,"情報",0x40) | Out-Null
        try {
            Install-Module -Name "Powershell-Yaml" -RequiredVersion $Ver -Force -ErrorAction Stop   
            # Write-Log -Message "Installed Powershell-Yaml "+$Ver -LogPath $Log
            Write-CommonLog -Message "Installed Powershell-Yaml "+$Ver -LogPath $Log -Level 'INFO'
        }
        catch {
            $obj.Popup("Powershell-Yamlのインストールに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30) | Out-Null
            Exit    # おわり
        }
    } else {
        # Write-Log -Message "Powershell-Yaml is already installed." -LogPath $Log
        Write-CommonLog -Message "Powershell-Yaml is already installed." -LogPath $Log -Level 'INFO'
    }
}
