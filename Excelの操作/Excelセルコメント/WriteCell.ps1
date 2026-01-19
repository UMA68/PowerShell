# ================================
# セルに文字列とコメントを書き込む
# ================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ取得
$UpperDir = $scriptDir | Split-Path -Parent                     # 親ディレクトリ取得

# ターゲットExcelファイル
$targetExcel = Join-Path (Join-Path $UpperDir "Excel") "WriteCell.xlsx"

# -----------------
# 処理開始
# -----------------

# ファイル存在確認
if (-not (Test-Path $targetExcel)) {
    Write-Error "ファイルが見つかりません: $targetExcel"
    exit 1
}

# Excelファイルを開く（エラーハンドリング付き）
try {
    $objExcel = New-Object -ComObject Excel.Application # Excelを起動
    $objExcel.Visible = $true                           # Excelを表示
    
    $workbook = $objExcel.Workbooks.Open($targetExcel, 0, $false)     # Excelファイルを開く
    $worksheet = $workbook.Worksheets.Item(1)                       # 1番目のシートを選択

    # セルの値判定
    if ($worksheet.Cells.Item(1, 1).Value2 -ne $null) { # セルの値が空でない場合
        $worksheet.Cells.Item(1, 1).Value2 = ""              # セルの値初期化
        $comment = $worksheet.Cells.Item(1, 1).Comment       # コメントを取得
        if ($null -ne $comment) {
            $comment.Delete()                               # コメントを削除
        }
        $worksheet.Cells.Item(2, 1).Value2 = ""              # セルの値初期化
    }

    $worksheet.Cells.Item(1, 1).Value2 = "Hello"                             # セルに値を書き込む
    $comment = $worksheet.Cells.Item(1, 1).AddComment("Hello World を記入")  # セルにコメントを書き込む
    $comment.Shape.TextFrame.AutoSize = $true   # コメントのサイズを自動調整
    $comment.Visible = $false                   # コメントを非表示にする(マウスオーバー表示)

    # コメントの取得（コメントがない場合の対策）
    if ($null -ne $worksheet.Cells.Item(1, 1).Comment) {
        $strCom = $worksheet.Cells.Item(1, 1).Comment.Shape.TextFrame.Characters.Text  # コメントのテキスト取得
        $worksheet.Cells.Item(2, 1).Value2 = $strCom                    # セルに取得したコメントを書き込む
    } else {
        $worksheet.Cells.Item(2, 1).Value2 = "(コメントなし)"          # コメントがない場合
    }
    
    Write-Information "セルへの書き込みが完了しました。" -InformationAction Continue

} catch {
    Write-Error "エラーが発生しました: $_"
    exit 1
} finally {
    # -----------------
    # 終了処理
    # -----------------
    # COMオブジェクトを完全に解放
    if ($workbook) {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    }
    if ($objExcel) {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objExcel) | Out-Null
    }
    Remove-Variable objExcel, workbook -ErrorAction SilentlyContinue
}

