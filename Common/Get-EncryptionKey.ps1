<#
.SYNOPSIS
    暗号化処理用の鍵ファイルを読み込みます。

.DESCRIPTION
    Get-EncryptionKey 関数は、指定された鍵ファイルからバイト配列を読み込み、
    暗号化・復号化処理で使用される鍵を取得します。
    
    鍵ファイルは以下の条件を満たす必要があります：
    - ファイルが存在する
    - ファイルが読み取り可能
    - 128ビット/192ビット/256ビットの鍵データ（16/24/32 バイト）

.PARAMETER KeyPath
    鍵ファイルへのパスを指定します。相対パスまたは絶対パスが可能です。
    
    パラメーター検証:
    - 空白のみの入力は不可
    - ファイルが存在する必要があります

.EXAMPLE
    # 鍵ファイルを読み込む
    $key = Get-EncryptionKey -KeyPath "C:\Keys\Encryption.Key"
    Write-Host "鍵を取得しました。鍵サイズ: $($key.Length) バイト"

.EXAMPLE
    # 相対パスを指定
    $key = Get-EncryptionKey -KeyPath "..\Common\Encryption.Key"

.OUTPUTS
    [byte[]] 鍵ファイルのバイト配列。暗号化処理で使用されます。

.FUNCTIONALITY
    暗号化用鍵ファイルの読み込み

.NOTES
    File Name      : Get-EncryptionKey.ps1
    Author         : UMA68
    Version        : 1.1.0
    Release Date   : 2025-12-11
    Prerequisite   : PowerShell 5.1 以上
    
    変更履歴:
    v1.1.0 (2025-12-11)
        - 到達不可能なコード（Mutex イベント登録）を削除
        - パラメーター検証を強化（ValidateNotNullOrEmpty）
        - エラーハンドリングを改善（try-catch 実装）
        - 戻り値の型を明示 ([byte[]])
        - パス検証とファイル読み取り可能性チェック
        - ヘルプドキュメント全体を追加
        - スコープ変数管理に対応
    
    v1.0.0 (2025-12-10)
        - 初版リリース

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