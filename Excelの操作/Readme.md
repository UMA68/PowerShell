# Excelの操作

## 概要

このフォルダーには、PowerShellを使用してExcelファイルを操作するための各種スクリプトが含まれています。Excel COMオブジェクトやImportExcelモジュールを活用して、データの比較、コメント操作、SQL Serverからのデータエクスポートなど、さまざまなExcel操作を自動化できます。

## サンプル一覧

### 📊 [ExcelBook比較](./ExcelBook比較/)

**機能**: 2つのExcelファイルの内容を比較し、差分がある行を自動的に強調表示

**主な特徴**:

- 2つのExcelブック（typeA.xlsxとtypeB.xlsx）の指定シート間でデータ比較
- CD、KEY、Chr1～3、Num1～3の各列を基準に差分を検出
- 差分がある行をシアン色で自動ハイライト
- 差分データを`compdata.xlsx`として出力
- オートフィルターとウィンドウ固定機能

**使用技術**: ImportExcelモジュール、Excel COMオブジェクト

**詳細**: [ExcelBook比較/Readme.md](./ExcelBook比較/Readme.md)

---

### 💬 [Excelセルコメント](./Excelセルコメント/)

**機能**: Excelのセルにテキストとコメントを書き込み、コメント内容を別セルに抽出

**主な特徴**:

- セルに値とコメントを記入
- コメント枠のサイズを自動調整
- マウスオーバー時のみ表示される設定
- セルコメントの内容を取得して別セルに出力
- コメントがない場合のエラーハンドリング

**使用技術**: Excel COMオブジェクト

**詳細**: [Excelセルコメント/Readme.md](./Excelセルコメント/Readme.md)

---

### 🗄️ [ExportExcel](./ExportExcel/)

**機能**: SQL Serverデータベースからデータを取得し、Excelファイルとして出力

**主な特徴**:

- 暗号化されたパスワードを使用したセキュアなDB接続
- パラメーター化されたSQLクエリの実行
- 必要な列のみを抽出してExcel出力
- 列幅自動調整、オートフィルター、先頭行固定
- Excelテーブル形式での出力
- 既存ファイルの上書き確認ダイアログ

**使用技術**: SqlServerモジュール、ImportExcelモジュール、暗号化認証

**詳細**: [ExportExcel/Readme.md](./ExportExcel/Readme.md)

---

## 共通の前提条件

### 必須環境

- **Windows 10/11**: Windows環境
- **PowerShell 5.1** 以降（またはPowerShell 7.x）
- **Microsoft Excel**: インストール済みであること（COM操作を使用するスクリプトの場合）

### 必要なモジュール

各サンプルで使用されるPowerShellモジュール：

```powershell
# ImportExcelモジュール（ExcelBook比較、ExportExcelで使用）
Install-Module -Name ImportExcel -Scope CurrentUser

# SqlServerモジュール（ExportExcelで使用）
Install-Module -Name SqlServer -Scope CurrentUser
```

## ディレクトリ構造

```Shell
Excelの操作/
├── Readme.md                          # このファイル
├── mssql2022-dev-db.pass              # 暗号化パスワードファイル（ExportExcel用）
├── Excel/                             # Excelファイル格納フォルダ
│   ├── typeA.xlsx                     # ExcelBook比較用：比較元ファイル
│   ├── typeB.xlsx                     # ExcelBook比較用：比較先ファイル
│   ├── compdata.xlsx                  # ExcelBook比較用：差分出力ファイル（自動生成）
│   ├── WriteCell.xlsx                 # Excelセルコメント用：対象ファイル
│   └── ExptExcel.xlsx                 # ExportExcel用：出力ファイル（自動生成）
├── ExcelBook比較/
│   ├── ExcelComp.ps1                  # メインスクリプト
│   └── Readme.md                      # 詳細ドキュメント
├── Excelセルコメント/
│   ├── WriteCell.ps1                  # メインスクリプト
│   └── Readme.md                      # 詳細ドキュメント
└── ExportExcel/
    ├── ExptExcel.ps1                  # メインスクリプト
    └── Readme.md                      # 詳細ドキュメント
```

## 使い方

### 基本的な実行手順

各サンプルスクリプトは独立して実行可能です：

```powershell
# ExcelBook比較の実行
Set-Location "$HOME\GitHub\PowerShell\Excelの操作\ExcelBook比較"
.\ExcelComp.ps1

# Excelセルコメントの実行
Set-Location "$HOME\GitHub\PowerShell\Excelの操作\Excelセルコメント"
.\WriteCell.ps1

# ExportExcelの実行（要：DB接続設定）
Set-Location "$HOME\GitHub\PowerShell\Excelの操作\ExportExcel"
.\ExptExcel.ps1
```

### 初回セットアップ

1. **PowerShellモジュールのインストール**

```powershell
# 管理者権限不要（CurrentUserスコープ）
Install-Module -Name ImportExcel -Scope CurrentUser
Install-Module -Name SqlServer -Scope CurrentUser
```

2. **Excelファイルの配置**

各サンプル用のExcelファイルを`Excel`フォルダーに配置してください。

3. **スクリプト実行ポリシーの設定**（必要に応じて）

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## よくある質問

### Q1: ImportExcelモジュールとExcel COM オブジェクトの違いは？

**ImportExcelモジュール**:

- Excelアプリケーションのインストール不要
- 軽量で高速
- ファイルの読み書きに特化
- 視覚的な書式設定は制限あり

**Excel COM オブジェクト**:

- Excelアプリケーションが必要
- すべてのExcel機能にアクセス可能
- セルコメント、マクロ、高度な書式設定が可能
- パフォーマンスはImportExcelより劣る

### Q2: どのサンプルから始めるべきか？

**初心者向け**:

- **Excelセルコメント** - Excel COMの基本操作を学べます

**データ分析向け**:

- **ExcelBook比較** - データの差分確認に便利

**業務自動化向け**:

- **ExportExcel** - DB連携とExcel出力の実践的な例

### Q3: エラーが発生した場合は？

各サンプルの`Readme.md`に詳細なトラブルシューティングセクションがあります。主なエラー：

- **モジュール未インストール**: `Install-Module`でインストール
- **ファイルが見つからない**: パスとファイル名を確認
- **Excel COM エラー**: Excelアプリケーションをインストール/再起動
- **権限エラー**: スクリプト実行ポリシーを確認

## 開発のヒント

### ImportExcelモジュールの活用

```powershell
# データの読み込み
$data = Import-Excel -Path "sample.xlsx" -WorksheetName "Sheet1"

# データの書き込み
$data | Export-Excel -Path "output.xlsx" -AutoSize -AutoFilter -FreezeTopRow

# 複数シートの書き込み
$data1 | Export-Excel -Path "output.xlsx" -WorksheetName "Sheet1"
$data2 | Export-Excel -Path "output.xlsx" -WorksheetName "Sheet2"
```

### Excel COM の基本パターン

```powershell
try {
    # Excel起動
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $true
    
    # ファイルを開く
    $workbook = $excel.Workbooks.Open($filePath)
    $worksheet = $workbook.Worksheets.Item(1)
    
    # 操作実行
    $worksheet.Cells.Item(1,1).Value2 = "Hello"
    
    # 保存
    $workbook.Save()    # 削除またはコメントアウトしている場合があります
} catch {
    Write-Error "エラー: $_"
} finally {
    # COM オブジェクト解放
    if ($workbook) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null }
    if ($excel) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null }
}
```

## セキュリティとベストプラクティス

### 🔒 セキュリティ

1. **暗号化ファイルの管理**
   - `.pass`ファイルと`Encryption.Key`をバージョン管理システムにコミットしない
   - `.gitignore`に追加推奨

2. **COM オブジェクトの解放**
   - 必ず`finally`ブロックで`ReleaseComObject`を実行
   - メモリリークを防ぐ

3. **エラーハンドリング**
   - `try-catch-finally`パターンを使用
   - ユーザーフレンドリーなエラーメッセージ

### ✅ ベストプラクティス

1. **パス指定**
   - `Join-Path`を使用してプラットフォーム互換性を確保
   - ハードコードされたパスを避ける

2. **リソース管理**
   - ファイルハンドルを適切に閉じる
   - COMオブジェクトを確実に解放

3. **データ検証**
   - 入力ファイルの存在確認
   - データの空チェック
   - 列の存在確認

## 参考リンク

- [ImportExcel モジュール](https://github.com/dfinke/ImportExcel)
- [Excel COM オブジェクト](https://docs.microsoft.com/office/vba/api/overview/excel)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [SqlServer モジュール](https://docs.microsoft.com/powershell/module/sqlserver/)

## ライセンスと貢献

各スクリプトは学習・業務利用目的で自由に使用・改変できます。

---

**各サンプルの詳細な使用方法とトラブルシューティングについては、それぞれのフォルダー内のReadme.mdをご参照ください。**
