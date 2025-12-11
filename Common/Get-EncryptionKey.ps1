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
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyPath    # 鍵ファイルへのパス
    )
    
    begin {
        # パス検証
        if ($KeyPath -match '[\*\?]') { # ワイルドカード文字の検出
            Write-Warning "パスにワイルドカード文字が含まれています: $KeyPath"
        }
    }
    
    process {
        try {
            # 絶対パスに変換
            $script:ResolvedPath = Resolve-Path -Path $KeyPath -ErrorAction Stop
            
            # ファイルが存在するか確認
            if (-not (Test-Path -Path $script:ResolvedPath -PathType Leaf)) { # ファイルが存在しない場合
                throw "ファイルが見つかりません: $script:ResolvedPath"
            }
            
            # ファイルが読み取り可能か確認
            try {
                $script:KeyBytes = [System.IO.File]::ReadAllBytes($script:ResolvedPath)
            }
            catch [System.UnauthorizedAccessException] {
                throw "ファイル『$script:ResolvedPath』への読み取りアクセス権がありません。"
            }
            catch {
                throw "鍵ファイルの読み込みに失敗しました: $($_.Exception.Message)"
            }
            
            # 鍵サイズを検証（128/192/256 ビット = 16/24/32 バイト）
            $validSizes = @(16, 24, 32)
            if ($script:KeyBytes.Length -notin $validSizes) { # 鍵サイズが無効な場合
                throw "鍵ファイルのサイズが無効です。サイズ: $($script:KeyBytes.Length) バイト。有効なサイズ: 16, 24, 32 バイト"
            }
            
            Write-Verbose "鍵ファイルを読み込みました。パス: $script:ResolvedPath、鍵サイズ: $($script:KeyBytes.Length) バイト"
            
            return $script:KeyBytes
        }
        catch {
            $errorMessage = "鍵ファイルの取得に失敗しました。`n詳細: $($_.Exception.Message)"
            Write-Error $errorMessage -ErrorAction Stop
        }
    }
}