# ILSpyCmd 自動インストールスクリプト

## 概要

このスクリプトは、ILSpyCmd (.NET逆コンパイルツール）とその前提条件である .NET SDKを自動的にインストールします。

**ファイル:** `getILSpyCmd.ps1`  
**バージョン:** v1.3.0 (改善版）

## 主な機能

- ✅ ILSpyCmdのインストール状態確認とバージョン比較
- ✅ 管理者権限の確認と要求
- ✅ ネットワーク接続の検証（NuGet.org）
- ✅ .NET SDKの存在確認と自動インストール
- ✅ インストーラーファイルの検証（サイズ、読み取り可能性）
- ✅ インストールタイムアウト処理（10分）
- ✅ インストール失敗時のロールバック機能
- ✅ YAMLファイルからの設定読み込みと検証
- ✅ 詳細なログ出力（INFO、WARN、ERROR、DEBUG）
- ✅ ユーザーへの対話的な確認

## 新機能 (v1.3.0)

### 1. **-NoKeyWait パラメーター（非対話モード）**

- スケジューラーや自動化環境での使用を想定
- すべてのポップアップダイアログを抑止
- ログファイルを自動で開かない

   **使用方法:**

   ```powershell
   .\getILSpyCmd.ps1 -NoKeyWait
   ```

### 2. **改善されたエラーハンドリング**

- すべての `exit N` 呼び出しを削除
- `$script:CanExecuteProcess` フラグによる統一管理
- `$script:ExitCode` で終了コードを保持
- endブロックで確実なクリーンアップを実行
- 例外タイプのログ出力を追加

### 3. **非対話実行時の動作**

- ポップアップを表示しない
- ログファイルを自動で開かない
- エラー情報はログファイルのみに記録

## 使用方法

### 基本的な実行

```powershell
.\getILSpyCmd.ps1
```

### カスタム YAML ファイルを使用

```powershell
.\getILSpyCmd.ps1 -EnvYaml "custom.yaml"
```

### 非対話モード（スケジューラー向け）

```powershell
.\getILSpyCmd.ps1 -NoKeyWait
```

### 管理者として実行（SDK インストール時に必須）

```powershell
Start-Process -FilePath powershell -ArgumentList "-NoExit", "-File", ".\getILSpyCmd.ps1" -Verb RunAs
```

## 終了コード

| コード | 説明 |
|--------|------|
| 0 | 正常終了 |
| 1 | 一般エラー（ファイル未検出、スクリプトエラーなど） |
| 2 | YAML検証エラー（必須フィールド不足） |
| 3 | 権限不足（管理者権限が必要） |
| 4 | ネットワークエラー（NuGet.orgに接続不可） |
| 5 | インストーラー検証エラー（ファイル破損の可能性） |
| 6 | タイムアウトエラー（インストールが10分を超過） |

## 設定ファイル (YAML)

`YAML/getILSpyCmd.yaml` で以下のフィールドを設定します。

### 必須フィールド

```yaml
Project: "ILSpyCmd Installation"
Version: "1.3.0"
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
  ExpectedVersion: "2.0.0"  # バージョン確認用
```

### モジュール設定

```yaml
Module:
  Powershell-Yaml:
    Version: "0.4.5"  # 特定バージョンを強制（省略可能）
```

## 前提条件

- **PowerShell:** 7.x以上
- **powershell-yaml モジュール:** インストール済み
- **Write-CommonLog.ps1:** Commonフォルダーに存在
- **getILSpyCmd.yaml:** YAMLフォルダーに存在
- **.NET SDK インストーラー:** 指定フォルダーに存在
- **インターネット接続:** NuGet.orgへのアクセス確認用
- **管理者権限:** .NET SDKインストール時に必須（SDK未インストール時のみ）

## ログ出力

ログファイルは `LOG` フォルダーに以下の形式で保存されます：

```Terminal
ILSpyCmd_yyyyMMdd-HHmmss-mmm.log
```

### ログレベル

- **INFO:** 標準情報
- **WARN:** 警告（処理は継続）
- **ERROR:** エラー（処理が中断）
- **DEBUG:** デバッグ情報（YAMLフィールド検証時など）

## トラブルシューティング

### エラー: "SDKインストーラーが見つかりません"

→ `YAML` フォルダーに `getILSpyCmd.yaml` が存在し、`DotnetSdk.SdkFolder` と `DotnetSdk.Installer` が正しく設定されているか確認してください。

### エラー: "管理者権限が必要です"

→ PowerShellを右クリック → "管理者として実行" を選択し、再度実行してください。

### エラー: "ネットワークエラー"

→ インターネット接続を確認し、NuGet.orgに接続できるか確認してください。

### エラー: "タイムアウトエラー"

→ インストーラーが正常に動作していない可能性があります。ファイルが破損していないか確認し、再度実行してください。

## 改善履歴

### v1.3.0 (現在)

- **-NoKeyWait パラメーターを追加** - スケジューラー/自動化環境での非対話実行に対応
- **exit 文をすべて削除** - `$script:CanExecuteProcess` フラグで統一管理
- **end ブロック保証** - エラー時にも確実にクリーンアップを実行
- **例外タイプのログ出力を追加** - デバッグ情報の充実化
- **ポップアップの条件付け実行** - `-NoKeyWait` 時に表示しない

### v1.2.0

- ネットワーク接続確認機能を追加
- インストーラーファイル検証を強化
- ロールバック機能を実装

### v1.1.0

- YAML設定ファイル対応
- ログ出力機能を強化

### v1.0.0

- 初版リリース

## 開発者向け情報

### スクリプト構造

```PowerShell
param {}              # パラメータ定義（-EnvYaml, -NoKeyWait）
begin {}              # 初期化（YAML読み込み、フラグ設定）
process {}            # メイン処理（SDK/ILSpyCmd インストール）
end {}                # クリーンアップ（COM解放、ログ表示）
```

### 重要な変数

- `$script:CanExecuteProcess` - プロセス実行フラグ（false=エラー状態）
- `$script:ExitCode` - スクリプト終了コード
- `$script:Log` - ログファイルパス
- `$script:comObject` - WScript.Shell COM オブジェクト

### エラーハンドリングパターン

```powershell
try {
    # 処理
} catch {
    Write-Error "Error: $($_)"
    Write-Error "Exception Type: $($_.Exception.GetType().FullName)"
    if (-not $NoKeyWait) { Show-Popup(...) }
    $script:CanExecuteProcess = $false
    $script:ExitCode = <code>
    return
}
```

## ライセンス

このスクリプトはGitHubリポジトリの一部として提供されます。

---

**最終更新:** 2025-01-15 (v1.3.0)  
**作成者:** UMA
