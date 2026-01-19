# ExcelBook比較 - ExcelComp.ps1

## 概要

2つのExcelファイルの内容を比較し、差分がある行を自動的に強調表示するPowerShellスクリプトです。比較結果は別ファイルに出力され、差分箇所には色付けが行われます。

## 主な機能

### 📊 データ比較機能

- **Excelファイル比較**: 2つのExcelブックの指定シート間でデータを比較
- **差分検出**: CD、KEY、Chr1～3、Num1～3の各列を基準に差分を検出
- **差分出力**: 検出された差分を`compdata.xlsx`として出力

### 🎨 視覚化機能

- **自動ハイライト**: 差分がある行をシアン色（変更可能）で強調表示
- **オートフィルター**: 比較対象シートにフィルター設定を追加
- **ウィンドウ固定**: 先頭行を固定して見やすく表示

## 前提条件

### 必須要件

- **Windows 10/11**: Windows環境
- **PowerShell 5.1** 以降（またはPowerShell 7.x）
- **Microsoft Excel**: インストール済みであること（COM操作に使用）
- **ImportExcelモジュール**: PowerShell Galleryからインストール

### ImportExcelモジュールのインストール

```powershell
# ImportExcelモジュールのインストール（管理者権限で実行）
Install-Module -Name ImportExcel -Scope CurrentUser
```

## ディレクトリ構造

```Shell
Excelの操作/
└── ExcelBook比較/
    ├── ExcelComp.ps1          # メインスクリプト
    ├── Readme.md              # このファイル
    └── ../Excel/              # 比較対象Excelファイルの配置場所
        ├── typeA.xlsx         # 比較元ファイル（beforeシート）
        ├── typeB.xlsx         # 比較先ファイル（afterシート）
        └── compdata.xlsx      # 差分出力ファイル（自動生成）
```

## 使い方

### 基本的な使用方法

1. **Excelファイルの準備**
   - `Excel`フォルダーに比較したいExcelファイルを配置
   - `typeA.xlsx`に「before」という名前のシートを作成
   - `typeB.xlsx`に「after」という名前のシートを作成
   - 両シートに以下の列が必要: `CD`, `KEY`, `Chr1`, `Chr2`, `Chr3`, `Num1`, `Num2`, `Num3`

2. **スクリプトの実行**

```powershell
# スクリプトのあるディレクトリに移動
Set-Location "$HOME\GitHub\PowerShell\Excelの操作\ExcelBook比較"

# スクリプト実行
.\ExcelComp.ps1
```

### 実行結果

スクリプトは以下の処理を順番に実行します：

1. ✅ ImportExcelモジュールの存在確認
2. ✅ 比較対象ファイルの存在確認
3. ✅ データの読み込みと比較
4. ✅ 差分の検出と表示
5. ✅ 差分データを`compdata.xlsx`に出力
6. ✅ `typeB.xlsx`を開いて差分行をハイライト表示
7. ✅ オートフィルターと先頭行固定を設定

```Terminal
INFO: 処理が正常に完了しました。Excelファイルは開いたままです。
```

## スクリプト詳細

### 比較対象の列

デフォルトで以下の列を比較対象としています：

- `CD`: コード
- `KEY`: キー
- `Chr1`, `Chr2`, `Chr3`: 文字列フィールド
- `Num1`, `Num2`, `Num3`: 数値フィールド

### ハイライト色の変更

スクリプト冒頭の定数を変更することで色を変更できます：

```powershell
# 定数定義
$HIGHLIGHT_COLOR = 20  # シアン色 (20:シアン 38:赤 6:黄色 3:赤)
```

### 出力ファイル

- **compdata.xlsx**: 差分データのみを抽出したファイル
  - シート名: `compdata`
  - 形式: 数値も文字列として保存（`@`フォーマット）
  - 列幅: 自動調整

## トラブルシューティング

### よくある問題と解決方法

#### 1. 「ImportExcelモジュールがインストールされていません」エラー

```Terminal
ImportExcelモジュールがインストールされていません。Install-Module ImportExcel を実行してください。
```

**解決方法**:

```powershell
# PowerShellを管理者として起動
Install-Module -Name ImportExcel -Scope CurrentUser
```

#### 2. ファイルが見つからないエラー

```Terminal
ファイルが見つかりません: C:\...\Excel\typeA.xlsx
```

**解決方法**:

- Excelファイルが正しい場所に配置されているか確認
- ファイル名が`typeA.xlsx`、`typeB.xlsx`であることを確認
- スクリプトのパス設定を確認

#### 3. シートが見つからないエラー

```Terminal
指定されたシート 'before' が見つかりません
```

**解決方法**:

- `typeA.xlsx`に「before」という名前のシートが存在するか確認
- `typeB.xlsx`に「after」という名前のシートが存在するか確認
- シート名のスペルと大文字小文字を確認

#### 4. Excel COM オブジェクトのエラー

```Terminal
Excel操作中にエラーが発生しました: ...
```

**解決方法**:

- Excelがインストールされているか確認
- Excelを一度起動して初期設定を完了させる
- すでに開いているExcelファイルがある場合は閉じる
- タスクマネージャーでExcelプロセスが残留していないか確認

#### 5. 列が存在しないエラー

**解決方法**:

- 両方のExcelシートに以下の列が存在することを確認:
  - `CD`, `KEY`, `Chr1`, `Chr2`, `Chr3`, `Num1`, `Num2`, `Num3`
- 列名が正確に一致していることを確認（大文字小文字も含む）

## 仕様に関する注意事項

### ⚠️ 重要な注意点

1. **比較基準**: 差分検出は指定された8列の値を基準に行われます
2. **SideIndicator**: `'=>'`（差分先にのみ存在）の行のみを抽出します
3. **Excel表示**: 処理完了後、Excelファイルは開いたままになります
4. **上書き注意**: `compdata.xlsx`は毎回上書きされます
5. **COM解放**: スクリプト終了時にCOMオブジェクトを適切に解放します

### 🔧 カスタマイズ可能な箇所

- **比較対象列**: スクリプト内の`-Property`パラメーターを変更
- **ハイライト色**: `$HIGHLIGHT_COLOR`定数を変更
- **ファイル名**: `$excelFileA`、`$excelFileB`の値を変更
- **シート名**: `Import-Excel`の`-WorksheetName`を変更

## 高度な使用例

### 例1: 異なるファイル名で実行

スクリプト冒頭を以下のように変更：

```powershell
$excelFileA = Join-Path $UpperDir "Excel\source.xlsx"
$excelFileB = Join-Path $UpperDir "Excel\target.xlsx"
```

### 例2: 比較列の変更

比較対象の列を変更する場合：

```powershell
$diff = Compare-Object -ReferenceObject $data1 -DifferenceObject $data2 `
    -Property 'ID','Name','Value1','Value2'
```

### 例3: ハイライト色を赤に変更

```powershell
$HIGHLIGHT_COLOR = 38  # 赤色
```

## 終了コード

- **0**: 正常終了
- **1**: エラー終了（モジュール不足、ファイル未検出、処理エラー等）

## 参考情報

- [ImportExcel モジュール](https://github.com/dfinke/ImportExcel)
- [PowerShell Compare-Object](https://docs.microsoft.com/powershell/module/microsoft.powershell.utility/compare-object)
- [Excel COM オブジェクト](https://docs.microsoft.com/office/vba/api/overview/excel)

## バージョン履歴

### v2.1.0 (2026-01-19)

- PSScriptAnalyzer対応による品質改善
- Write-Host → Write-Informationに変更（ホスト互換性向上）
- コードスタイルの統一（スペース、中括弧の配置）
- ベストプラクティスへの準拠

### v2.0.0 (2026-01-05)

- エラーハンドリングの強化（try-catch-finally）
- COMオブジェクトの適切な解放処理
- ファイル存在チェックの追加
- ImportExcelモジュールチェックの追加
- パス結合の修正（Join-Path使用）
- ループ効率化（不要なインクリメント削除）
- 定数化（ハイライト色）
- リソースリーク対策

### v1.0.0 (初期リリース)

- 基本的なExcel比較機能
- 差分検出とハイライト表示
- compdata.xlsx出力機能
