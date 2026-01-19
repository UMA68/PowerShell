# ファイルアクセスブロック解除

ダウンロードされたファイルや外部から取得したファイルに付与される `Zone.Identifier` 代替データストリームを一括削除し、Windowsのアクセスブロックを解除するPowerShellスクリプトです。

## 概要

Windowsでは、インターネットからダウンロードしたファイルや、外部ストレージから取得したファイルに対して、セキュリティ保護のため自動的に「ブロック」が設定されます。このブロック情報は `Zone.Identifier` という代替データストリーム（ADS）として保存されます。

本スクリプトは、指定されたディレクトリ内のファイルから `Zone.Identifier` ストリームを検出・削除し、ファイルのブロックを一括解除します。

## 主な機能

- **Zone.Identifier 自動検出**: 代替データストリームの存在を自動的に検出
- **一括処理**: ディレクトリ内のファイルを再帰的にスキャンして一括処理
- **除外設定**: 拡張子やフォルダパターンによる柔軟な除外設定
- **詳細ログ**: 処理結果の詳細なログ出力とサマリ表示
- **二重起動防止**: Mutexによる安全な多重実行防止
- **エラーハンドリング**: 各ファイルのエラーを個別にハンドリングし、処理を継続
- **パラメーター検証**: 入力値の妥当性を事前検証

## 前提条件

- **PowerShell**: 7.3.9以上
- **実行ポリシー**: RemoteSigned以上
- **依存スクリプト**:
  - `Common/NoDoubleActivation.ps1` - 二重起動防止機能
  - `Common/Write-CommonLog.ps1` - ログ出力関数

## ディレクトリ構成

```Shell
PowerShell/
├── Common/
│   ├── NoDoubleActivation.ps1
│   └── Write-CommonLog.ps1
└── ファイルアクセスブロック解除/
    ├── Readme.md                        (このファイル)
    ├── アクセスブロック解除.ps1 - ショートカット.lnk
    ├── Script/
    │   └── unblock_files.ps1            (メインスクリプト)
    ├── FileAccessBlock/                  (デフォルト処理対象フォルダ)
    │   └── TEST_A.txt
    └── LOG/                              (ログ自動作成先)
        └── unblock_YYYYMMDD-HHmmss.log
```

## 使い方

### 基本的な使用方法

```powershell
# デフォルト設定で実行（FileAccessBlockフォルダを処理）
.\Script\unblock_files.ps1
```

### パラメーター指定

```powershell
# 対象フォルダを指定
.\Script\unblock_files.ps1 -TargetFolder "Downloads"

# 除外する拡張子を指定
.\Script\unblock_files.ps1 -ExcludeExtensions @('.txt', '.pdf', '.docx')

# 除外フォルダパターンを指定（正規表現）
.\Script\unblock_files.ps1 -ExcludeFolderPattern "\\(Backup|Archive|Temp)\\"

# 詳細ログモード
.\Script\unblock_files.ps1 -VerboseLogging

# ログファイル名のプレフィックスを指定
.\Script\unblock_files.ps1 -LogPrefix "mylog_"

# 複合指定
.\Script\unblock_files.ps1 `
    -TargetFolder "MyFiles" `
    -ExcludeExtensions @('.log', '.tmp') `
    -ExcludeFolderPattern "\\System\\" `
    -VerboseLogging
```

## パラメーター一覧

| パラメーター | 型 | デフォルト値 | 説明 |
|----------|-----|------------|------|
| `TargetFolder` | string | `"FileAccessBlock"` | 処理対象のフォルダー名（相対パス） |
| `LogPrefix` | string | `"unblock_"` | ログファイル名のプレフィックス |
| `ExcludeExtensions` | string[] | `@('.log', '.xlsx')` | 除外する拡張子のリスト |
| `ExcludeFolderPattern` | string | `'\\Script\\'` | 除外するフォルダパターン（正規表現） |
| `VerboseLogging` | switch | `$false` | 詳細ログ出力の有効化 |

### パラメーター検証

すべてのパラメーターには入力検証が実装されています：

- **TargetFolder / LogPrefix**:
  - 空白文字のみの入力は不可
  - ファイル名に使用できない文字（`\ / : * ? " < > |`）を含まない
  - 最大255文字まで

- **ExcludeFolderPattern**:
  - 正規表現として妥当な形式である必要があります

## 処理結果サマリ

スクリプト実行後、以下の情報がログに出力されます：

| 項目 | 説明 |
|------|------|
| Total files processed | 処理対象ファイルの総数 |
| Files unblocked | Zone.Identifierを削除したファイル数 |
| Files already unblocked | 元々Zone.Identifierがないファイル数 |
| Files with access errors | ストリームアクセス時にエラーが発生したファイル数 |
| Files failed to unblock | Unblock-File実行時にエラーが発生したファイル数 |
| Success rate | 成功率（%） |
| Processing time | 処理時間（分:秒） |

### サマリ例

```log
===== Processing Summary =====
Total files processed: 150
Files unblocked: 45
Files already unblocked: 100
Files with access errors: 3
Files failed to unblock: 2
Success rate: 96.67%
Processing time: 02:Min 15:Sec
==============================
```

## 処理フロー

1. **パラメーター検証**: ValidateScript属性による入力値チェック
2. **二重起動チェック**: Mutexによる多重実行防止
3. **共通スクリプトインポート**: NoDoubleActivation.ps1、Write-CommonLog.ps1の読み込み
4. **ログディレクトリ作成**: LOGフォルダーが存在しない場合は自動作成
5. **対象ディレクトリ確認**: 処理対象フォルダーの存在チェック
6. **コマンドレット確認**: Unblock-Fileの利用可能性チェック
7. **ファイルスキャン**: 再帰的にファイルを取得し、除外パターンを適用
8. **Zone.Identifier検出**: 各ファイルの代替データストリームを確認
9. **ブロック解除**: Unblock-Fileコマンドレットでストリームを削除
10. **エラーハンドリング**: FileNotFoundException、アクセスエラーなどを個別処理
11. **サマリ出力**: 処理結果の集計と表示
12. **ログ表示**: 完了後、ログファイルを自動的に開く

## エラーハンドリング

### FileNotFoundException

Zone.Identifierストリームが存在しない場合（正常な状態）。`Files already unblocked`にカウントされます。

### アクセスエラー

ファイルがロックされている、権限不足などでストリームにアクセスできない場合。`Files with access errors`にカウントされ、警告ログが記録されます。

### Unblock失敗

Unblock-Fileの実行中にエラーが発生した場合。`Files failed to unblock`にカウントされ、エラーログが記録されます。

## ログファイル

### ログファイル名形式

```log
{LogPrefix}YYYYMMDD-HHmmss.log
```

例: `unblock_20251212-143025.log`

### ログレベル

- **INFO**: 通常の処理情報
- **WARN**: Zone.Identifier検出、アクセスエラー
- **ERROR**: 処理失敗、致命的なエラー

### ログ出力先

スクリプトの親ディレクトリ直下（デフォルトでは`ファイルアクセスブロック解除`フォルダー直下）

## トラブルシューティング

### 「すでに起動しています」と表示される

別のプロセスで同じスクリプトが実行中です。先に実行中のプロセスが終了するまで待ってください。

### 「Target directory does not exist」エラー

指定したTargetFolderが存在しません。パスを確認してください。

### 「Unblock-File command not found」エラー

PowerShellのバージョンが古い、または環境がUnblock-Fileコマンドレットをサポートしていません。PowerShell 7.3.9以上にアップグレードしてください。

### 一部のファイルが「Files with access errors」にカウントされる

ファイルが他のアプリケーションで開かれている、権限不足、またはファイルシステムの問題が考えられます。ログファイルで詳細なエラーメッセージを確認してください。

## 注意事項

- **バックアップ推奨**: 重要なファイルを処理する前に、必ずバックアップを取得してください
- **権限**: ファイルに対する読み取り・書き込み権限が必要です
- **除外設定**: 誤って重要なファイルを処理しないよう、適切な除外設定を行ってください
- **セキュリティ**: Zone.Identifierを削除すると、Windowsのセキュリティ警告が表示されなくなります。信頼できるファイルのみを処理してください

## バージョン履歴

### v2.1.1 (2026-01-19)

- PSScriptAnalyzer準拠対応（コード品質改善）
- ホワイトスペースの一貫性修正（開き括弧前、演算子周辺）
- 空のcatchブロック改善（Write-Verbose追加）
- コーディング規約遵守による可読性向上

### v2.1.0 (2025-12-12)

- FileNotFoundException例外ハンドリング追加（Zone.Identifier不在時の正確な処理）
- accessErrorFilesカウンターの明確化（skippedFilesから変更）
- ログメッセージの改善（"Files with access errors"）
- ヘルプドキュメントの拡充（処理フロー、サマリ説明追加）

### v2.0.0 (2025-12-12)

- パラメーター検証の追加（ValidateScript属性）
- 変数スコープの統一（$script: プレフィックス）
- exit文をreturnに変更（endブロック確実実行）
- COMオブジェクト管理の改善（スクリプトブロック化）
- ログ出力の改善（設定パラメーター出力、処理時間形式統一）
- CanExecuteProcessフラグ導入（earlyExit簡素化）
- 正規表現検証をパラメータレベルに移行

### v1.0.0 (初版)

- 基本的なファイルブロック解除機能実装
- Zone.Identifierストリーム検出と削除
- 再帰的ファイルスキャン
- 拡張子・フォルダパターン除外機能

## ライセンス

このプロジェクトのライセンスについては、リポジトリのLICENSEファイルを参照してください。

## 関連リンク

- [GitHub リポジトリ](https://github.com/UMA68/PowerShell)
- [Wiki](https://github.com/UMA68/PowerShell/wiki)
- [Zone.Identifier について (Microsoft Docs)](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/6e3f7352-d11c-4d76-8c39-2516a9df36e8)

## 作者

UMA68

---

**最終更新日**: 2026年1月19日
