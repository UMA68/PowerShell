<#
.SYNOPSIS
    暗号化・復号化用の鍵ファイルを生成します。

.DESCRIPTION
    指定されたビット長（128/192/256）で暗号化鍵を生成し、Common フォルダーに
    Encryption.Key として保存します。既存ファイルがある場合は上書き確認を行います。
    二重起動防止・セキュアな乱数生成・メモリクリーンアップを実施します。

.PARAMETER KeySize
    生成する鍵のビット長。128、192、256から選択可能。デフォルトは192ビット。

.INPUTS
    None

.OUTPUTS
    Encryption.Key ファイル（Common フォルダー）

.EXAMPLE
    .\MakeEncrypted.ps1
    既定の192ビット鍵を生成します。

.EXAMPLE
    .\MakeEncrypted.ps1 -KeySize 256
    256ビット鍵を生成します。

.NOTES
    FileName:     MakeEncrypted.ps1
    Author:       UMA68
    Version:      1.1.0
    LastModified: 2025-12-10
    Prerequisites:
      - PowerShell 5.1 以上
      - Common\NoDoubleActivation.ps1 が存在すること

.LINK
    関連スクリプト: MakeEncryptedString.ps1（文字列暗号化）
    関連スクリプト: StringDecryption.ps1（復号）
#>

# ====================================
# パラメーター定義
# ====================================
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(128, 192, 256)]
    [int]$KeySize = 192  # デフォルトは192bit
)

begin {
    # ====================================
    # パス初期化・共通スクリプト読込
    # ====================================
    # スクリプトのディレクトリ取得
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $UpperDir = Split-Path -Parent $ScriptDir
    $PowerShellDir = Split-Path -Parent $UpperDir
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"
    $noDoubleActivationPath = Join-Path -Path $comPath -ChildPath "NoDoubleActivation.ps1"

    # COMオブジェクトを作成（再利用）
    $obj = $null
    try {
        $obj = New-Object -ComObject WScript.Shell
    } catch {
        Write-Host "COMオブジェクトの作成に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }

    # .ps1ファイル読み込み
    try {
        if (-not (Test-Path $noDoubleActivationPath)) {
            throw "NoDoubleActivation.ps1 が見つかりません: $noDoubleActivationPath"
        }
        . $noDoubleActivationPath -ErrorAction Stop
    } catch {
        $obj.Popup("共通スクリプトの読み込みに失敗しました。`r`n`r`n"+$_.Exception.Message, 0, "エラー", 0x10)
        if ($null -ne $obj) {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
        exit
    }

    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "MakeEncrypted"

    # ====================================
    # 出力先確認と既存ファイルチェック
    # ====================================
    # 出力先ディレクトリの存在確認
    if (-not (Test-Path -Path $comPath)) {
        $obj.Popup("Common フォルダーが存在しません。`r`n`r`n"+$comPath, 0, "エラー", 0x10)
        if ($null -ne $obj) {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
        exit
    }

    # 既存ファイルの確認
    $KeyFilePath = Join-Path -Path $comPath -ChildPath "Encryption.Key"
    if (Test-Path -Path $KeyFilePath) {
        $result = $obj.Popup("既存の鍵ファイルが見つかりました。上書きしますか？`r`n`r`n"+$KeyFilePath, 0, "確認", 0x34)
        if ($result -ne 6) { # 6 = はい
            if ($null -ne $obj) {
                try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
                $obj = $null
            }
            exit
        }
    }
}

process {
    # ====================================
    # 鍵生成とファイル書き込み
    # ====================================
    Write-Host "鍵生成中（${KeySize}bit）…" -ForegroundColor Cyan

    $rng = $null
    $EncryptionKey = $null
    try {
        $KeyBytes = $KeySize / 8  # ビットをバイトに変換
        $EncryptionKey = New-Object Byte[] $KeyBytes
        
        # 乱数を生成して鍵を埋める
        $rng = [Security.Cryptography.RNGCryptoServiceProvider]::Create()
        $rng.GetBytes($EncryptionKey)

        # 鍵が正しく生成されたか検証（すべてゼロでないことを確認）
        $allZero = $true
        foreach ($byte in $EncryptionKey) {
            if ($byte -ne 0) {
                $allZero = $false
                break
            }
        }
        if ($allZero) {
            throw "鍵生成に失敗しました。すべてのバイトがゼロです。"
        }

        # 鍵をファイルに書き出す（バイナリ）
        try {
            [System.IO.File]::WriteAllBytes($KeyFilePath, $EncryptionKey)
            Write-Host "鍵ファイル「Encryption.Key」を生成しました。" -ForegroundColor Green
        } catch [System.UnauthorizedAccessException] {
            throw "ファイルへの書き込み権限がありません。管理者権限で実行してください。"
        } catch [System.IO.IOException] {
            throw "ファイルの書き込みに失敗しました。ファイルが使用中の可能性があります。"
        }

        $obj.popup("鍵生成完了（${KeySize}bit）`r`n`r`n"+$KeyFilePath, 0, "鍵生成", 0x40)
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $obj.popup("鍵生成またはファイル書き込みに失敗しました。`r`n`r`n"+$_.Exception.Message, 0, "エラー", 0x10)
        if ($null -ne $obj) {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null } catch {}
            $obj = $null
        }
        exit
    } finally {
        # ====================================
        # セキュリティクリーンアップ
        # ====================================
        # RNGCryptoServiceProviderのリソースを解放
        if ($null -ne $rng) {
            $rng.Dispose()
            $rng = $null
        }
        # 機密性の高い暗号化キーをメモリから明示的にクリア
        if ($null -ne $EncryptionKey) {
            [Array]::Clear($EncryptionKey, 0, $EncryptionKey.Length)
            $EncryptionKey = $null
        }
        Clear-Variable -Name EncryptionKey, KeyBytes, allZero, rng -ErrorAction SilentlyContinue
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-Host "機密情報をメモリから削除しました。" -ForegroundColor Cyan
    }
}

end {
    # ====================================
    # COMオブジェクトの解放
    # ====================================
    if ($null -ne $obj) {
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
        } catch {
            Write-Host "COMオブジェクトの解放中に警告: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        $obj = $null
        Clear-Variable -Name obj -ErrorAction SilentlyContinue
    }
    
    Write-Host "終了するには何かキーを押してください..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
