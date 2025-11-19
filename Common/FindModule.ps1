function Find-Module{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )

    # モジュールがインストールされているか確認
    $module = Get-Module -ListAvailable | Where-Object { $_.Name -eq $ModuleName }
    if ($null -eq $module) {
        # $obj = New-Object PSObject WScript.Shell
        $obj = New-Object -ComObject WScript.Shell  # ✅ 正しい
        $obj.Popup("Module '$ModuleName' is not installed.", 0, "Module Check", 0x30) | Out-Null
        # Write-Host "Module '$ModuleName' is not installed."
        return $false
    } else {
        Write-Host "Module '$ModuleName' is installed."
        return $true
    }
}