# ILSpyCmd 自動インストールスクリプト

## 概要

このスクリプトは、ILSpyCmd (.NET逆コンパイルツール）とその前提条件である .NET SDKを自動的にインストールします。

- ファイル: `getILSpyCmd.ps1`
- バージョン: v1.4.0

## 主な機能

- ✅ ILSpyCmdのインストール状態確認とバージョン比較（期待値チェックに対応）
- ✅ 管理者権限の確認と要求（SDK未導入時のみ必須）
- ✅ ネットワーク接続の検証（NuGet.orgへICMP/HTTPで確認）
- ✅ .NET SDKの存在確認と自動インストール（タイムアウト10分・ロールバック案内）
- ✅ インストーラー検証（サイズ/読み取り可能性）
- ✅ YAMLからの設定読み込みと検証（相対/絶対パス、ファイル名のみ対応）
- ✅ 詳細ログ（INFO/WARN/ERROR/DEBUG、タイムスタンプ+ミリ秒）
- ✅ 例外タイプに基づくログレベル自動分類（v1.4.0）
- ✅ 非対話モード `-NoKeyWait`（ポップアップ抑止・ログ自動オープンなし）

## 新機能（v1.4.0）

- **EnvYaml の柔軟な解決**: ファイル名のみは `YAML/` 配下、相対パスはスクリプト位置基準、絶対パスはそのまま使用
- **例外分類ログ**: 代表的な例外型（UnauthorizedAccessException/TimeoutException他）に応じて自動的にログレベルを振り分け
- **必須フィールド検証の強化**: どのキーが不足しているかを詳細表示（DEBUGで候補キーも記録）

## 使い方

- 基本実行: `./getILSpyCmd.ps1`
- YAML指定（ファイル名のみ）: `./getILSpyCmd.ps1 -EnvYaml "custom.yaml"`
- YAML指定（相対）: `./getILSpyCmd.ps1 -EnvYaml "../Config/prod.yaml"`
- YAML指定（絶対）: `./getILSpyCmd.ps1 -EnvYaml "C:\\Config\\getILSpyCmd.yaml"`
- 非対話モード: `./getILSpyCmd.ps1 -NoKeyWait`
- 管理者として実行（SDK導入が必要な場合）:
  `Start-Process -FilePath pwsh -ArgumentList "-NoExit","-File",".\getILSpyCmd.ps1" -Verb RunAs`

注意:

- `-NoKeyWait` 指定時に .NET SDKが未導入の場合、インストール確認のポップアップは表示されず「はい」として自動承認しインストールを実行します。対話で可否を決めたい場合は `-NoKeyWait` を付けずに実行してください。

## 検証スクリプト（推奨）

インストール前後の実装整合性を自動検証できます。

- スクリプト: `ILSpyCmdの入手/Script/Verify_v1.4.0.ps1`
- 検証項目: v1.3.0（9項目）+ v1.4.0（11項目）= 合計20項目
- 実行例（PowerShell 7）:

```pwsh
pwsh -NoProfile -File "ILSpyCmdの入手/Script/Verify_v1.4.0.ps1"
```

- 期待結果（成功時）:
  - `【v1.3.0 検証】 9 / 9 合格`
  - `【v1.4.0 検証】 11 / 11 合格`
  - `総合結果: 20 / 20 合格`

## 終了コード

| コード | 説明 |
|------|------|
| 0 | 正常終了 |
| 1 | 一般エラー（ファイル未検出、処理例外など） |
| 2 | YAML検証エラー（必須フィールド不足） |
| 3 | 権限不足（管理者権限が必要） |
| 4 | ネットワークエラー（NuGet.orgに接続不可） |
| 5 | インストーラー検証エラー（破損等） |
| 6 | タイムアウトエラー（インストールが10分超過） |

## 設定ファイル（YAML）

`YAML/getILSpyCmd.yaml`（または任意のパス）で以下を設定します。

### 必須フィールド

```yaml
Project: "ILSpyCmd Installation"
Version: "1.4.0"
LOG:
  FILENAME: "ILSpyCmd"
  EXTENSION: ".log"
DotnetSdk:
  SdkFolder: "DotnetSDK"
  Installer: "dotnet-sdk-8.0.411-win-x64.exe"
  Version: "8.0.411"
```

### オプションフィールド

```yaml
ILSpyCmd:
  ExpectedVersion: "9.1.0.7988"  # バージョン確認用
```

### モジュール設定（任意）

```yaml
Module:
  Powershell-Yaml:
    Version: "0.4.7"  # 特定バージョンを強制する場合
```

## 前提条件

- PowerShell 7.x以上（7.3+ 推奨）
- `powershell-yaml` モジュールが使用可能
- `Common/Write-CommonLog.ps1` が存在
- YAMLファイル（既定は `YAML/getILSpyCmd.yaml`）が存在
- .NET SDKインストーラーが指定フォルダーに存在
- インターネット接続（NuGet.org到達性）
- 管理者権限（SDK未導入時に必要）

## ログ出力

- 保存先: `LOG/` フォルダー
- 形式: `ILSpyCmd_yyyyMMdd-HHmmss-mmm.log`
- レベル: INFO / WARN / ERROR / DEBUG（例外型に応じ自動分類）

## トラブルシューティング

- **SDKインストーラーが見つからない**: `DotnetSdk.SdkFolder` と `DotnetSdk.Installer` の設定・配置を確認
- **管理者権限が必要**: `pwsh` を「管理者として実行」で起動して再実行
- **ネットワークエラー**: プロキシ/ファイアウォール含めて `nuget.org` 到達性を確認
- **タイムアウト**: インストーラーの応答有無とサイズ整合性（破損の可能性）を確認

## 安全な検証（非破壊）

インストールを実行せずに動作確認するためのレシピです。必要に応じてテスト用のYAMLを作成し、`-EnvYaml` で指定してください。

- 提供サンプル
  - テストYAML: `YAML/getILSpyCmd.test.yaml`
  - 非対話・早期終了の確認（インストーラー未検出でExit 1）:

    ```pwsh
    pwsh -NoProfile -File "ILSpyCmdの入手/Script/getILSpyCmd.ps1" -EnvYaml "getILSpyCmd.test.yaml" -NoKeyWait
    ```

  - 実導入を試す場合は、同ファイル内 `DotnetSdk.Installer` を実在のファイル名に変更してから対話実行:

    ```pwsh
    pwsh -NoProfile -File "ILSpyCmdの入手/Script/getILSpyCmd.ps1" -EnvYaml "getILSpyCmd.test.yaml"
    ```

- 準備: テスト用YAMLを作成
  - 例: `YAML/getILSpyCmd.test.yaml`
  - 実行: `./getILSpyCmd.ps1 -EnvYaml "getILSpyCmd.test.yaml"`

- YAML検証エラー（Exit 2）を確認
  - テスト: テストYAMLで必須キー（例: `DotnetSdk.Installer`）を一時的に削除
  - 期待: 必須キー不足として終了コード2、ログに不足キー一覧

- インストーラー未検出（Exit 1）で早期終了
  - テスト: `DotnetSdk.Installer` を存在しないファイル名に設定（例: `missing.exe`）
  - 期待: 早期に終了コード1。インストール処理は開始されません
  - 補足: `-NoKeyWait` 指定時はSDK導入確認が自動承認されますが、インストーラー未検出で即終了します

- ネットワークエラー（Exit 4）で早期終了
  - テスト: 一時的にオフライン環境で実行、または `nuget.org` への到達不可状況で実行
  - 期待: ネットワーク到達性の確認で終了コード4、インストール処理は開始されません

- 既存インストール検出（Exit 0）
  - テスト: すでにILSpyCmdが導入されている環境で実行
  - 期待: 早期に正常終了（Exit 0）。`ILSpyCmd ExpectedVersion` を異なる値にすれば「バージョン不一致」のWARNをログで確認可能

- ログの確認
  - 出力先: `LOG/ILSpyCmd_yyyyMMdd-HHmmss-mmm.log`
  - 重要: 例外型に応じたログレベル（INFO/WARN/ERROR/DEBUG）が付与されます

## 開発者向けメモ

- スクリプト構造: `param` → `begin`（初期化・YAML読取）→ `process`（SDK/ILSpyCmdインストール）→ `end`（クリーンアップ・ログ表示）
- 終了コード管理: 途中では `return`、最終的に `end` で一括 `exit $script:ExitCode`
- 例外分類: `Get-ExceptionLogLevel` で代表的な例外型を判定しログレベルに反映
- 重要変数: `$script:CanExecuteProcess`, `$script:ExitCode`, `$script:Log`, `$script:comObject`

## 変更履歴

- v1.4.0（2026-01-19）: 例外分類ログ、EnvYamlの相対/絶対/ファイル名のみ解決、必須キー検証の強化
- v1.3.0（2025-01-15）: `-NoKeyWait` 追加、終了処理の一元化、対話抑止時の動作整理
- v1.2.0: ネットワーク確認とインストーラー検証、ロールバック案内
- v1.1.0: YAML設定対応、ログ機能強化
- v1.0.0: 初版

---

最終更新: 2026-01-19（v1.4.0）  
作成者: UMA
