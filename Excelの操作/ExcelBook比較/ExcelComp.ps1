# =================================
# 二つのExcelファイルの内容を比較し、
# 差分のあった箇所を表示する
# =================================

# 定数定義
$HIGHLIGHT_COLOR = 20  # シアン色 (20:シアン 38:赤)

# Import-Excelモジュールの存在チェック
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Error "ImportExcelモジュールがインストールされていません。Install-Module ImportExcel を実行してください。"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path    # スクリプトのディレクトリ取得
$UpperDir = $scriptDir | Split-Path -Parent                     # 親ディレクトリ取得

# 比較する2つのExcelファイルのパス
$excelFileA = Join-Path $UpperDir "Excel\typeA.xlsx"
$excelFileB = Join-Path $UpperDir "Excel\typeB.xlsx"
$outputFile = Join-Path $UpperDir "Excel\compdata.xlsx"

# ファイル存在チェック
if (-not (Test-Path $excelFileA)) {
    Write-Error "ファイルが見つかりません: $excelFileA"
    exit 1
}
if (-not (Test-Path $excelFileB)) {
    Write-Error "ファイルが見つかりません: $excelFileB"
    exit 1
}

try {
    # Excelファイルを読み込む
    $data1 = Import-Excel -Path $excelFileA -WorksheetName "before"
    $data2 = Import-Excel -Path $excelFileB -WorksheetName "after"

# $data1と$data2の内容を比較する
$diff = Compare-Object -ReferenceObject $data1 -DifferenceObject $data2 -Property 'CD', 'KEY', 'Chr1', 'Chr2', 'Chr3', 'Num1', 'Num2', 'Num3'

# 差分のあった行のみ表示する
$diff | Where-Object { $_.SideIndicator -eq '=>' } | Format-Table

# 差分のあった箇所を表示する(typeB.xlsx)
$compdata = $diff | Where-Object { $_.SideIndicator -eq '=>' } 

    # Excelファイルの存在チェック
    if (Test-Path $outputFile) {
        Remove-Item $outputFile -Force
    }
    # Excelファイルにデータを書き込む
    $compdata | Export-Excel -Path $outputFile -WorksheetName "compdata" -NumberFormat '@' -AutoSize

    $row = @() 
    $Count = $compdata.Count
    foreach ($i in 0..($Count - 1)) { 
        $row += $data2 | Where-Object { $_.CD -eq $compdata[$i].CD -and $_.KEY -eq $compdata[$i].KEY }
    }

    $row | Format-Table

    # ----------------------------------------
    # 差分のあった箇所に色を付ける(typeB.xlsx)
    # ----------------------------------------
    # Excel起動
    $excel = $null
    $workbook = $null
    
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $true

        # Excelファイルを開く
        $workbook = $excel.Workbooks.Open($excelFileB)

# シートを選択
$sheet = $workbook.Worksheets.Item("after")
$usedrange = $sheet.UsedRange   # 使用範囲を取得

# オートフィルタが設定されていたら解除
if ($sheet.AutoFilterMode -eq $true) {
    $usedrange.UsedRange.AutoFilter()  
}
# オートフィルターを設定
$usedrange.rows("1").AutoFilter() | Out-Null

        # フィルター対象に色をつける
        $Count = $compdata.Count
        foreach ($i in 0..($Count - 1)) { 
            $usedrange.AutoFilter(1, $compdata[$i].CD) | Out-Null   # CD列をフィルター
            $usedrange.AutoFilter(2, $compdata[$i].KEY) | Out-Null  # KEY列をフィルター

            # フィルターをかけた行を取得
            $targetRow = $usedrange.rows | Where-Object { $_.EntireRow.Hidden -eq $false } | Select-Object -Skip 1

            # 取得した行を選択
            $targetRow.EntireRow.Select() | Out-Null

            # 選択した行に色を付ける
            $excel.Selection.Interior.ColorIndex = $HIGHLIGHT_COLOR
        }

        # 終了処理
        $excel.Selection.EntireRow.Select() | Out-Null # 選択行を解除
        $usedrange.AutoFilter() | Out-Null # フィルターを解除

        # 先頭行を固定する
        $sheet.Activate()
        $sheet.Application.ActiveWindow.SplitRow = 1        # 1行目を分離する
        $sheet.Application.ActiveWindow.FreezePanes = $true # 固定する

        # 選択行のフォーカスを外す
        $sheet.Range("A1").Select() | Out-Null
        
        Write-Information "処理が正常に完了しました。Excelファイルは開いたままです。" -InformationAction Continue
        
    } catch {
        Write-Error "Excel操作中にエラーが発生しました: $_"
    } finally {
        # COM オブジェクトの解放（Excelは開いたままにする）
        if ($workbook) {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
        }
        if ($excel) {
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        }
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        # 変数のクリーンアップ
        Remove-Variable -Name row, targetRow, excel, workbook -ErrorAction SilentlyContinue
    }
    
} catch {
    Write-Error "処理中にエラーが発生しました: $_"
    exit 1
}