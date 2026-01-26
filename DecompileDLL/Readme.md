# DecompileDLL - DLL逆コンパイル差分比較ツール

## 概要

新旧のDLLファイルを自動的に逆コンパイルし、差分を視覚的に比較するPowerShellスクリプトです。ILSpyCmdとWinMerge（またはVS Code）を使用して、.NET DLLの変更内容を効率的に確認できます。Windows 10/11のみ対応です（ビルド番号で判定）。

## 主な機能

### 🚀 基本機能

- **一括逆コンパイル**: 複数のDLLファイルを自動的に処理
- **差分比較**: WinMerge/VS Codeで視覚的に差分を表示
- **進捗表示**: リアルタイムの進捗状況とETA表示
- **詳細ログ**: 処理内容を自動的にログファイルに記録

### ⚡ 高度な機能

- **並列処理**: 複数DLLを同時に処理して高速化（`-Parallel`）
- **リトライロジック**: 失敗時の自動リトライ（最大3回）
- **タイムアウト制御**: 大容量DLLにも対応（デフォルト300秒）
- **完全な非対話実行対応**: スケジューラー・CI/CD統合（`-NoKeyWait`）
- **YAML設定**: 柔軟なカスタマイズが可能

### 📊 レポート機能

- 処理統計の表示（成功/失敗/スキップ数）
- エラー詳細レポート（試行回数付き）
- スキップ理由の詳細表示

## 前提条件

### 必須ソフトウェア

- **Windows 10/11**: OSバージョンをビルド番号で判定
- **PowerShell 7.x** 以降
- **ILSpyCmd**: .NET逆コンパイルツール
- **WinMerge** または **VS Code**: 差分比較ツール
- **powershell-yaml**: PowerShell YAMLモジュール

### インストール手順

#### 1. PowerShell 7.xのインストール

```powershell
winget install Microsoft.PowerShell
```

#### 2. ILSpyCmdのインストール

```powershell
# 付属のインストールスクリプトを使用
.\ILSpyCmdの入手\ILSpyCmdインストール.ps1

# または手動インストール
dotnet tool install ilspycmd -g
```

#### 3. powershell-yamlモジュールのインストール

```powershell
Install-Module powershell-yaml -Scope CurrentUser
```

#### 4. WinMergeのインストール

- Windows 11: Microsoft Storeからインストール
- Windows 10: [公式サイト](https://winmerge.org/)からダウンロード

## ディレクトリ構造

```Shell
DecompileDLL/
├── README.md                   # このファイル
├── Script/
│   └── DecompileDll.ps1       # メインスクリプト
├── YAML/
│   └── Decompile.yaml         # 設定ファイル（InstWinMerge必須）
├── Dlls/
│   ├── Old/                   # 旧バージョンDLL配置先
│   ├── New/                   # 新バージョンDLL配置先
│   └── Decompiled/            # 逆コンパイル結果出力先
│       ├── old/
│       └── new/
└── Log/                       # ログファイル保存先
```

## 使い方

### 基本的な使用方法

#### 1. DLLファイルの配置

```Shell
Dlls/Old/    # 旧バージョンのDLLファイルを配置
Dlls/New/    # 新バージョンのDLLファイルを配置
```

#### 2. スクリプトの実行

```powershell
# 基本実行
.\Script\DecompileDll.ps1

# 詳細ログ付き実行
.\Script\DecompileDll.ps1 -Verbose

# 出力フォルダーをクリアして実行
.\Script\DecompileDll.ps1 -CleanOutput

# 確認なしで実行
.\Script\DecompileDll.ps1 -CleanOutput -Force
```

### 並列処理モード

複数のDLLを高速に処理したい場合は並列処理を使用します。

```powershell
# デフォルト（4スレッド）で並列処理
.\Script\DecompileDll.ps1 -Parallel

# スレッド数を指定して並列処理
.\Script\DecompileDll.ps1 -Parallel -ThrottleLimit 8

# 並列処理 + クリーンアップ
.\Script\DecompileDll.ps1 -Parallel -CleanOutput -Force
```

**注意**: 並列処理モードでは、処理完了後に差分ツールは自動起動しません。手動で比較してください。

### 差分比較ツールの選択

```powershell
# WinMerge（デフォルト）
.\Script\DecompileDll.ps1

# VSCodeで比較
.\Script\DecompileDll.ps1 -DiffTool VSCode

# 手動で比較（パスのみ表示）
.\Script\DecompileDll.ps1 -DiffTool Custom
```

### スケジューラー実行・自動化

タスクスケジューラーやCI/CDパイプラインから実行する場合は、`-NoKeyWait`を使用します。

```powershell
# スケジューラー実行用（完全に非対話）
.\Script\DecompileDll.ps1 -NoKeyWait -Force

# 並列処理 + 非対話実行
.\Script\DecompileDll.ps1 -Parallel -NoKeyWait -Force

# カスタム設定 + 非対話実行
.\Script\DecompileDll.ps1 -EnvYaml "CustomConfig.yaml" -NoKeyWait -Force
```

**注意**: `-NoKeyWait`を使用すると、処理完了後にキー入力待ちをスキップします。差分ツールも自動起動されないため、手動で比較してください。

### その他のオプション

```powershell
# 設定内容の確認
.\Script\DecompileDll.ps1 -ShowConfig

# WhatIfモード（実行せずに確認）
.\Script\DecompileDll.ps1 -WhatIf

# カスタム設定ファイルの使用
.\Script\DecompileDll.ps1 -EnvYaml "CustomConfig.yaml"
```

## YAML設定ファイル

`YAML/Decompile.yaml`で動作をカスタマイズできます。

### 主な設定項目

```yaml
# OS判定とWinMergeパス（必須）
OSDetection:
 Win11MinBuild: 22000  # Windows 11 最小ビルド
 Win10MinBuild: 10240  # Windows 10 最小ビルド

InstWinMerge:
 Win10: "C:\\Program Files\\WinMerge\\WinMergeU.exe"
 Win11: "$HOME\\AppData\\Local\\Programs\\WinMerge\\WinMergeU.exe"

# フォルダー名設定
Folders:
 Old: old              # 旧DLL出力フォルダー名
 New: new              # 新DLL出力フォルダー名

# リトライ設定
Retry:
 MaxAttempts: 3        # 最大リトライ回数
 DelaySeconds: 2       # リトライ間隔（秒）
 TimeoutSeconds: 300   # タイムアウト時間（秒）

# 終了コード
ExitCodes:
 Success: 0            # 正常終了
 GeneralError: 1       # 一般エラー（YAML読込失敗など）
 OSNotSupported: 3     # OS非対応（Windows 10/11以外）
 FileNotFound: 4       # ファイル/フォルダーが見つからない
 DecompileFailed: 5    # 逆コンパイル失敗

# 表示色設定
Colors:
 Info: Cyan
 Success: Green
 Warning: Yellow
 Error: Red

# WinMergeパス（OS別）
InstWinMerge:
 Win10: "C:\Program Files\WinMerge\WinMergeU.exe"
 Win11: "$HOME\AppData\Local\Programs\WinMerge\WinMergeU.exe"
```

### タイムアウト時間の調整

大容量のDLLを処理する場合は、タイムアウト時間を延長します。

```yaml
Retry:
 TimeoutSeconds: 600   # 10分に延長
```

### リトライ回数の変更

```yaml
Retry:
 MaxAttempts: 5        # 5回までリトライ
 DelaySeconds: 3       # 3秒間隔
```

## パフォーマンス

### 処理速度の目安

| DLL数 | 順次処理 | 並列処理（4スレッド） | 並列処理（8スレッド） |
|-------|---------|---------------------|---------------------|
| 1個   | 10秒    | 10秒                | 10秒                |
| 4個   | 40秒    | 12秒                | 12秒                |
| 8個   | 80秒    | 25秒                | 15秒                |
| 16個  | 160秒   | 50秒                | 30秒                |

※ DLLサイズや内容により変動します

### 推奨設定

- **小規模（1-3個）**: 順次処理（デフォルト）
- **中規模（4-10個）**: 並列処理4スレッド
- **大規模（11個以上）**: 並列処理8スレッド

```powershell
# 推奨: 中規模プロジェクト
.\Script\DecompileDll.ps1 -Parallel -ThrottleLimit 4

# 推奨: 大規模プロジェクト
.\Script\DecompileDll.ps1 -Parallel -ThrottleLimit 8
```

## トラブルシューティング

### よくある問題と解決方法

#### 0. GUIダイアログが出る環境

`Show-ErrorPopup` によりWScriptのダイアログが表示されます。サーバーやヘッドレス環境では対話ができないため失敗することがあります。必要に応じてコンソール環境で実行するか、スクリプトを対話不要な形に調整してください。

#### 1. ILSpyCmdが見つからない

```Shell
エラー: 「ILSpyCmd.exe」が存在しません
```

**解決方法**:

```powershell
# ILSpyCmdをインストール
dotnet tool install ilspycmd -g

# または付属のスクリプトを実行
.\ILSpyCmdの入手\ILSpyCmdインストール.ps1
```

#### 2. WinMergeが見つからない

```Shell
エラー: WinMergeが見つかりませんでした
```

**解決方法**:

- `YAML/Decompile.yaml`のWinMergeパスを確認
- 実際のインストールパスに合わせて修正

#### 3. タイムアウトエラー

```Shell
WARNING: [LargeDLL.dll] Old タイムアウト (300秒)
```

**解決方法**:
`YAML/Decompile.yaml`のタイムアウト時間を延長

```yaml
Retry:
 TimeoutSeconds: 600  # 10分に延長
```

#### 4. 並列処理でエラーが多発

```Shell
WARNING: 複数のDLLで逆コンパイル失敗
```

**解決方法**:

- スレッド数を減らす: `-ThrottleLimit 2`
- または順次処理に切り替える（`-Parallel`を外す）

#### 5. 対応するDLLが見つからない

```Shell
WARNING: 'OldDLL.dll' をスキップ: 対応する新しいDLLが見つかりません
```

**解決方法**:

- `Dlls/New/`フォルダーに対応するDLLが存在するか確認
- ファイル名が一致しているか確認（完全一致でない場合は最新のものが自動選択されます）

#### 6. ショートカットから実行時の動作

ショートカット（`.lnk`ファイル）から実行した場合、スクリプトは処理完了後に自動的にキー入力待ちになります。これにより、実行結果やエラーメッセージを確認してからウィンドウを閉じることができます。

**動作の詳細**:

- ショートカットから実行: キー入力待ち（結果を確認可能）
- PowerShellコンソールから実行: 自動終了（待機なし）

この動作は自動的に判定されるため、特別な操作は不要です。

#### 7. 出力フォルダーを削除したい

`-CleanOutput` 単体では確認付きで削除します。バッチ等で無確認削除したい場合は `-CleanOutput -Force` を併用してください。

## ログファイル

### ログの場所

```Shell
Log/DecompileDll_YYYYMMDD-HHMMSS.log
```

### ログの内容

- 処理開始/終了時刻
- 各DLLの処理状況
- エラー詳細（試行回数付き）
- スキップ理由
- 処理統計

### ログの例

```log
[2026-01-26 16:36:34] [INFO] ────────────────────────────────────────
[2026-01-26 16:36:34] [INFO] DLL逆コンパイルスクリプトを開始
[2026-01-26 16:36:34] [INFO] YAML設定を読み込みました: Decompile.yaml
[2026-01-26 16:36:35] [INFO] 逆コンパイル開始: 3 個のDLLファイル (順次処理)
[2026-01-26 16:36:40] [INFO] [HelloWorld.dll] 逆コンパイル成功 (Old: 1回, New: 1回)
[2026-01-26 16:36:45] [WARN] [TestLib.dll] Old 失敗 (試行: 1/3) - 2秒後にリトライ
[2026-01-26 16:36:48] [INFO] [TestLib.dll] 逆コンパイル成功 (Old: 2回, New: 1回)
[2026-01-26 16:36:50] [WARN] [OldLib.dll] スキップ: 対応する新しいDLLが見つかりません
[2026-01-26 16:36:50] [INFO] 処理時間: 00:00:15
[2026-01-26 16:36:50] [INFO] DLL逆コンパイルスクリプトを正常終了
```

## 終了コード

スクリプトは以下の終了コードを返します。

| コード | 意味 | 説明 |
|-------|------|------|
| 0 | Success | 正常終了 |
| 1 | GeneralError | 一般エラー |
| 3 | OSNotSupported | OS非対応 |
| 4 | FileNotFound | ファイル/フォルダーが見つからない |
| 5 | DecompileFailed | 逆コンパイル失敗 |

### 終了コードの確認

```powershell
.\Script\DecompileDll.ps1
echo $LASTEXITCODE
```

## 高度な使用例

### バッチ処理

```powershell
# 複数の設定で連続実行
$configs = @("Config1.yaml", "Config2.yaml", "Config3.yaml")
foreach ($config in $configs) {
    Write-Host "処理中: $config" -ForegroundColor Cyan
    .\Script\DecompileDll.ps1 -EnvYaml $config -CleanOutput -Force
}
```

### カスタムログ処理

```powershell
# ログファイルを即座に確認
.\Script\DecompileDll.ps1 -Verbose *>&1 | Tee-Object -FilePath "custom.log"
```

### CI/CD統合

```powershell
# 自動テスト用（検証のみ）
.\Script\DecompileDll.ps1 -WhatIf -Verbose
if ($LASTEXITCODE -eq 0) {
    Write-Host "検証成功" -ForegroundColor Green
} else {
    Write-Host "検証失敗: $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# CI/CDパイプラインでの実行
.\Script\DecompileDll.ps1 -Parallel -NoKeyWait -Force -Verbose
if ($LASTEXITCODE -ne 0) {
    Write-Host "逆コンパイル失敗: 終了コード $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "逆コンパイル成功" -ForegroundColor Green
```

## パラメータリファレンス

| パラメーター | 型 | デフォルト | 説明 |
|-----------|---|-----------|------|
| `-EnvYaml` | string | "Decompile.yaml" | 使用するYAML設定ファイル名 |
| `-CleanOutput` | switch | - | 出力フォルダーを事前にクリア |
| `-ShowConfig` | switch | - | 設定内容を表示して終了 |
| `-DiffTool` | string | "WinMerge" | 使用する差分ツール（WinMerge/VS Code/Custom） |
| `-Parallel` | switch | - | 並列処理モードを有効化 |
| `-ThrottleLimit` | int | 4 | 並列処理の最大スレッド数（1-10） |
| `-Force` | switch | - | 確認プロンプトをスキップ |
| `-NoKeyWait` | switch | - | キー入力待機をスキップ（スケジューラー・CI/CD用） |
| `-WhatIf` | switch | - | 実行せずに動作を確認 |
| `-Verbose` | switch | - | 詳細ログを表示 |

## バージョン履歴

### v2.1.0 (2026-01-26)

- 🔄 **Write-CommonLogへの完全移行**: ローカルのWrite-Log関数を削除し、Commonフォルダーの標準化されたWrite-CommonLogを使用
- 🛡️ **並列処理のログ安定化**: Write-CommonLogのファイルロック時リトライ機能により、並列処理時のログ競合を解決
- 📝 **ログレベル統一**: SUCCESS → INFO、WARNING → WARNに統一し、Write-CommonLogの標準レベルに準拠
- ✅ **スレッドセーフ性向上**: ミューテックス管理がWrite-CommonLogに一元化され、実装がシンプルに

### v2.1.0-earlier (2026-01-15)

- 🤖 完全な非対話実行対応（`-NoKeyWait`パラメーター追加）
- 🛠️ ShowConfig機能の実装（設定内容表示）
- 🔧 COMオブジェクト管理の改善（`Show-ErrorPopup`の安全性向上）
- 📝 変数スコープの統一（`$script:timestamp`への一元化）
- 🎯 終了コード参照の統一（すべて`$script:`プレフィックス付き）
- ✅ PSScriptAnalyzer完全準拠（0違反達成）
- 📖 ヘルプドキュメントの全面更新

### v2.0.0 (2025-12-03)

- 🚀 並列処理機能の追加
- 🔄 リトライロジックとタイムアウト制御の実装
- 📊 ETA付き進捗表示
- 📝 詳細なスキップ理由の記録
- ⚡ コード品質の改善（定数化、関数分離）
- 📖 包括的なREADME作成

### v1.0.0 (初期リリース)

- 基本的な逆コンパイル機能
- WinMerge統合
- YAML設定対応

## ライセンス

このプロジェクトに含まれるスクリプト類（`Script/`配下、`YAML/`配下、`Readme.md`等）は、本リポジトリ直下の`LICENSE`に従います。

注意事項:

- 本ツールは外部ソフトウェア（ILSpyCmd、WinMerge、VS Code）を呼び出して動作します。これらのソフトウェアはそれぞれのライセンスにしたがってご利用ください。
  - ILSpyCmd: MIT License（ICSharpCode/ILSpyに準拠）
  - WinMerge: GPLライセンス系（WinMergeの配布条件に準拠）
  - VS Code: Microsoftの使用許諾に準拠
- 逆コンパイルで生成されるソースコードやアーティファクト（`Dlls/Decompiled/`配下）は、元のDLLの著作権・ライセンスに従います。分析・比較目的の利用に留め、第三者への配布や公開、ライセンス違反となる利用は避けてください。
- 逆コンパイル物のリポジトリへのコミットは、権利上の問題が生じる可能性があります。公開範囲や契約条件を確認のうえ、必要に応じてコミット対象から除外してください（例: `.gitignore`で`Dlls/Decompiled/`を除外）。

## サポート

問題が発生した場合は、以下を確認してください：

1. ログファイル（`Log/`フォルダー）
2. エラーレポート（`Log/DecompileErrors_*.txt`）
3. YAML設定ファイル（`YAML/Decompile.yaml`）

## 関連リンク

- [ILSpy公式サイト](https://github.com/icsharpcode/ILSpy)
- [WinMerge公式サイト](https://winmerge.org/)
- [PowerShell 7ドキュメント](https://docs.microsoft.com/powershell/)
