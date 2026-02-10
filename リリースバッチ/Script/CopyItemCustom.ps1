<#
.SYNOPSIS
    リリースバッチのカスタムファイルコピー処理を実行します

.DESCRIPTION
    指定されたリリースタイプに基づいて、リリース元フォルダからリリース先フォルダへ
    ファイルをコピーします。既存ファイルがある場合はタイムスタンプ付きでリネームします。
    
    処理フロー:
    1. リリース元フォルダのファイル確認
    2. リリース先フォルダの既存ファイルをリネーム（yyyyMMdd-HHmmss形式）
    3. 新しいファイルをリリース先へコピー
    4. ログ記録

.PARAMETER ReleaseType
    リリースタイプ名。YAML設定ファイルで定義されたタイプを指定します。
    例: 'TYPE_A', 'TYPE_B', 'TYPE_C'

.PARAMETER Yaml
    YAML設定オブジェクト。ConvertFrom-Yaml で解析されたハッシュテーブル

.PARAMETER LogPath
    ログファイルの完全パス

.PARAMETER SensitivePatterns
    ログに出力する際にマスキング対象とする機密情報キーワード配列
    デフォルト: @()

.EXAMPLE
    Copy-ItemCustom -ReleaseType "TYPE_A" -Yaml $yamlConfig -LogPath "C:\Logs\release.log"

.NOTES
    File Name      : CopyItemCustom.ps1
    Author         : UMA68
    Version        : 1.3.1
    Release Date   : 2025-12-10
    Last Modified  : 2026-01-20
    
    依存関数:
    - Write-CommonLog : ログ出力関数
    - Invoke-ReleaseRule : リリースルール適用（内部関数）
    
    内部関数:
    - Convert-ToLongPath : ファイルパスをロングパス形式に変換
    - Invoke-WithRetry : スクリプトブロックをリトライ実行
    - Invoke-ReleaseRule : リリースルール処理を実行
    
    変更履歴:
    v1.3.1 (2026-01-20)
        - 関数呼び出し名の修正（Invoke-ReleaseRules → Invoke-ReleaseRule、197行目）
        - この修正により relMain.ps1 から正常に実行可能に
    
    v1.3.0 (2026-01-20)
        - PSScriptAnalyzer 警告をすべて解決
        - コードスタイルの統一（スペース、括弧の位置）
        - 内部関数のヘルプコメント追加
        - パラメータ検証の統一（Mandatory = $true/false）
        - 関数名の定義を複数形から単数形に変更（Invoke-ReleaseRules → Invoke-ReleaseRule）
    
    v1.2.0 (2025-12-10)
        - 機密情報マスキング機能追加
        - SensitivePatterns パラメータ対応
        
    v1.1.0 (2025-11-20)
        - 初版リリース
#>

function Copy-ItemCustom {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseType,               # リリースタイプ名
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object]$Yaml,                      # YAML設定オブジェクト（OrderedDictionary推奨）
        [Parameter(Mandatory = $true)]
        [ValidateScript({ if ([string]::IsNullOrWhiteSpace($_)) { throw 'LogPath is empty' } $true })]
        [string]$LogPath,                   # ログファイルパス
        [Parameter(Mandatory = $false)]
        [string[]]$SensitivePatterns = @()  # 機密情報キーワード配列
    )
    
    begin {
        # 設定の読み取り（フェーズ2拡張）
        $OverwritePolicy = $Yaml.RELEASE.$ReleaseType.OverwritePolicy
        if ([string]::IsNullOrWhiteSpace($OverwritePolicy)) { $OverwritePolicy = 'RenameThenCopy' } # 既定
        $RetryCount = $Yaml.RELEASE.$ReleaseType.RetryCount
        if (-not $RetryCount -or $RetryCount -lt 0) { $RetryCount = 0 }
        $RetryDelayMs = $Yaml.RELEASE.$ReleaseType.RetryDelayMs
        if (-not $RetryDelayMs -or $RetryDelayMs -lt 0) { $RetryDelayMs = 250 }
        $EnableLongPath = $Yaml.RELEASE.$ReleaseType.EnableLongPath
        if (-not $EnableLongPath) { $EnableLongPath = $false }

        # ロングパス変換ヘルパー
        <#
        .SYNOPSIS
            ファイルパスをロングパス形式に変換します
        .PARAMETER path
            変換対象のファイルパス
        .OUTPUTS
            ロングパス形式に変換されたパス
        #>
        function Convert-ToLongPath ([string]$path) {
            if (-not $EnableLongPath) { return $path }  # 無効時はそのまま返す
            if ($path -like "\\?\*") { return $path }   # 既にロングパス形式の場合はそのまま返す
            if ($path -match '^[A-Za-z]:\\') { return "\\?\$path" } # ドライブレター形式
            return $path
        }

        # リトライヘルパー
        <#
        .SYNOPSIS
            スクリプトブロックを指定回数までリトライ実行します
        .PARAMETER Action
            実行するスクリプトブロック
        .OUTPUTS
            成功時は $true を返します
        #>
        function Invoke-WithRetry ([scriptblock]$Action) {
            $attempt = 0
            while ($true) { # 無限ループ（成功または例外で抜ける）
                try { & $Action; return $true }
                catch {
                    if ($attempt -ge $RetryCount) { throw }
                    Start-Sleep -Milliseconds $RetryDelayMs
                    $attempt = $attempt + 1
                }
            }
        }
        # ログディレクトリの事前作成（ログ出力失敗防止）
        try {
            $logDir = Split-Path -Parent $LogPath
            if ($logDir -and -not (Test-Path -Path $logDir)) { # ディレクトリが存在しない場合
                New-Item -ItemType Directory -Path $logDir -ErrorAction Stop | Out-Null
            }
        } catch {
            # ディレクトリ作成に失敗しても処理は継続（relMain側のACLで後続保護）
            Write-CommonLog -Message "[WARN] LOG DIRECTORY CREATE FAILED: '$logDir'." -LogPath $LogPath -Level 'WARN' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'WARN' -SensitivePatterns $SensitivePatterns
        }
        # リリース元フォルダ
        # YAMLの必須キー検証
        if (-not $Yaml.RELEASE -or -not $Yaml.RELEASE.Contains($ReleaseType)) { # リリースタイプが存在しない場合
            Write-CommonLog -Message "[ERROR] RELEASE TYPE '$ReleaseType' NOT DEFINED IN YAML." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            return
        }
        $ReleaseSource = Convert-ToLongPath -path $Yaml.RELEASE.$ReleaseType.FolderBy
        $ReleaseDestination = Convert-ToLongPath -path $Yaml.RELEASE.$ReleaseType.ReleaseTo

        # サマリ用カウンタ
        $script:SumDeleted = 0
        $script:SumRenamed = 0
        $script:SumCopied = 0
        $script:SumFailed = 0
    }
    process {
        # フォルダ内ファイルのカウント
        try {
            $FileCount = (Get-ChildItem -Path $ReleaseSource -Recurse -File -ErrorAction Stop | Measure-Object).Count
        } catch {
            # フォルダ内ファイルのカウントに失敗した場合は、エラーメッセージを表示
            Write-CommonLog -Message "[ERROR] SOURCE FOLDER NOT FOUND: '$ReleaseSource'." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            return # YAML記述が間違っている場合は、Functionを抜ける
        }
        # フォルダ内ファイルのカウントが0の場合は、Functionを抜ける
        if ($FileCount -eq 0) { # リリース対象ファイルが存在しない場合
            Write-CommonLog -Message "[SKIP] RELEASE TYPE '$ReleaseSource' FOLDER EMPTY!." -LogPath $LogPath -Level 'WARN' -SensitivePatterns $SensitivePatterns
            return
        }
        # リリース開始メッセージ
        [string]$StartMessage = "[MESSAGE] RELEASE TYPE '$ReleaseType' FOLDER COPY STARTED."
        # $StartMessageと同じ長さの'-'を作成
        $StartMessageLineCount = $StartMessage.Length
        $StartMessageLine = "-" * $StartMessageLineCount

        Write-CommonLog -Message $StartMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $StartMessage -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $StartMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns

        # リリース先フォルダの存在確認（なければ作成を試みる）
        if (-not (Test-Path -Path $ReleaseDestination)) { # リリース先フォルダが存在しない場合
            try {
                New-Item -ItemType Directory -Path $ReleaseDestination -ErrorAction Stop | Out-Null
                Write-CommonLog -Message "[INFO] DESTINATION FOLDER CREATED: '$ReleaseDestination'." -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
            } catch [System.UnauthorizedAccessException] {
                Write-CommonLog -Message "[ERROR] DESTINATION CREATE PERMISSION DENIED: '$ReleaseDestination'." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
                Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
                return
            } catch {
                Write-CommonLog -Message "[ERROR] DESTINATION FOLDER UNAVAILABLE: '$ReleaseDestination'." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
                Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
                return
            }
        }

        # リリース実行
        foreach ($File in (Get-ChildItem -Path $ReleaseSource -Recurse -File | Sort-Object FullName)) { # リリース対象ファイルが存在する場合（順序安定化）
            # リリースルールに従い実行
            Invoke-ReleaseRule -ReleaseTypeName $ReleaseType -FileObject $File -ReleaseDestination $ReleaseDestination -LogPath $LogPath -SensitivePatterns $SensitivePatterns -OverwritePolicy $OverwritePolicy -RetryCount $RetryCount -RetryDelayMs $RetryDelayMs -EnableLongPath $EnableLongPath
        }
        # リリース完了メッセージ
        [string]$EndMessage = "[MESSAGE] RELEASE TYPE '$ReleaseType' FOLDER COPY COMPLETED."
        # $EndMessageと同じ長さの'-'を作成
        $EndMessageCount = $EndMessage.Length
        $EndMessageLine = "-" * $EndMessageCount
        Write-CommonLog -Message $EndMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $EndMessage -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message $EndMessageLine -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        # サマリ出力
        Write-CommonLog -Message "[SUMMARY] TYPE='$ReleaseType' COPIED=$script:SumCopied RENAMED=$script:SumRenamed DELETED=$script:SumDeleted FAILED=$script:SumFailed" -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
    }
}
# リリースルールのスクリプト化
<#
.SYNOPSIS
    リリースルールを適用してファイルをコピーします

.DESCRIPTION
    指定されたファイルに対してリリースルールを適用し、リリース先へコピーします。
    既存ファイルが存在する場合はタイムスタンプ付きでリネーム・削除します。

.PARAMETER ReleaseTypeName
    リリースタイプ名（ログ出力用）

.PARAMETER FileObject
    コピー対象のファイルシステム情報オブジェクト

.PARAMETER ReleaseDestination
    リリース先フォルダパス

.PARAMETER LogPath
    ログファイルの完全パス

.PARAMETER SensitivePatterns
    ログに出力する際にマスキング対象とする機密情報キーワード配列

.PARAMETER OverwritePolicy
    既存ファイル処理ポリシー: RenameThenCopy, DeleteThenCopy, SkipIfExists

.PARAMETER RetryCount
    リトライ回数

.PARAMETER RetryDelayMs
    リトライ待機時間（ミリ秒）

.PARAMETER EnableLongPath
    ロングパス対応有効フラグ

.NOTES
    内部用関数 - Copy-ItemCustom から呼び出されます
    File Name: relMain.ps1 の Copy-ItemCustom 内部関数
    Version: 1.2.0
#>
function Invoke-ReleaseRule {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ReleaseTypeName,               # ログ用リリースタイプ名
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$FileObject,  # コピー対象ファイルオブジェクト
        [Parameter(Mandatory = $true)]
        [string]$ReleaseDestination,            # リリース先フォルダパス
        [Parameter(Mandatory = $true)]
        [string]$LogPath,                       # ログファイルパス    
        [Parameter(Mandatory = $false)]
        [string[]]$SensitivePatterns = @(),     # 機密情報キーワード配列
        [Parameter(Mandatory = $false)]
        [ValidateSet('RenameThenCopy', 'DeleteThenCopy', 'SkipIfExists')] # 既存ファイル処理ポリシー
        [string]$OverwritePolicy = 'RenameThenCopy',                    # 既存ファイル処理ポリシー
        [Parameter(Mandatory = $false)]
        [int]$RetryCount = 0,               # リトライ回数
        [Parameter(Mandatory = $false)]
        [int]$RetryDelayMs = 250,           # リトライ待機時間（ミリ秒）
        [Parameter(Mandatory = $false)]
        [bool]$EnableLongPath = $false      # ロングパス対応有効フラグ
    )
    # リリース先の既存リネームファイルを削除する
    $FileBaseName = $FileObject.BaseName      # ファイル名
    $FileExtension = $FileObject.Extension    # 拡張子
    $FileNameWithDatePattern = $FileBaseName + "_????????-??????" + $FileExtension    # リネームファイルの検索パターン
    # リネームファイルの検索
    $FileNameWithDate = Get-ChildItem -Path $ReleaseDestination -Filter $FileNameWithDatePattern -ErrorAction SilentlyContinue
    # 検索したリネームファイルを削除
    foreach ($RenamedFileName in $FileNameWithDate) { # リネームファイルが存在する場合
        # リネームファイルの削除処理
        try {
            Invoke-WithRetry { Remove-Item -Path $RenamedFileName.FullName -Force -ErrorAction Stop }
            # 削除結果をログに記述
            Write-CommonLog -Message "[DELETE] '$ReleaseTypeName' -> '$($RenamedFileName.FullName)'" -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
            $script:SumDeleted++
        } catch {
            # 削除に失敗した場合は、エラーメッセージをログに記述
            Write-CommonLog -Message "[ERROR] DELETE FAILED: '$($RenamedFileName.FullName)'." -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
            $script:SumFailed++
        }
    }

    # ファイルのコピー
    try {
        # もし、同一のファイルがあれば、yyyyMMdd-HHmmss形式でリネームを実施
        $ReleaseToFileName = Join-Path -Path $ReleaseDestination -ChildPath $FileObject.Name  
        $NewFileNameWithDate = $FileBaseName + "_" + (Get-Date -Format "yyyyMMdd-HHmmss") + $FileExtension
        $FileNameWithDatePath = Join-Path -Path $ReleaseDestination -ChildPath $NewFileNameWithDate
        $FileExist = Get-ChildItem -Path $ReleaseDestination -Filter $FileObject.Name -ErrorAction SilentlyContinue
        if ($FileExist) { # ファイルが存在する場合
            switch ($OverwritePolicy) { # 既存ファイル処理ポリシー
                'RenameThenCopy' { # リネームしてからコピー
                    Invoke-WithRetry { Rename-Item -Path $ReleaseToFileName -NewName $NewFileNameWithDate -Force -ErrorAction Stop }
                    Write-CommonLog -Message "[RENAME] '$ReleaseTypeName' -> '$FileNameWithDatePath'" -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
                    $script:SumRenamed++
                }
                'DeleteThenCopy' { # 削除してからコピー
                    Invoke-WithRetry { Remove-Item -Path $ReleaseToFileName -Force -ErrorAction Stop }
                    Write-CommonLog -Message "[DELETE] '$ReleaseTypeName' EXISTING -> '$ReleaseToFileName'" -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
                    $script:SumDeleted++
                }
                'SkipIfExists' { # 存在する場合はスキップ
                    Write-CommonLog -Message "[SKIP] EXISTS: '$ReleaseToFileName' (policy SkipIfExists)" -LogPath $LogPath -Level 'WARN' -SensitivePatterns $SensitivePatterns
                    return
                }
            }
        }
        # コピー処理
        Invoke-WithRetry { Copy-Item -Path $FileObject.FullName -Destination $ReleaseDestination -Force -ErrorAction Stop }
        # コピー結果をログに記述
        Write-CommonLog -Message "[COPY] '$ReleaseTypeName' -> '$($FileObject.Name)'" -LogPath $LogPath -Level 'INFO' -SensitivePatterns $SensitivePatterns
        $script:SumCopied++
    } catch {
        # コピーに失敗した場合は、エラーメッセージをログに記述
        Write-CommonLog -Message "[ERROR] COPY FAILED: '$($FileObject.FullName)' -> '$ReleaseDestination'" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
        Write-CommonLog -Message "[MESSAGE] $($_.Exception.Message)" -LogPath $LogPath -Level 'ERROR' -SensitivePatterns $SensitivePatterns
        $script:SumFailed++
    }
}