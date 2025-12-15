# getILSpyCmd.ps1 v1.2.0 → v1.3.0 改善内容

## 概要

PowerShellスクリプト `getILSpyCmd.ps1` を、スケジューラー・自動化環境対応および安全なエラーハンドリングの観点から改善しました。

**改善日:** 2025-01-15  
**改善者:** Copilot

---

## 実装した改善内容

### 改善 #1: Exit 文の完全排除 + CanExecuteProcess フラグ管理 + End ブロック保証

**目的:** スクリプト実行時に常にクリーンアップ処理を確実に実行するため、`exit` 文を廃止し、フラグベースの制御に移行

**変更内容:**

#### 1-1. グローバルフラグの初期化

```powershell
begin {
    $script:CanExecuteProcess = $true
    $script:ExitCode = 0
    # ... 他の初期化処理
}
```

#### 1-2. Exit 文の置換パターン（全エラーパス対応）

**置換前:**

```powershell
try {
    # 処理
} catch {
    Write-Error "エラーメッセージ"
    exit 1
}
```

**置換後:**

```powershell
try {
    # 処理
} catch {
    Write-Error "エラーメッセージ"
    Write-Error "Exception Type: $($_.Exception.GetType().FullName)"
    if (-not $NoKeyWait) { Popup-Message(...) }
    $script:CanExecuteProcess = $false
    $script:ExitCode = 1
    return
}
```

#### 1-3. 実装したエラーパス（計14箇所）

| エラーパス | Exit コード | 箇所数 |
|-----------|-----------|--------|
| COM オブジェクト作成失敗 | 1 | 1 |
| 共通スクリプト読み込み失敗 | 1 | 1 |
| YAML ファイル不在 | 1 | 1 |
| YAML 解析失敗 | 1 | 1 |
| YAML モジュール読み込み失敗 | 1 | 1 |
| YAML 検証失敗 | 2 | 1 |
| ログディレクトリ作成失敗 | 1 | 1 |
| ILSpyCmd 既存インストール検出 | 0 | 1（return） |
| SDK インストール前チェック | - | 1（確認型） |
| 管理者権限不足 | 3 | 1 |
| インストーラーファイル未検出 | 1 | 1 |
| インストーラー検証失敗 | 5 | 1 |
| インストール時タイムアウト | 6 | 1 |
| SDK インストール失敗 | 1 | 1 |
| SDK インストーラー起動失敗 | 1 | 1 |
| ユーザーがキャンセル | 0 | 1 |
| ネットワーク接続失敗 | 4 | 1 |
| ILSpyCmd インストール失敗 | 1 | 2 |

#### 1-4. End ブロックの改善

**置換前:**

```powershell
end {
    if ($script:comObject -ne $null) {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:comObject) | Out-Null
    }
    Invoke-Item -Path $script:Log
}
```

**置換後:**

```powershell
end {
    # エラー状態の確認
    if (-not $script:CanExecuteProcess) {
        if ($script:Log -and (Test-Path $script:Log)) {
            Add-Content -Path $script:Log -Value "`n=== Script ended with error (Exit Code: $script:ExitCode) ==="
        }
    } else {
        if ($script:Log -and (Test-Path $script:Log)) {
            Add-Content -Path $script:Log -Value "`n=== Script completed successfully (Exit Code: 0) ==="
        }
    }
    
    # COM オブジェクト解放（常に実行）
    if ($script:comObject) {
        try {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:comObject) | Out-Null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        } catch {
            # 無視
        }
    }
    
    # ログを開く（-NoKeyWait 時は開かない）
    if ((-not $NoKeyWait) -and ($script:Log -and (Test-Path $script:Log))) {
        try {
            Invoke-Item -Path $script:Log
        } catch {
            # 無視
        }
    }
    
    # 終了コード返却
    exit $script:ExitCode
}
```

**改善ポイント:**

- ✅ `CanExecuteProcess` フラグで処理状態を管理
- ✅ エラー時・成功時のログ記録を分離
- ✅ Endブロックでログ出力とCOM解放が確実に実行
- ✅ ログ開きは `-NoKeyWait` に基づき条件付け
- ✅ 例外発生時もendブロック実行は保証

---

### 改善 #2: -NoKeyWait パラメーター追加（非対話モード対応）

**目的:** スケジューラー・自動化環境での使用時、ユーザー入力が必要なポップアップを抑止し、ログファイルのみで処理を実行

**変更内容:**

#### 2-1. パラメーター定義

```powershell
param (
    [Parameter(Mandatory=$false)]
    [ValidateScript({...})]
    [string]$EnvYaml = "getILSpyCmd.yaml",
    
    [Parameter(Mandatory=$false)]
    [switch]$NoKeyWait = $false      # 非対話環境でキー待機を無効化
)
```

#### 2-2. ポップアップ条件付け実行

**パターン例（計20箇所以上）:**

```powershell
# ポップアップを実行する場合の条件付け
if (-not $NoKeyWait) {
    $script:comObject.Popup("メッセージ", 0, "タイトル", 0x10) | Out-Null
}

# ログファイル自動オープンも条件付け
if ((-not $NoKeyWait) -and ($script:Log -and (Test-Path $script:Log))) {
    Invoke-Item -Path $script:Log
}
```

**実装対象:**

1. ✅ COMオブジェクト作成失敗ポップアップ
2. ✅ 共通スクリプト読み込み失敗ポップアップ
3. ✅ YAMLファイル不在ポップアップ
4. ✅ YAML解析失敗ポップアップ
5. ✅ YAMLモジュール読み込み失敗ポップアップ
6. ✅ YAML検証失敗ポップアップ
7. ✅ ログディレクトリ作成失敗ポップアップ
8. ✅ ILSpyCmd既存検出ポップアップ
9. ✅ SDK未インストール警告ポップアップ
10. ✅ 管理者権限不足ポップアップ
11. ✅ ファイルサイズ警告ポップアップ
12. ✅ インストーラー検証失敗ポップアップ
13. ✅ SDKインストール開始ポップアップ
14. ✅ SDKインストールタイムアウトポップアップ
15. ✅ SDKインストール失敗ポップアップ
16. ✅ SDKインストーラー起動失敗ポップアップ
17. ✅ SDKインストール完了ポップアップ
18. ✅ SDKインストール警告ポップアップ
19. ✅ SDKキャンセル確認ポップアップ
20. ✅ ネットワークエラーポップアップ
21. ✅ ILSpyCmdインストール開始ポップアップ
22. ✅ ILSpyCmdインストール完了ポップアップ
23. ✅ ILSpyCmdインストール失敗ポップアップ

**使用例:**

```powershell
# 対話的実行（デフォルト）
.\getILSpyCmd.ps1

# 非対話的実行（スケジューラーなど）
.\getILSpyCmd.ps1 -NoKeyWait
```

#### 2-3. スケジューラータスクの設定例

```powershell
# タスクスケジューラーで非対話実行
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
  -Argument "-NoProfile -File 'c:\...\getILSpyCmd.ps1' -NoKeyWait"
```

**改善ポイント:**

- ✅ ポップアップを完全に抑止（スケジューラー向け）
- ✅ ログファイルに全情報を記録
- ✅ 対話環境では従来通り動作
- ✅ 例外情報も明示的に出力

---

### 補助改善: 例外タイプのログ出力

**目的:** デバッグ・トラブルシューティング時に例外の種類を明確にする

**実装:**

```powershell
catch {
    Write-Error "エラーメッセージ: $($_)"
    Write-Error "Exception Type: $($_.Exception.GetType().FullName)"
    # ...
}
```

**記録される情報の例:**

```log
Exception Type: System.IO.FileNotFoundException
Exception Type: System.UnauthorizedAccessException
Exception Type: System.Net.WebException
Exception Type: System.Management.Automation.ParameterBindingException
```

---

## 動作検証

### テスト項目

| テスト項目 | 期待動作 | 検証方法 |
|-----------|--------|--------|
| 基本実行（対話） | ポップアップ表示、ログファイル開く | `.\getILSpyCmd.ps1` |
| -NoKeyWait 実行 | ポップアップなし、ログ開かない | `.\getILSpyCmd.ps1 -NoKeyWait` |
| YAML エラー時 | エラー終了、end ブロック実行 | YAML ファイル削除 |
| 権限エラー時 | 管理者権限不足エラー、終了 | 非管理者で実行 |
| ネットワークエラー時 | ネットワーク接続エラー | インターネット接続遮断 |
| インストール成功時 | exit 0、ログ出力 | SDK・ILSpyCmd インストール |

### テスト結果

- ✅ Endブロックは常に実行される
- ✅ ポップアップは `-NoKeyWait` で完全に抑止
- ✅ すべてのエラーパスで `$script:ExitCode` が設定される
- ✅ ログファイルには完全な処理履歴が記録される

---

## ファイル変更一覧

| ファイル | 変更内容 | 行数 |
|---------|--------|------|
| `getILSpyCmd.ps1` | パラメーター追加、フラグ初期化、exit 置換、end ブロック改善 | 688行 |
| `README.md` | v1.3.0 ドキュメント作成 | 新規 |

---

## 後続改善予定

- [ ] #3: 例外タイプのログレベル分類化
- [ ] #4: パラメーター検証の強化（YAMLパス指定など）
- [ ] #5: タイムアウト時間のパラメーター化
- [ ] #6: ロールバック機能の詳細オプション化

---

## 参考資料

### スクリプトの使用方法

```powershell
# 基本的な実行
.\getILSpyCmd.ps1

# カスタム YAML を指定
.\getILSpyCmd.ps1 -EnvYaml "custom.yaml"

# 非対話モード（スケジューラー向け）
.\getILSpyCmd.ps1 -NoKeyWait

# 両方を指定
.\getILSpyCmd.ps1 -EnvYaml "custom.yaml" -NoKeyWait
```

### 終了コード確認方法

```powershell
# PowerShell で実行
.\getILSpyCmd.ps1 -NoKeyWait
$lastExitCode
```

---

**ドキュメント作成日:** 2025-01-15  
**スクリプトバージョン:** v1.3.0
