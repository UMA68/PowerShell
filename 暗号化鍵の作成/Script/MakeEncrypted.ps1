<#
.SYNOPSIS
    暗号化・復号化用の鍵ファイルを生成します。

.DESCRIPTION
    指定されたビット長（128/192/256）で暗号化鍵を生成し、Common フォルダーに
    Encryption.Key として保存します。
    
    主な機能：
    - セキュアな乱数生成（RNGCryptoServiceProvider）
    - 既存ファイルの上書き確認
    - 二重起動防止機構（早期チェック）
    - 鍵データの検証（全ゼロチェック）
    - 処理後の機密情報自動削除
    - エラー時・二重起動時の適切なクリーンアップ処理

.PARAMETER KeySize
    生成する鍵のビット長。128、192、256から選択可能。デフォルトは192ビット。
    - 128ビット = 16バイト
    - 192ビット = 24バイト（推奨）
    - 256ビット = 32バイト

.INPUTS
    None
    パイプライン入力は受け付けません。

.OUTPUTS
    Encryption.Key ファイル（Common フォルダー）
    バイナリ形式で保存されます。

.EXAMPLE
    .\MakeEncrypted.ps1
    
    既定の192ビット鍵を生成します。
    1. 二重起動チェックが実行されます
    2. Common フォルダーの存在を確認します
    3. 既存の鍵ファイルがあれば上書き確認します
    4. セキュアな乱数で鍵を生成します
    5. 鍵の妥当性を検証します
    6. Common\Encryption.Key に保存します
    7. 機密情報をメモリから削除します
    8. キー入力待ち後、スクリプトが終了します

.EXAMPLE
    .\MakeEncrypted.ps1 -KeySize 256
    
    256ビット（32バイト）鍵を生成します。

.NOTES
    FileName:     MakeEncrypted.ps1
    Author:       UMA68
    Version:      1.2.0
    LastModified: 2025-12-11
    Prerequisites:
      - PowerShell 5.1 以上
      - Common\NoDoubleActivation.ps1 が存在すること
    
    変更履歴:
    v1.2.0 (2025-12-11)
        - begin-process-end 構造を強化
        - 制御フローフラグ（$script:CanExecuteProcess）を導入
        - スクリプトスコープ変数の適切な管理
        - exit を削除し return に変更（end ブロック確実実行）
        - 二重起動時・エラー時も end ブロックでクリーンアップ
        - COM オブジェクトのリソース解放を強化
        - エラーハンドリングを改善
    
    v1.1.0 (2025-12-10)
        - 二重起動防止機構を追加
        - セキュリティクリーンアップ処理を追加
        - 鍵データ検証機能を追加
    
    v1.0.0 (初版)
        - 基本的な鍵生成機能を実装
    
    セキュリティに関する注意:
    - 鍵はセキュアな乱数生成器（RNGCryptoServiceProvider）で生成されます
    - 生成後、鍵データは速やかにメモリから削除されます
    - 鍵ファイルは厳重に管理してください
    - 鍵ファイルのバックアップを推奨します
    
    エラーハンドリング:
    - スクリプト読み込みエラー: エラーダイアログ → クリーンアップ → 終了
    - 二重起動検出: 警告ダイアログ → クリーンアップ → 終了
    - Common フォルダー不存在: エラーダイアログ → クリーンアップ → 終了
    - 上書き確認でキャンセル: クリーンアップ → 終了
    - 鍵生成エラー: エラーダイアログ → クリーンアップ → 終了
    - ファイル書き込みエラー: エラーダイアログ → クリーンアップ → 終了
    
    クリーンアップ処理:
    - 正常終了時: 機密情報完全削除 → COM解放 → キー入力待ち → 終了
    - 二重起動時: COM解放 → キー入力待ち → 終了
    - エラー時: COM解放 → キー入力待ち → 終了

.LINK
    関連スクリプト: MakeEncryptedString.ps1（文字列暗号化）
    関連スクリプト: StringDecryption.ps1（復号）
    関連スクリプト: NoDoubleActivation.ps1（二重起動防止）
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
    # 制御フローフラグの初期化
    # ====================================
    $script:CanExecuteProcess = $true  # Process ブロックを実行するかどうかのフラグ
    
    # ====================================
    # パス初期化・共通スクリプト読込
    # ====================================
    # スクリプトのディレクトリ取得
    $script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $script:UpperDir = Split-Path -Parent $script:ScriptDir
    $script:PowerShellDir = Split-Path -Parent $script:UpperDir
    $script:comPath = Join-Path -Path $script:PowerShellDir -ChildPath "Common"
    $script:noDoubleActivationPath = Join-Path -Path $script:comPath -ChildPath "NoDoubleActivation.ps1"

    # COMオブジェクトを作成（再利用）
    $script:obj = $null
    try {
        $script:obj = New-Object -ComObject WScript.Shell
    } catch {
        Write-Host "COMオブジェクトの作成に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        $script:CanExecuteProcess = $false
        return
    }

    # .ps1ファイル読み込み
    try {
        if (-not (Test-Path $script:noDoubleActivationPath)) { # NoDoubleActivation.ps1の存在確認
            throw "NoDoubleActivation.ps1 が見つかりません: $script:noDoubleActivationPath"
        }
        . $script:noDoubleActivationPath -ErrorAction Stop
    } catch {
        $script:obj.Popup("共通スクリプトの読み込みに失敗しました。`r`n`r`n"+$_.Exception.Message, 0, "エラー", 0x10)
        $script:CanExecuteProcess = $false
        return
    }

    # ====================================
    # 二重起動の防止（最優先チェック）
    # ====================================
    # 同じスクリプトが複数同時実行されないようチェック
    if (-not (Test-NoDoubleActivation -Thread "MakeEncrypted" -ShowDialog)) { # 二重起動が検出された場合
        # 既に起動中のため処理を終了
        Write-Host "既に起動中のため処理を終了します" -ForegroundColor Yellow
        $script:CanExecuteProcess = $false
        return
    }

    # ====================================
    # 出力先確認と既存ファイルチェック
    # ====================================
    # 出力先ディレクトリの存在確認
    if (-not (Test-Path -Path $script:comPath)) { # Commonフォルダーが存在しない場合
        $script:obj.Popup("Common フォルダーが存在しません。`r`n`r`n"+$script:comPath, 0, "エラー", 0x10)
        $script:CanExecuteProcess = $false
        return
    }

    # 既存ファイルの確認
    $script:KeyFilePath = Join-Path -Path $script:comPath -ChildPath "Encryption.Key"
    if (Test-Path -Path $script:KeyFilePath) { # 既存ファイルがある場合
        $result = $script:obj.Popup("既存の鍵ファイルが見つかりました。上書きしますか？`r`n`r`n"+$script:KeyFilePath, 0, "確認", 0x34)
        if ($result -ne 6) { # 6 = はい
            Write-Host "上書きがキャンセルされました" -ForegroundColor Yellow
            $script:CanExecuteProcess = $false
            return
        }
    }
}

process {
    if (-not $script:CanExecuteProcess) { # begin ブロックでエラーが発生した場合はスキップ
        return  # begin ブロックでエラーが発生した場合はスキップ
    }
    
    # ====================================
    # 鍵生成とファイル書き込み
    # ====================================
    Write-Host "鍵生成中（${KeySize}bit）…" -ForegroundColor Cyan

    $script:rng = $null
    $script:EncryptionKey = $null
    try {
        $script:KeyBytes = $KeySize / 8  # ビットをバイトに変換
        $script:EncryptionKey = New-Object Byte[] $script:KeyBytes
        
        # 乱数を生成して鍵を埋める
        $script:rng = [Security.Cryptography.RNGCryptoServiceProvider]::Create()
        $script:rng.GetBytes($script:EncryptionKey)

        # 鍵が正しく生成されたか検証（すべてゼロでないことを確認）
        $script:allZero = $true
        foreach ($byte in $script:EncryptionKey) { # 鍵の各バイトをチェック
            if ($byte -ne 0) { # 一つでもゼロでないバイトがあれば正常
                $script:allZero = $false
                break
            }
        }
        if ($script:allZero) { # すべてのバイトがゼロの場合は異常とみなす
            throw "鍵生成に失敗しました。すべてのバイトがゼロです。"
        }

        # 鍵をファイルに書き出す（バイナリ）
        try {
            [System.IO.File]::WriteAllBytes($script:KeyFilePath, $script:EncryptionKey)
            Write-Host "鍵ファイル「Encryption.Key」を生成しました。" -ForegroundColor Green
        } catch [System.UnauthorizedAccessException] {
            throw "ファイルへの書き込み権限がありません。管理者権限で実行してください。"
        } catch [System.IO.IOException] {
            throw "ファイルの書き込みに失敗しました。ファイルが使用中の可能性があります。"
        }

        $script:obj.popup("鍵生成完了（${KeySize}bit）`r`n`r`n"+$script:KeyFilePath, 0, "鍵生成", 0x40)
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $script:obj.popup("鍵生成またはファイル書き込みに失敗しました。`r`n`r`n"+$_.Exception.Message, 0, "エラー", 0x10)
        $script:CanExecuteProcess = $false
    } finally {
        # ====================================
        # セキュリティクリーンアップ
        # ====================================
        # RNGCryptoServiceProviderのリソースを解放
        if ($null -ne $script:rng) { # リソース解放
            $script:rng.Dispose()
            $script:rng = $null
        }
        # 機密性の高い暗号化キーをメモリから明示的にクリア
        if ($null -ne $script:EncryptionKey) { # メモリからクリア
            [Array]::Clear($script:EncryptionKey, 0, $script:EncryptionKey.Length)
            $script:EncryptionKey = $null
        }
        Clear-Variable -Name EncryptionKey, KeyBytes, allZero, rng -Scope Script -ErrorAction SilentlyContinue
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-Host "✓ 機密情報をメモリから削除しました。" -ForegroundColor Green
    }
}

end {
    # ====================================
    # COMオブジェクトの解放
    # ====================================
    if ($null -ne $script:obj) { # COMオブジェクトが存在する場合
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:obj) | Out-Null
        } catch {
            Write-Host "COMオブジェクトの解放中に警告: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        $script:obj = $null
        Clear-Variable -Name obj -Scope Script -ErrorAction SilentlyContinue
    }
    
    # パス変数のクリーンアップ
    Clear-Variable -Name ScriptDir, UpperDir, PowerShellDir, comPath, noDoubleActivationPath, KeyFilePath -Scope Script -ErrorAction SilentlyContinue
    
    Write-Host "終了するには何かキーを押してください..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
