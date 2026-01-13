# 貢献ガイドライン

このプロジェクトへの貢献を検討していただきありがとうございます！このドキュメントでは、コードの貢献方法、コーディング規約、プルリクエストのプロセスについて説明します。

## 📋 目次

- [行動規範](#行動規範)
- [貢献の方法](#貢献の方法)
- [開発環境のセットアップ](#開発環境のセットアップ)
- [コーディング規約](#コーディング規約)
- [コミットメッセージ規約](#コミットメッセージ規約)
- [プルリクエストのプロセス](#プルリクエストのプロセス)
- [コードレビュー](#コードレビュー)
- [テスト](#テスト)

## 行動規範

このプロジェクトに参加するすべての人は、以下の行動規範に従うことが求められます：

- **尊重**: すべての貢献者を尊重し、建設的なフィードバックを提供してください
- **協力**: オープンで友好的な環境を作り、他の人の成長を支援してください
- **包括性**: 多様な視点と経験を歓迎します
- **プロフェッショナリズム**: プロフェッショナルで礼儀正しいコミュニケーションを心がけてください

## 貢献の方法

### バグ報告

バグを見つけた場合は、[Issue](https://github.com/UMA68/PowerShell/issues)を作成してください：

1. 既存のIssueで同じ問題が報告されていないか確認
2. バグレポートテンプレートを使用して新しいIssueを作成
3. 再現手順、期待される動作、実際の動作を明確に記述
4. 可能であれば、スクリーンショットやログファイルを添付

### 機能提案

新機能のアイデアがある場合：

1. [Issue](https://github.com/UMA68/PowerShell/issues)で機能リクエストテンプレートを使用
2. 提案する機能の背景、用途、利点を説明
3. 可能であれば、使用例や疑似コードを提供
4. コミュニティからのフィードバックを待つ

### コード貢献

1. リポジトリをFork
2. 作業用ブランチを作成（`feature/your-feature-name` または `fix/your-bug-fix`）
3. コードを変更
4. テストを追加・実行
5. コミット
6. プルリクエストを作成

## 開発環境のセットアップ

### 前提条件

```powershell
# PowerShell 7.3以上
winget install Microsoft.PowerShell

# 実行ポリシーの設定
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 必要なモジュールのインストール

```powershell
# PowerShell-Yaml
Install-Module -Name PowerShell-Yaml -MinimumVersion 0.4.7 -Scope CurrentUser

# PSScriptAnalyzer（コード品質チェック）
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser

# Pester（テストフレームワーク、今後導入予定）
Install-Module -Name Pester -Scope CurrentUser
```

### リポジトリのクローン

```powershell
# Forkしたリポジトリをクローン
git clone https://github.com/[your-username]/PowerShell.git
cd PowerShell

# upstreamリモートを追加
git remote add upstream https://github.com/UMA68/PowerShell.git
```

## コーディング規約

### PowerShell スタイルガイド

#### 変数のスコープ

**必須**: [SCOPE_GUIDELINES.md](SCOPE_GUIDELINES.md) に従ってください。

```powershell
# ✅ 推奨: スクリプトスコープ変数を明示的に指定
begin {
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $script:Config = Import-YamlConfig -Path $configPath
}

# ❌ 非推奨: スコープを明示しない
begin {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Config = Import-YamlConfig -Path $configPath
}
```

#### 関数とパラメータ

```powershell
# ✅ 推奨: CmdletBindingを使用し、詳細なヘルプを提供
<#
.SYNOPSIS
    簡潔な説明

.DESCRIPTION
    詳細な説明

.PARAMETER ParameterName
    パラメータの説明

.EXAMPLE
    使用例
#>
function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )
    
    begin {
        # 初期化処理
    }
    
    process {
        # メイン処理
    }
    
    end {
        # 後処理
    }
}
```

#### エラーハンドリング

```powershell
# ✅ 推奨: try-catch-finallyを適切に使用
try {
    # 処理
    $result = Invoke-SomeCommand
}
catch [System.UnauthorizedAccessException] {
    Write-CommonLog -Message "アクセス権限エラー: $_" -Level "ERROR"
    throw
}
catch {
    Write-CommonLog -Message "予期しないエラー: $_" -Level "ERROR"
    throw
}
finally {
    # リソースのクリーンアップ
    if ($resource) { $resource.Dispose() }
}
```

#### コメント

```powershell
# ✅ 推奨: 意図を説明するコメント
# ユーザー権限が不足している場合、管理者として再実行を促す
if (-not (Test-Administrator)) {
    Show-AdminPrompt
}

# ❌ 非推奨: 自明なコメント
# 変数に値を代入
$count = 0
```

### PSScriptAnalyzer

すべてのコード変更は、PSScriptAnalyzerのチェックを通過する必要があります。

```powershell
# リポジトリ全体をチェック
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1

# 特定のファイルをチェック
Invoke-ScriptAnalyzer -Path .\Script\YourScript.ps1 -Settings .\PSScriptAnalyzerSettings.psd1
```

**重要なルール**:
- `PSUseDeclaredVarsMoreThanAssignments`: 未使用変数を避ける
- `PSAvoidGlobalVars`: グローバル変数を避ける
- `PSUseCorrectCasing`: 正しい大文字小文字を使用
- `PSUseConsistentWhitespace`: 一貫した空白を使用
- `PSUseApprovedVerbs`: 承認された動詞を使用
- `PSAvoidUsingWriteHost`: `Write-Host`の代わりに`Write-Output`を使用

### ファイル構成

```powershell
# スクリプトの標準構造
<#
.SYNOPSIS
.DESCRIPTION
.PARAMETER
.EXAMPLE
.NOTES
    File Name      : ScriptName.ps1
    Author         : Your Name
    Version        : 1.0.0
    Release Date   : YYYY-MM-DD
    Prerequisite   : PowerShell 7.3+
#>

[CmdletBinding()]
param(
    # パラメータ定義
)

begin {
    # 初期化処理
    # - パス設定
    # - 共通スクリプト読み込み
    # - 設定ファイル読み込み
}

process {
    # メイン処理
}

end {
    # 後処理
    # - ログ出力
    # - リソース解放
}
```

## コミットメッセージ規約

[Conventional Commits](https://www.conventionalcommits.org/) に従ってください。

### フォーマット

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type（必須）

- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更（空白、フォーマットなど）
- `refactor`: バグ修正や機能追加ではないコードの変更
- `perf`: パフォーマンス改善
- `test`: テストの追加や修正
- `chore`: ビルドプロセスやツールの変更

### Scope（オプション）

変更の範囲を示します：
- `common`: Commonフォルダーの変更
- `decompile`: DecompileDLLツールの変更
- `sql`: SQLクエリー実行ツールの変更
- `release`: リリースバッチツールの変更
- `security`: セキュリティツールの変更
- `ci`: CI/CD設定の変更

### 例

```bash
# 新機能の追加
git commit -m "feat(sql): SQLクエリ実行時のタイムアウト設定を追加"

# バグ修正
git commit -m "fix(common): Write-CommonLogのタイムスタンプフォーマットを修正"

# ドキュメント更新
git commit -m "docs: READMEにトラブルシューティングセクションを追加"

# リファクタリング
git commit -m "refactor(decompile): 並列処理ロジックを関数化"

# 破壊的変更（BREAKING CHANGE）
git commit -m "feat(common)!: Get-ScriptPathsの戻り値の構造を変更

BREAKING CHANGE: 戻り値がハッシュテーブルからPSCustomObjectに変更されました。"
```

## プルリクエストのプロセス

### プルリクエスト作成前のチェックリスト

- [ ] コードがPSScriptAnalyzerのチェックを通過している
- [ ] 適切なコメント・ドキュメントを追加している
- [ ] [SCOPE_GUIDELINES.md](SCOPE_GUIDELINES.md) に従っている
- [ ] 新機能の場合、使用例を追加している
- [ ] 既存の機能を壊していない
- [ ] セキュリティ上の問題がない（鍵ファイル、パスワードなどをコミットしていない）

### プルリクエストのタイトル

コミットメッセージと同じフォーマットを使用：

```
feat(scope): 新機能の簡潔な説明
fix(scope): バグ修正の簡潔な説明
```

### プルリクエストの説明

以下の情報を含めてください：

```markdown
## 概要
この変更の目的を簡潔に説明してください。

## 変更内容
- 変更点1
- 変更点2
- 変更点3

## 動機と背景
なぜこの変更が必要なのかを説明してください。

## テスト方法
この変更をどのようにテストしたかを説明してください。

## スクリーンショット（該当する場合）
変更を視覚的に示すスクリーンショットを追加してください。

## チェックリスト
- [ ] PSScriptAnalyzerチェックを通過
- [ ] ドキュメントを更新
- [ ] SCOPE_GUIDELINESに準拠
```

### レビュープロセス

1. プルリクエストを作成すると、自動的にPSScriptAnalyzerがCIで実行されます（今後実装予定）
2. メンテナーがコードレビューを行います
3. フィードバックがあれば対応してください
4. 承認されたら、メンテナーがマージします

## コードレビュー

### レビュアーとして

- **建設的**: 問題を指摘するだけでなく、解決策を提案してください
- **具体的**: 曖昧なコメントではなく、具体的な改善案を提示してください
- **優しく**: 敬意を持ってフィードバックしてください
- **質問**: 理解できない部分があれば質問してください

### レビュイーとして

- **オープン**: フィードバックを前向きに受け入れてください
- **説明**: なぜその実装にしたのか説明してください
- **迅速**: フィードバックには素早く対応してください
- **質問**: 理解できないコメントがあれば質問してください

## テスト

### 手動テスト

新しい機能やバグ修正を実装した場合は、以下をテストしてください：

1. **正常系**: 期待通りに動作することを確認
2. **異常系**: エラーが適切に処理されることを確認
3. **エッジケース**: 境界値や特殊な入力をテスト
4. **既存機能**: 他の機能を壊していないことを確認

### PSScriptAnalyzer による静的解析

```powershell
# すべてのスクリプトをチェック
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1

# 特定のフォルダーをチェック
Invoke-ScriptAnalyzer -Path .\Common\ -Recurse -Settings .\PSScriptAnalyzerSettings.psd1

# エラーのみ表示
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 -Severity Error
```

### ユニットテスト（今後導入予定）

Pesterを使用したユニットテストの作成を計画しています：

```powershell
# テストの実行（将来）
Invoke-Pester -Path .\Tests\

# カバレッジレポート
Invoke-Pester -Path .\Tests\ -CodeCoverage .\Common\*.ps1
```

## セキュリティ

### 機密情報の取り扱い

- **絶対に**以下をコミットしないでください：
  - `Common/Encryption.Key`
  - `*.pass` ファイル
  - パスワードやAPIキー
  - 実際の接続文字列

- `.gitignore` が適切に設定されていることを確認してください

### 脆弱性の報告

セキュリティ上の問題を発見した場合は、**公開のIssueではなく**、プライベートに報告してください：

1. リポジトリのメンテナーに直接連絡
2. 問題の詳細と再現手順を提供
3. 可能であれば、修正案を提案

## 質問やサポート

質問がある場合は：

1. [README.md](README.md) を確認
2. [SCOPE_GUIDELINES.md](SCOPE_GUIDELINES.md) を確認
3. [Issues](https://github.com/UMA68/PowerShell/issues) で質問
4. 既存のIssueやプルリクエストのディスカッションを参照

## ライセンス

このプロジェクトに貢献することで、あなたの貢献が [MIT License](LICENSE) の下でライセンスされることに同意したものとみなされます。

---

**貢献いただきありがとうございます！** 🎉

あなたの時間と努力は、このプロジェクトをより良いものにするのに役立ちます。
