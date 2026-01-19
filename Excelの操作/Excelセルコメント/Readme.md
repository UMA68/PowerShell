# Excelセルコメント - WriteCell.ps1

## 概要

Excelのセルにテキストとコメントを書き込み、セルコメントの内容を別のセルに抽出するPowerShellスクリプトです。セルコメント機能を活用した自動化処理を実現します。

## 主な機能

### 📝 セル書き込み機能

- **値の書き込み**: Excelセルに指定したテキストを記入
- **コメント追加**: セルにコメント（注釈）を追加
- **コメント自動調整**: コメント枠のサイズを内容に合わせて自動調整
- **コメント非表示**: マウスオーバー時のみ表示される設定

### 🔍 コメント抽出機能

- **コメント取得**: セルのコメント内容を取得して別セルに出力
- **エラーハンドリング**: コメントがない場合も適切に処理
- **初期化機能**: 前回の処理内容をリセット

## 前提条件

### 必須要件

- **Windows 10/11**: Windows環境
- **PowerShell 5.1** 以降（またはPowerShell 7.x）
- **Microsoft Excel**: インストール済みであること（COM操作に使用）

## ディレクトリ構造

```Shell
Excelの操作/
└── Excelセルコメント/
    ├── WriteCell.ps1      # メインスクリプト
    ├── Readme.md          # このファイル
    └── ../Excel/          # Excelファイルの配置場所
        └── WriteCell.xlsx # 対象Excelファイル
```

## 使い方

### 基本的な使用方法

1. **Excelファイルの準備**
   - `Excel`フォルダーに`WriteCell.xlsx`を配置
   - ファイルは1つ以上のシートを含む必要があります

2. **スクリプトの実行**

```powershell
# スクリプトのあるディレクトリに移動
Set-Location "$HOME\GitHub\PowerShell\Excelの操作\Excelセルコメント"

# スクリプト実行
.\WriteCell.ps1
```

### 実行結果

スクリプトは以下の処理を順番に実行します：

1. ✅ Excelファイルの存在確認
2. ✅ Excelアプリケーションの起動
3. ✅ 既存のセル値とコメントを初期化
4. ✅ セルA1に「Hello」と入力
5. ✅ セルA1に「Hello Worldを記入」というコメントを追加
6. ✅ コメント枠をテキスト合わせにリサイズ
7. ✅ セルA2にコメント内容を抽出
8. ✅ ファイルを保存

```Terminal
INFO: セルへの書き込みが完了しました。
```

## スクリプト詳細

### 処理の流れ

#### 1. **初期化処理**

セルA1に値がある場合、以下の初期化を実行：

- セルA1の値をクリア
- セルA1のコメントを削除（存在する場合）
- セルA2の値をクリア

```powershell
if ($worksheet.Cells.Item(1, 1).Value2 -ne $null) {
    $worksheet.Cells.Item(1, 1).Value2 = ""
    $comment = $worksheet.Cells.Item(1, 1).Comment
    if ($null -ne $comment) {
        $comment.Delete()
    }
}
```

#### 2. **セル書き込み処理**

セルA1に値とコメントを記入：

```powershell
$worksheet.Cells.Item(1, 1).Value2 = "Hello"
$comment = $worksheet.Cells.Item(1, 1).AddComment("Hello World を記入")
$comment.Shape.TextFrame.AutoSize = $true
$comment.Visible = $false
```

#### 3. **コメント抽出処理**

セルA1のコメント内容をセルA2に出力：

```powershell
if ($null -ne $worksheet.Cells.Item(1, 1).Comment) {
    $strCom = $worksheet.Cells.Item(1, 1).Comment.Shape.TextFrame.Characters.Text
    $worksheet.Cells.Item(2, 1).Value2 = $strCom
}
```

### 特殊な設定

| 設定項目 | 現在値 | 説明 |
|---------|------|------|
| 対象セル (値) | A1 | セルコメント書き込み対象 |
| 対象セル (抽出先) | A2 | コメント内容の抽出先 |
| 書き込み内容 | "Hello" | セルに記入するテキスト |
| コメント内容 | "Hello World を記入" | セルに追加するコメント |
| コメント表示方式 | マウスオーバー時 | `Visible = $false` で実現 |

## トラブルシューティング

### よくある問題と解決方法

#### 1. ファイルが見つからないエラー

```Terminal
Write-Error: ファイルが見つかりません: C:\...\Excel\WriteCell.xlsx
```

**解決方法**:

- Excelファイルが正しい場所に配置されているか確認
- ファイル名が`WriteCell.xlsx`であることを確認
- スクリプトのパス設定を確認

#### 2. Excel COM オブジェクトのエラー

```Terminal
Write-Error: エラーが発生しました: ...
```

**解決方法**:

- Excelがインストールされているか確認
- すでに開いているExcelファイルがある場合は閉じる
- タスクマネージャーでExcelプロセスが残留していないか確認
- PowerShellを管理者として実行してみる

#### 3. コメント抽出時の型キャストエラー

```Terminal
Write-Error: エラーが発生しました: Unable to cast object of type...
```

**解決方法**:

- Excel COMオブジェクトの型が異なっている可能性があります
- 以下の正しいパスを使用：

  ```powershell
  .Comment.Shape.TextFrame.Characters.Text
  ```

## 高度なカスタマイズ

### 異なるセルに書き込む場合

スクリプト内の`Item(1,1)`を変更します：

```powershell
# セルB2に書き込む場合
$worksheet.Cells.Item(2, 2).Value2 = "Hello"
$comment = $worksheet.Cells.Item(2, 2).AddComment("コメント")
```

セルの指定方法：

- `Item(行番号, 列番号)`: 例）`Item(3,5)` = セルE3

### コメント内容をカスタマイズする場合

```powershell
$comment = $worksheet.Cells.Item(1, 1).AddComment("カスタムコメント")
```

### 複数セルにコメントを追加する場合

```powershell
for ($i = 1; $i -le 10; $i++) {
    $worksheet.Cells.Item($i, 1).Value2 = "Row $i"
    $worksheet.Cells.Item($i, 1).AddComment("Row $i のコメント")
}
```

## 終了コード

- **0**: 正常終了
- **1**: エラー終了（ファイル未検出、処理エラー等）

## 参考情報

- [Excel COM オブジェクト](https://docs.microsoft.com/office/vba/api/overview/excel)
- [PowerShell COM オブジェクト操作](https://docs.microsoft.com/powershell/scripting/learn/deep-dives/working-with-com-objects)

## 注意事項

### ⚠️ 重要な注意点

1. **スクリプトは自動でExcelを開く**: 処理完了後、Excelアプリケーションはメモリに残ります
2. **COM解放**: スクリプト終了時にCOMオブジェクトを適切に解放します
3. **実行権限**: 一度だけスクリプト実行ポリシーを設定する必要がある場合があります：

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## バージョン履歴

### v2.1.0 (2026-01-19)

- PSScriptAnalyzer対応による品質改善
- Write-Host → Write-Informationに変更（ホスト互換性向上）
- コードスタイルの統一（カンマ後のスペース、中括弧の配置）
- ベストプラクティスへの準拠

### v2.0.0 (2026-01-05)

- エラーハンドリング強化（try-catch-finally）
- ファイル存在確認追加
- パス結合修正（Join-Path使用）
- 変数名統一（大文字小文字）
- ファイル保存処理追加
- COMオブジェクト完全解放
- コメントテキスト取得パス修正
- 成功メッセージ表示

### v1.0.0 (初期リリース)

- 基本的なセル書き込み機能
- コメント追加機能
- コメント抽出機能
