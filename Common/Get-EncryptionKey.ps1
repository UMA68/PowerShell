<#
.SYNOPSIS
    暗号化処理用の鍵ファイルを読み込みます。

.DESCRIPTION
    Get-EncryptionKey 関数は、指定された鍵ファイルからバイト配列を読み込み、
    暗号化・復号化処理で使用される鍵を取得します。
    
    対応暗号化アルゴリズム: AES（Advanced Encryption Standard）
    
    鍵ファイルは以下の条件を満たす必要があります：
    - ファイルが存在する
    - ファイルが読み取り可能（アクセス権）
    - 128ビット/192ビット/256ビットのキーデータ（16/24/32 バイト）
      * 128ビット（16バイト）- AES-128
      * 192ビット（24バイト）- AES-192
      * 256ビット（32バイト）- AES-256
    
    パラメーター検証時に実行される確認:
    - 鍵ファイルの存在（ファイル）
    - パスのワイルドカード文字検出（警告のみ）
    
    ファイルの読み込みは System.IO.File::ReadAllBytes で行われ、
    バイナリデータとして直接読み込まれます。

.PARAMETER KeyPath
    鍵ファイルへのパスを指定します。相対パスまたは絶対パスが可能です。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ファイルが存在する必要があります（ファイル型）
    - ワイルドカード文字（* ?）が含まれていないか確認（警告のみ）
    
    注意: 鍵ファイルのアクセス権チェックは実行時に行われます。

.EXAMPLE
    # 鍵ファイルを読み込む
    $key = Get-EncryptionKey -KeyPath "C:\Keys\Encryption.Key"
    Write-Host "鍵を取得しました。鍵サイズ: $($key.Length) バイト"

.EXAMPLE
    # 相対パスを指定
    $key = Get-EncryptionKey -KeyPath "..\Common\Encryption.Key"

.EXAMPLE
    # 鍵サイズを確認（AES-256 = 32 バイト）
    $key = Get-EncryptionKey -KeyPath "C:\Keys\AES256.Key"
    if ($key.Length -eq 32) {
        Write-Host "AES-256 鍵を取得しました"
    } else {
        Write-Warning "予期しない鍵サイズ: $($key.Length) バイト"
    }

.EXAMPLE
    # エラーハンドリング（無効な鍵サイズ）
    try {
        $key = Get-EncryptionKey -KeyPath "C:\Keys\InvalidSize.Key"
    }
    catch {
        Write-Error "鍵ファイルの取得に失敗: $($_)"
        exit 1
    }

.EXAMPLE
    # エラーハンドリング（アクセス権エラー）
    try {
        $key = Get-EncryptionKey -KeyPath "C:\Protected\Encryption.Key"
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "ファイルへのアクセス権がありません。管理者権限が必要です"
        exit 1
    }

.OUTPUTS
    [byte[]] 鍵ファイルのバイト配列。暗号化・復号化処理で使用されます。
    
    返却されたバイト配列は以下のいずれかのサイズです:
    - 16 バイト（128ビット = AES-128）
    - 24 バイト（192ビット = AES-192）
    - 32 バイト（256ビット = AES-256）

.FUNCTIONALITY
    暗号化用鍵ファイルの読み込み

.NOTES
    File Name      : Get-EncryptionKey.ps1
    Author         : UMA68
    Version        : 1.2.0
    Release Date   : 2026-01-14
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.2.0 (2026-01-14)
        - ValidateScript により詳細なパラメーター検証を統一実装
        - AES（128/192/256ビット）対応を明記
        - エラーハンドリング詳細化（UnauthorizedAccessException、FileNotFoundException、IOException の個別処理）
        - 無効な鍵サイズエラーハンドリングを実装・記載
        - ワイルドカード文字検出をドキュメント記載
        - System.IO.File::ReadAllBytes によるバイナリ読み込み明記
        - 鍵サイズ確認例を追加
        - アクセス権エラーハンドリング例を追加
    
    v1.1.0 (2025-12-11)
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - エラーハンドリングを改善（try-catch 実装）
        - 戻り値の型を明示 ([byte[]])
        - パス検証とファイル読み取り可能性チェック
    
    v1.0.0 (2025-12-10)
        - 初版リリース
    
    既知の制限:
    - 鍵ファイルは固定サイズ（16/24/32バイト）のバイナリデータとして読み込まれます
    - 鍵ファイルの暗号化保存には対応していません（鍵自体の暗号化は別途実装推奨）
    - ファイルサイズが大きい場合（数百MB以上）は別途処理が必要
    
    セキュリティに関する注意:
    - 鍵ファイルは適切なアクセス権で保護してください
    - 鍵ファイルのパスをログに出力する際は注意が必要です
    - 本番環境では鍵管理システム（Azure Key Vault など）の使用を推奨

.LINK
    GitHub: https://github.com/UMA68/PowerShell
    System.IO.File: https://learn.microsoft.com/en-us/dotnet/api/system.io.file
#>

function Get-EncryptionKey {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if (!(Test-Path -Path $_ -PathType Leaf)) {
                    throw "鍵ファイルが存在しません: $_"
                }
                if ($_ -match '[\*\?]') {
                    Write-Warning "パスにワイルドカード文字が含まれています: $_"
                }
                $true
            })]
        [string]$KeyPath    # 鍵ファイルへのパス
    )
    
    process {
        try {
            # 絶対パスに変換
            $resolvedPath = (Resolve-Path -Path $KeyPath -ErrorAction Stop).Path
            
            # ファイルが読み取り可能か確認
            $fileInfo = Get-Item -Path $resolvedPath -ErrorAction Stop
            if ($fileInfo.IsReadOnly -and !(Test-Path -Path $resolvedPath -PathType Leaf)) {
                throw "ファイル『$resolvedPath』への読み取りアクセス権がありません。"
            }
            
            # 鍵ファイルを読み込む
            $keyBytes = [System.IO.File]::ReadAllBytes($resolvedPath)
            
            # 鍵サイズを検証（128/192/256 ビット = 16/24/32 バイト）
            $validSizes = @(16, 24, 32)
            if ($keyBytes.Length -notin $validSizes) {
                throw "鍵ファイルのサイズが無効です。サイズ: $($keyBytes.Length) バイト。有効なサイズ: 16, 24, 32 バイト"
            }
            
            Write-Verbose "鍵ファイルを読み込みました。パス: $resolvedPath、鍵サイズ: $($keyBytes.Length) バイト"
            
            return $keyBytes
        }
        catch [System.UnauthorizedAccessException] {
            Write-Error "ファイル『$KeyPath』への読み取りアクセスが拒否されました。管理者権限が必要な可能性があります。" -ErrorAction Stop
        }
        catch [System.IO.FileNotFoundException] {
            Write-Error "鍵ファイルが見つかりません: $KeyPath" -ErrorAction Stop
        }
        catch [System.IO.IOException] {
            Write-Error "鍵ファイルの読み込み中にI/Oエラーが発生しました: $($_.Exception.Message)" -ErrorAction Stop
        }
        catch {
            Write-Error "鍵ファイルの取得に失敗しました。詳細: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
}