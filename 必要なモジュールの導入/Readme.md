# PowerShellモジュール一括インストールスクリプト

YAMLファイルに定義されたPowerShellモジュールを自動的に一括インストールするスクリプトです。

## 概要

このスクリプトは、YAML設定ファイルに記述されたPowerShellモジュールの情報を読み込み、指定されたバージョンのモジュールが存在しない場合に自動的にインストールします。複数の環境で統一されたモジュール構成を維持するのに便利です。

### 主な機能

- **YAMLベースの設定管理** - モジュール情報をYAMLファイルで一元管理
- **バージョン指定インストール** - 特定バージョンのモジュールをインストール
- **自動存在チェック** - 既存モジュールの有無とバージョンを確認
- **PowerShellバージョン検証** - 実行環境のPowerShellバージョンを確認
- **二重起動防止** - 同時実行を防ぐ安全機構
- **詳細ログ記録** - インストール結果をログファイルに記録

## システム要件

### PowerShell

- **バージョン**: 7.3.9以上（推奨）
- **実行ポリシー**: RemoteSignedまたはUnrestricted

### 前提条件

- インターネット接続（PowerShell Galleryへのアクセス）
- 管理者権限：通常は不要です（ユーザースコープでインストール）
  - グローバルスコープ（AllUsers）でインストールする場合のみ必要

### 自動インストールされる前提モジュール

| モジュール | バージョン | 用途 |
|-----------|-----------|------|
| powershell-yaml | 0.4.7 | YAML設定ファイルの読み込み |

## ディレクトリ構造

```Shell
必要なモジュールの導入/
├── Script/
│   ├── InstMain.ps1              # メインスクリプト
│   ├── Check-EnvModule.ps1        # モジュール存在確認・インストール
│   ├── Check-YamlModule.ps1       # powershell-yaml 確認・インストール
│   └── Log-Output.ps1             # ログ出力関数
├── YAML/
│   └── Env.yaml                   # 設定ファイル（重要）
├── LOG/                           # ログ出力先（自動作成）
│   └── {ホスト名}_yyyyMMdd-HHmmss.log
└── 指定モジュールの導入.ps1 - ショートカット.lnk  # スクリプトの実行用ショートカット
```

## インストール手順

### 前提モジュールの確認

スクリプトは初回実行時に自動的に `powershell-yaml` モジュールをインストールします。手動でインストールする場合：

```powershell
Install-Module -Name powershell-yaml -RequiredVersion 0.4.7 -Force
```

## 使用方法

### 基本的な実行

```powershell
cd "C:\Users\...\必要なモジュールの導入\Script"
.\InstMain.ps1
```

### パラメーター指定

```powershell
# カスタム設定ファイルを使用
.\InstMain.ps1 -envFileName "Production.yaml"
```

#### パラメーター

| パラメーター | 型 | デフォルト | 説明 |
|-----------|----|---------|----|
| `envFileName` | string | "Env.yaml" | 使用する設定ファイル名（YAMLフォルダー内） |

## 設定ファイル (Env.yaml)

### 基本構成

```yaml
Project: InstallModule
Version: 1.0.0               # プロジェクトバージョン

# 実行環境
PowerShell:
 Version: 7.3.9              # 検証済みバージョン（推奨: 7.3.9以上）

# モジュール定義
Module:
 powershell-yaml:            # YAML設定ファイル読み込み用（必須）
  Name: powershell-yaml
  Version: 0.4.7
 SqlServer:                  # SQL Server管理・クエリ実行用
  Name: SqlServer
  Version: 22.1.1             # SQL Server 2022対応版
 ImportExcel:                # Excelファイル読み書き用
  Name: ImportExcel
  Version: 7.8.5              # 最新版に適宜更新してください
```

### 設定項目の詳細

#### PowerShell セクション

- **Version**: 検証済みのPowerShellバージョン（推奨バージョン）
  - 実行時のバージョンと異なる場合、警告ダイアログが表示されます
  - ユーザーは「はい」で続行、「いいえ」で中止を選択できます
  - 異なるバージョンでも、ほとんどの場合正常に動作します

#### Module セクション

各モジュールは以下の形式で定義：

```yaml
 モジュールキー:
  Name: モジュール名          # PowerShell Gallery上の正式名称
  Version: x.x.x            # インストールするバージョン番号
```

#### 例：新しいモジュールを追加

```yaml
 Az:
  Name: Az                  # Azure PowerShellモジュール
  Version: 11.0.0
 Pester:
  Name: Pester              # テストフレームワーク
  Version: 5.5.0
```

## 実行フロー

### 1. 初期化フェーズ

- ディレクトリパスの構築
- 環境変数の取得（ユーザー名、ホスト名）
- 共通スクリプトの読み込み
- ログファイルの初期化

### 2. 前提チェックフェーズ

- `powershell-yaml` モジュールの存在確認・インストール
- YAML設定ファイルの読み込み

### 3. 検証フェーズ

- 二重起動チェック
- PowerShellバージョン検証

### 4. インストールフェーズ

- YAMLで定義された各モジュールについて：
  - 既存モジュールの検索
  - バージョン比較
  - 必要に応じてインストール

### 5. 完了フェーズ

- 処理結果の集計
- ログファイルの保存
- 完了メッセージの表示
- ログファイルを自動で開く

## ログファイル

### ログの場所

```log
必要なモジュールの導入/LOG/{ホスト名}_yyyyMMdd-HHmmss.log
```

**例**: `DESKTOP-ABC123_20251209-143052.log`

### ログの内容

```log
HOST: DESKTOP-ABC123
USER: UMA68
Running PowerShell Version: 7.3.9
============================
InstallModule
Version: 0.0.0
============================
[[[START]]]
[EXIST] powershell-yaml 0.4.7 が既にインストールされています
[NOTHING] SqlServer が見つかりません
[INSTALL] SqlServer 22.1.1 をインストールしています...
[EXIST] ImportExcel 7.8.5 が既にインストールされています
[[[END]]]
-----------------------------

ログの見方
[EXIST] : yaml記述バージョンのモジュールを発見
[OTHER] : yaml記述バージョン以外のモジュールを発見
[NOTHING] : yaml記述モジュールが存在しない
[INSTALL] : yaml記述バージョンのモジュールが存在しないのでインストール
```

### ログレベルの説明

| ログレベル | 説明 | 対応 |
|----------|------|------|
| `[EXIST]` | 指定バージョンのモジュールがすでにインストール済み | 何もしない |
| `[OTHER]` | 異なるバージョンのモジュールが存在 | 指定バージョンを追加インストール |
| `[NOTHING]` | モジュールが存在しない | 新規インストール |
| `[INSTALL]` | モジュールをインストール中 | インストール処理実行 |
| `[ERROR]` | モジュールのインストールに失敗 | ログを確認してトラブルシューティング |

## トラブルシューティング

### エラーメッセージと対応

| エラーメッセージ | 原因 | 対応方法 |
|-------------|------|--------|
| "XXX の読み込みに失敗しました" | 共通スクリプトファイルが見つからない | `Common/` フォルダーと `Script/` フォルダーの構成を確認 |
| "Env.yaml の読み込みに失敗しました" | YAML設定ファイルが存在しない、または形式が不正 | `YAML/` フォルダーに正しい形式の Env.yaml を配置 |
| "すでに実行中です" | 同じスクリプトが実行されている | 既存プロセスの完了を待つか、タスクマネージャーで終了 |
| "PowerShell Gallery に接続できません" | インターネット接続の問題 | ネットワーク接続を確認 |
| "バージョン形式が無効です" | ModuleVersion パラメーターが不正な形式 | バージョンを x.x.x 形式で指定（例: 22.1.1） |
| "モジュール名が指定されていません" | ModuleName パラメーターが空 | モジュール名を正確に指定 |

### よくある問題

#### 1. モジュールがインストールされない

**症状**: スクリプトは正常終了するが、モジュールがインストールされていない

**解決方法**:

```powershell
# 管理者権限でPowerShellを起動
Start-Process pwsh -Verb RunAs

# スクリプトを再実行
.\InstMain.ps1
```

#### 2. PowerShellバージョン警告

**症状**: "実行中のPowerShellはX.X.Xです" という警告が表示される

**解決方法**:

- 「はい」を選択して続行（通常は問題なく動作）
- または、YAML設定ファイルの `PowerShell.Version` を現在のバージョンに更新

```yaml
PowerShell:
 Version: 7.4.0  # 実際のバージョンに変更
```

#### 3. YAML読み込みエラー

**症状**: "Env.yamlの読み込みに失敗しました"

**確認事項**:

- ファイルが `YAML/` フォルダーに存在するか
- ファイル名が正確か（大文字小文字、拡張子）
- YAML形式が正しいか（インデントはスペース、タブ不可）

```powershell
# YAMLファイルの存在確認
Test-Path "YAML\Env.yaml"

# YAMLファイルの内容を表示
Get-Content "YAML\Env.yaml"
```

#### 4. 二重起動エラー

**症状**: "すでに実行中です" のメッセージが表示

**解決方法**:

```powershell
# PowerShellプロセスを確認
Get-Process | Where-Object {$_.ProcessName -like "*pwsh*"}

# 必要に応じて強制終了
Stop-Process -Name pwsh -Force
```

## 高度な使用方法

### 複数環境の管理

開発環境、ステージング環境、本番環境で異なるモジュール構成を管理：

```Shell
YAML/
├── Env.yaml              # 開発環境
├── Staging.yaml          # ステージング環境
└── Production.yaml       # 本番環境
```

**実行例**:

```powershell
# ステージング環境用のモジュールをインストール
.\InstMain.ps1 -envFileName "Staging.yaml"
```

### バージョン管理のベストプラクティス

#### モジュールバージョンの固定

```yaml
Module:
 SqlServer:
  Name: SqlServer
  Version: 22.1.1        # 明示的にバージョン指定
```

#### モジュールの一時的な無効化

```yaml
Module:
 # Az:                   # コメントアウトでスキップ
 #  Name: Az
 #  Version: 11.0.0
```

### 定期実行（Windows タスクスケジューラ）

環境を常に最新の状態に保つため、定期実行を設定：

1. **タスクスケジューラを開く**
   - `taskschd.msc`

2. **基本タスクを作成**
   - 名前: "PowerShellモジュール更新"
   - トリガー: 毎週月曜日　09:00

3. **操作を設定**

   ```text
   プログラム: C:\Windows\System32\pwsh.exe
   引数: -NoProfile -ExecutionPolicy Bypass -File "C:\Users\...\InstMain.ps1"
   開始: C:\Users\...\必要なモジュールの導入\Script
   ```

## セキュリティに関する注意

### インストールスコープ

本スクリプトは **CurrentUser スコープ**（ユーザースコープ）でモジュールをインストールします。

**利点：**

- 管理者権限が不要
- ユーザー固有の環境になる
- 他のユーザーに影響しない

**グローバルスコープでインストールする場合：**

```powershell
# Script/ フォルダー内の Check-EnvModule.ps1 を編集
# -Scope CurrentUser を -Scope AllUsers に変更
Install-Module -Name ModuleName -Scope AllUsers
# この場合は管理者権限が必要です
```

### 管理者権限

通常の使用では管理者権限は不要です。ただし、グローバルスコープでのインストールを希望する場合のみ必要となります。

### 信頼されたリポジトリ

スクリプトはPowerShell Galleryからモジュールをダウンロードします。初回実行時に信頼確認が表示される場合があります：

```PowerShell
NuGet provider is required to continue
PowerShellGet requires NuGet provider version '2.8.5.201' or newer...
```

この場合は「Y」（はい）を選択してNuGetプロバイダーをインストールしてください。

### 二重起動防止

スクリプトには二重起動を防ぐ機構が組み込まれており、同時実行による競合を防ぎます。

## パフォーマンス

### インストール時間

モジュールのサイズと数により異なります：

| モジュール数 | 想定時間 |
|------------|---------|
| 1-3 | 1-2分 |
| 4-10 | 3-5分 |
| 10以上 | 5-10分 |

### ネットワーク帯域

PowerShell Galleryからのダウンロード速度に依存します。大規模モジュール（Azなど）は数百MBのダウンロードが発生する場合があります。

## 関連スクリプト

| スクリプト | 場所 | 用途 |
|-----------|------|------|
| Check-EnvModule.ps1 | Script/ | YAML定義の各モジュールについて存在確認・インストール実行 |
| Check-YamlModule.ps1 | Script/ | YAML読み込み必須の powershell-yaml モジュール確認・インストール |
| Log-Output.ps1 | Script/ | コンソールとログファイルへの同時出力関数 |
| NoDoubleActivation.ps1 | Common/ | 同時起動防止機構 |
| Write-CommonLog.ps1 | Common/ | 共通ログ記録機能（Check-EnvModule で使用） |

## 実行例

### シンプルな実行

```powershell
PS C:\Users\...\Script> .\InstMain.ps1
# 警告ダイアログ: PowerShellバージョン確認
# → 「はい」を選択
# 処理実行...
# 完了ダイアログ: "処理を終了しました。ログを表示します"
# → ログファイルが自動で開く
```

### ログ出力例

```log
HOST: MYCOMPUTER
USER: UMA68
Running PowerShell Version: 7.3.9
============================
InstallModule
Version: 1.0.0
============================
[[[START]]]
[EXIST] powershell-yaml Version: 0.4.7
[NOTHING] SqlServer
[INSTALL] SqlServer Version: 22.1.1 をインストール中...
[INSTALL] SqlServer Version: 22.1.1 をインストールしました
[OTHER] ImportExcel Version: 7.8.0
[INSTALL] ImportExcel Version: 7.8.5 をインストール中...
[INSTALL] ImportExcel Version: 7.8.5 をインストールしました
[[[END]]]
-----------------------------
```

## よくある質問（FAQ）

### Q1: 既存のモジュールは削除されますか？

**A**: いいえ。スクリプトは指定バージョンが存在しない場合のみインストールします。異なるバージョンが存在する場合は、並行してインストールされます。

### Q2: グローバルスコープとユーザースコープのどちらにインストールされますか？

**A**: デフォルトではユーザースコープ（CurrentUser）にインストールされます。管理者権限で実行した場合はグローバルスコープ（AllUsers）になる可能性があります。

### Q3: オフライン環境で使用できますか？

**A**: いいえ。このスクリプトはPowerShell Galleryへのインターネット接続が必要です。オフライン環境では、事前にモジュールをダウンロードして手動インストールが必要です。

### Q4: モジュールを削除するにはどうすればよいですか？

**A**: このスクリプトは削除機能を持ちません。手動で削除してください：

```powershell
Uninstall-Module -Name SqlServer -RequiredVersion 22.1.1
```

## ライセンス

MIT License

## サポート

問題が発生した場合：

1. ログファイルで詳細エラーを確認
2. トラブルシューティングセクションを参照
3. PowerShellバージョンと実行ポリシーを確認
4. 管理者権限での実行を試みる

## バージョン履歴

### v1.0.0 (2025-12-09)

- 初版リリース
- PowerShell 7.3.9対応
- YAMLベースの設定管理
- 自動バージョンチェック機能
- 詳細ログ記録機能
- 二重起動防止機能
- ユーザースコープでのインストール対応
- 包括的なエラーハンドリング

---

**最終更新:** 2025年12月9日
