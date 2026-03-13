# テストについて

このリポジトリでは、Pesterを使用したユニットテストを実施しています。

## テストの構造

```Shell
Tests/
├── README.md                                    # このファイル
├── Common/                                      # Common モジュールのテスト
│   ├── Get-ScriptPaths.Tests.ps1                # ✅ 実装完了 (40テストケース)
│   ├── Write-CommonLog.Tests.ps1                # ✅ 実装完了 (30テストケース)
│   ├── Import-YamlConfig.Tests.ps1              # ✅ 実装完了 (35テストケース)
│   ├── CheckCommand.Tests.ps1                   # ✅ 更新: 内容を全面改修
│   └── NoDoubleActivation.Tests.ps1             # ✅ 新規追加: 二重起動防止機能のテスト
├── Integration/                                 # 統合テスト
│   ├── ReleaseProcess.Tests.ps1                 # ✅ 実装完了 (17テストケース)
│   ├── DecompileDll.Tests.ps1                   # ✅ 実装完了 (8テストケース: Pass 6 / Skip 2)
│   ├── SQLQuery.Tests.ps1                       # 📋 テンプレート
│   └── sqlMain.Tests.ps1                        # ✅ 新規追加: SQL 実行フローの統合テスト
└── Fixtures/                                    # テスト用のサンプルファイル
    ├── SampleConfig.yaml
    ├── SampleScript.ps1
    └── SampleDatabase/
```

**凡例:**

- ✅ 実装完了 - テストケースが完成して実行可能
- 📋 テンプレート - 実装ガイドとしてご利用ください
- 更新 - 既存テストを全面改修して保守性・網羅性を強化
- 新規追加 - 新しい対象機能に対して追加したテスト

## 前提条件

### Pester のインストール

```powershell
# Pester をインストール（v5以上推奨）
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force

# バージョン確認
Get-Module -ListAvailable Pester | Select-Object Name, Version
```

### その他の必要なモジュール

```powershell
# PowerShell-Yaml
Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Scope CurrentUser

# PSScriptAnalyzer
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

## テスト実行方法

### すべてのテストを実行

```powershell
# リポジトリのルートから
cd PowerShell

# すべてのテストを実行
Invoke-Pester -Path .\Tests\ -Verbose

# テスト結果を NUnit 形式で出力
Invoke-Pester -Path .\Tests\ -OutputFormat NUnitXml -OutputFile test-results.xml
```

### 特定のテストファイルを実行

```powershell
# Common モジュールのテストのみ
Invoke-Pester -Path .\Tests\Common\Get-ScriptPaths.Tests.ps1 -Verbose

# FindModule のテストのみ
Invoke-Pester -Path .\Tests\Common\FindModule.Tests.ps1 -Verbose

# 統合テストのみ
Invoke-Pester -Path .\Tests\Integration\ -Verbose

# DecompileDll 統合テスト（ファイル単体）
Invoke-Pester -Path .\Tests\Integration\DecompileDll.Tests.ps1 -Verbose

# DecompileDll 統合テスト（Pester 5 ランナー経由）
pwsh -NoProfile -File .\Run-Pester5.ps1 -DecompileDll
```

### 特定のテストを実行（フィルタリング）

```powershell
# 特定のテスト関数を実行
Invoke-Pester -Path .\Tests\ -Filter @{ FullName = '*Get-ScriptPaths*' } -Verbose

# タグでフィルタリング
Invoke-Pester -Path .\Tests\ -Tag 'Unit' -Verbose
```

## カバレッジレポートの取得

### ローカルでの測定

```powershell
# コードカバレッジを測定
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = .\Common\*.ps1
$config.CodeCoverage.OutputPath = 'coverage.xml'
$config.CodeCoverage.OutputFormat = 'CoverageGutters'
$config.Run.Path = .\Tests\Common\

Invoke-Pester -Configuration $config

# レポートを確認
Get-Content coverage.xml | ConvertFrom-Csv | Format-Table -AutoSize
```

### CI/CD での自動測定

GitHub Actionsで自動的にカバレッジが測定され、アーティファクトとして保存されます：

1. PRを作成すると、GitHub Actionsが自動的に実行
2. テスト結果とカバレッジレポートが生成
3. アーティファクトセクションから `coverage-report-*.xml` をダウンロード可能

### VS Code での可視化

VS Code拡張機能でカバレッジを可視化できます：

```powershell
# Coverage Gutters 拡張をインストール
# https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters

# カバレッジレポート生成後、VS Code で表示
code .
# Ctrl+Shift+P -> Coverage Gutters: Display Coverage
```

## テストの書き方

### 基本的なテストテンプレート

```powershell
<#
.SYNOPSIS
    テスト対象の関数/スクリプトのテスト

.DESCRIPTION
    Get-ScriptPaths 関数のユニットテスト
    - 正常系: パスが正しく計算されることを検証
    - 異常系: 無効な入力に対してエラーが発生することを検証

.NOTES
    Author: Your Name
    Version: 1.0.0
    Last Updated: 2026-01-13
#>

BeforeAll {
    # テスト前の初期化処理
    # 対象の関数/スクリプトを読み込み
    $modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $modulePath 'Common\Get-ScriptPaths.ps1')
}

Describe 'Get-ScriptPaths' {
    Context '正常系: パス計算' {
        It 'スクリプトパスが設定されていない場合、デフォルトパスを使用' {
            # Arrange
            $testScriptPath = 'C:\Test\Script\MyScript.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            $result.Script | Should -Not -BeNullOrEmpty
            $result.PowerShell | Should -Not -BeNullOrEmpty
            $result.Common | Should -Not -BeNullOrEmpty
        }
        
        It 'EnvFileName を指定すると EnvFile キーが追加される' {
            # Arrange
            $testScriptPath = 'C:\Test\Script\MyScript.ps1'
            $envFileName = 'Env.yaml'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath -EnvFileName $envFileName
            
            # Assert
            $result.ContainsKey('EnvFile') | Should -BeTrue
            $result.EnvFile | Should -Match $envFileName
        }
    }
    
    Context '異常系: エラーハンドリング' {
        It 'スクリプトパスが空の場合、エラーが発生' {
            # Arrange
            $testScriptPath = ''
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $testScriptPath } | Should -Throw
        }
    }
}
```

### テストのベストプラクティス

1. **AAA パターンを使用**: Arrange → Act → Assert
2. **明確なテスト名**: テスト名から目的がわかること
3. **単一責任**: 1つのテストは1つのことをテストする
4. **モックとスタブの使用**: 外部依存を最小化
5. **セットアップとクリーンアップ**: 
   - `BeforeAll` / `AfterAll`: テスト前後の全体初期化
   - `BeforeEach` / `AfterEach`: 各テスト前後の初期化

## テストタグの使用

テストを分類・管理するためにタグを使用します：

```powershell
Describe 'Get-ScriptPaths' -Tag 'Unit', 'Common' {
    It 'パスを正しく計算する' -Tag 'Positive' {
        # テスト内容
    }
    
    It '無効な入力でエラーが発生' -Tag 'Negative' {
        # テスト内容
    }
}
```

**推奨タグ**:

- `Unit`: ユニットテスト
- `Integration`: 統合テスト
- `Positive`: 正常系テスト
- `Negative`: 異常系テスト
- `Common`, `SQL`, `Release`, `DecompileDLL`: モジュール別

### タグでのフィルタリング実行

```powershell
# Unit テストのみ実行
Invoke-Pester -Path .\Tests\ -Tag 'Unit' -Verbose

# Common モジュール以外を実行
Invoke-Pester -Path .\Tests\ -ExcludeTag 'Common' -Verbose
```

## CI/CD 統合

GitHub Actionsで自動的にテストが実行されます（`.github/workflows/pester.yml` 参照）。

```yaml
- name: Pester テスト実行
  run: |
    Invoke-Pester -Path .\Tests\ -OutputFormat NUnitXml -OutputFile test-results.xml
```

## トラブルシューティング

### Pester が見つからない

```powershell
# Pester がインストールされているか確認
Get-Module -ListAvailable Pester

# インストールされていない場合
Install-Module -Name Pester -Scope CurrentUser -Force
```

### モジュール読み込みエラー

```powershell
# 対象のモジュール/スクリプトのパスが正しいか確認
Test-Path 'C:\path\to\your\module.ps1'

# 構文エラーがないか確認
Invoke-ScriptAnalyzer -Path 'C:\path\to\your\module.ps1'
```

### テストの実行に時間がかかる

```powershell
# 特定のテストファイルのみ実行
Invoke-Pester -Path .\Tests\Common\Get-ScriptPaths.Tests.ps1

# パラレル実行（Pester v5.1+）
$config = New-PesterConfiguration
$config.Run.ParallelRuns = 4
Invoke-Pester -Configuration $config
```

## テスト作成のチェックリスト

テストを作成する際は、以下を確認してください：

- [ ] テスト関数がDescribe/Contextブロックで適切に構造化されている
- [ ] AAAパターン（Arrange-Act-Assert）にしたがっている
- [ ] テスト名が明確で目的がわかる
- [ ] 正常系と異常系の両方をテストしている
- [ ] エッジケースやボーダーケースをカバーしている
- [ ] モックとスタブを適切に使用している
- [ ] セットアップとクリーンアップが実装されている
- [ ] テストが高速に実行される（遅いテストは注記を追加）
- [ ] テストが繰り返し実行できる（テスト間で依存がない）
- [ ] コード行数が合理的（大きすぎないテスト）

## 追加・更新した主なテスト

### CheckCommand.Tests.ps1（更新）

PowerShellコマンド／外部コマンド検出関数Test-Commandのテスト。

- 正常系・異常系を大幅強化
- COM（WScript.Shell）によるポップアップ分岐もテスト
- Mock-ParameterFilterを用いた安定したモック方式へ更新

### NoDoubleActivation.Tests.ps1（新規）

二重起動防止ロジック (NoDoubleActivation.ps1) のテスト。

- PIDロックファイル生成／削除のモック化
- ポップアップ表示（WScript.Shell）を含む分岐の網羅
- CheckCommandと同じテストパターンを採用

### sqlMain.Tests.ps1（新規）

SQLクエリー実行のメインスクリプトsqlMain.ps1の統合テスト。

主なテスト対象：

- YAML読み込み
- SQLフォルダー検出
- nkf32をモック化したエンコード変換
- Key/passの存在確認
- SQL実行の成功／失敗ハンドリング
- 一時ファイル生成／削除
- SQL実行フロー全体のE2Eテスト

## 参考資料

- [Pester 公式ドキュメント](https://pester.dev/)
- [PowerShell テストベストプラクティス](https://docs.microsoft.com/powershell/scripting/learn/ps-best-practices)
- [AAA テストパターン](https://docs.microsoft.com/en-us/visualstudio/test/unit-test-basics)

## 貢献時のテスト要件

新機能またはバグ修正を提出する際は、以下を確認してください：

- [ ] 関連するユニットテストを実装している
- [ ] すべてのテストが成功している

  ```powershell
  Invoke-Pester -Path .\Tests\ -Verbose
  ```

- [ ] テストカバレッジが合理的な範囲にある（60%以上推奨）
- [ ] テストがPRテンプレートに記載されている

---

**質問や提案**: テスト関連の質問がある場合は、[Issue](https://github.com/UMA68/PowerShell/issues) で質問してください。
