# ===================================
# 暗号化・復号化用の鍵ファイル
# Encryption.Keyを作成する
# ===================================
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(128, 192, 256)]
    [int]$KeySize = 192  # デフォルトは192bit
)

begin {
    # スクリプトのディレクトリ取得
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $UpperDir = Split-Path -Parent $ScriptDir
    $PowerShellDir = Split-Path -Parent $UpperDir
    $comPath = Join-Path -Path $PowerShellDir -ChildPath "Common"

    # COMオブジェクトを作成（再利用）
    $obj = New-Object -ComObject WScript.Shell

    # .ps1ファイル読み込み
    try {
        . (Join-Path -Path $comPath -ChildPath "NoDoubleActivation.ps1") -ErrorAction Stop
    } catch {
        $scriptName = $_.InvocationInfo.MyCommand.Name
        $obj.Popup("$scriptName の読み込みに失敗しました。処理を終了します。`r`n`r`n"+$_.Exception.Message,0,"エラー",0x30)
        exit
    }

    # 二重起動の禁止
    Test-NoDoubleActivation -Thread "MakeEncrypted"

    # 出力先ディレクトリの存在確認
    if (-not (Test-Path -Path $UpperDir)) {
        $obj.Popup("出力先ディレクトリが存在しません。`r`n`r`n"+$UpperDir, 0, "エラー", 0x10)
        exit
    }

    # 既存ファイルの確認
    $KeyFilePath = Join-Path -Path $UpperDir -ChildPath "Encryption.Key"
    if (Test-Path -Path $KeyFilePath) {
        $result = $obj.Popup("既存の鍵ファイルが見つかりました。上書きしますか？`r`n`r`n"+$KeyFilePath, 0, "確認", 0x34)
        if ($result -ne 6) { # 6 = はい
            exit
        }
    }
}

process {
    "鍵生成中（${KeySize}bit）…" | Out-Host

    # 鍵生成とファイル書き込み
    $rng = $null
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

        if ($allZero) {
            throw "鍵生成に失敗しました。すべてのバイトがゼロです。"
        }

        # 鍵をファイルに書き出す
        # $EncryptionKey | Set-Content $KeyFilePath -Encoding utf8      # テキストで書き出す場合
        try {
            [System.IO.File]::WriteAllBytes($KeyFilePath, $EncryptionKey) # バイナリで書き出す場合
        } catch [System.UnauthorizedAccessException] {
            throw "ファイルへの書き込み権限がありません。管理者権限で実行してください。"
        } catch [System.IO.IOException] {
            throw "ファイルの書き込みに失敗しました。ファイルが使用中の可能性があります。"
        }

        $obj.popup("鍵生成完了（${KeySize}bit）`r`n`r`n"+$KeyFilePath ,0, "鍵生成", 0x40) # OKボタンのみ表示(0x40)
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $obj.popup("鍵生成またはファイル書き込みに失敗しました。`r`n`r`n"+$_.Exception.Message, 0, "エラー", 0x10)
        exit
    } finally {
        # RNGCryptoServiceProviderのリソースを解放
        if ($rng) {
            $rng.Dispose()
        }
        # 機密性の高い暗号化キーをメモリから明示的にクリア
        if ($EncryptionKey) {
            [Array]::Clear($EncryptionKey, 0, $EncryptionKey.Length)
            $EncryptionKey = $null
        }
    }
}

end {
    # 処理完了（特に追加処理なし）
}
