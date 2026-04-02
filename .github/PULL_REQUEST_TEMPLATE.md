## 📝 概要

<!-- この変更の目的を簡潔に説明してください -->

## 🔗 関連Issue

<!-- 関連するIssueがあればリンクしてください -->
Closes #(issue番号）

## 📋 変更内容

<!-- 具体的な変更内容をリストアップしてください -->
- 
- 
- 

## 🎯 変更の種類

<!-- 該当する項目にチェックを入れてください -->
- [ ] 🐛 バグ修正 (Bug fix)
- [ ] ✨ 新機能 (New feature)
- [ ] 📚 ドキュメント (Documentation)
- [ ] 🎨 スタイル (Formatting, missing semi colons, etc)
- [ ] ♻️ リファクタリング (Refactoring)
- [ ] ⚡ パフォーマンス改善 (Performance improvement)
- [ ] ✅ テスト (Adding tests)
- [ ] 🔧 ツール・設定変更 (Build, CI/CD, etc)
- [ ] 💥 破壊的変更 (Breaking change)

## 💡 動機と背景

<!-- なぜこの変更が必要なのかを説明してください -->

## 🧪 テスト方法

<!-- この変更をどのようにテストしたかを説明してください -->

### テスト環境

- OS:
- PowerShellバージョン: 
- 影響を受けるツール: 

### テストケース

1. 
2. 
3. 

### テスト結果

```powershell
# テストコマンドと結果を貼り付け
```

## 📸 スクリーンショット（該当する場合）

<!-- 変更を視覚的に示すスクリーンショットを追加してください -->

## ✅ チェックリスト

<!-- PRを作成する前に、以下の項目を確認してください -->

### コード品質

- [ ] PSScriptAnalyzerのチェックを通過している

  ```powershell
  Get-ChildItem -Recurse -File -Include *.ps1,*.psm1,*.psd1 |
    Where-Object {
      $_.FullName -notmatch '\\.venv\\' -and
      $_.FullName -notmatch '\\.localmodules\\' -and
      $_.FullName -notmatch '(\\|^)(Tests|docs|adr|LOG)(\\|$)' -and
      $_.FullName -notmatch '\\.github\\'
    } |
    ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings .\PSScriptAnalyzerSettings.psd1 }
  ```

- [ ] [SCOPE_GUIDELINES.md](../SCOPE_GUIDELINES.md) に準拠している
- [ ] 適切なエラーハンドリングを実装している
- [ ] コードに適切なコメントを追加している

### ドキュメント

- [ ] README.mdを更新している（必要な場合）
- [ ] ツール固有のReadme.mdを更新している（必要な場合）
- [ ] コメントベースのヘルプ（.SYNOPSIS, .DESCRIPTION等）を追加/更新している
- [ ] 使用例を追加している（必要な場合）

### セキュリティ

- [ ] 機密情報（鍵、パスワード、接続文字列等）をコミットしていない
- [ ] `.gitignore` が適切に設定されている
- [ ] 入力値の検証を実装している

### テスト

- [ ] 正常系のテストを実施している
- [ ] 異常系のテストを実施している
- [ ] エッジケースのテストを実施している
- [ ] 既存機能を壊していないことを確認している

### その他

- [ ] コミットメッセージが [Conventional Commits](https://www.conventionalcommits.org/) にしたがっている
- [ ] [CONTRIBUTING.md](../CONTRIBUTING.md) を読んで理解している
- [ ] 破壊的変更がある場合、その旨を明記している

## 💬 レビュアーへのメモ

<!-- レビュアーに特に注目してほしい点や、説明が必要な設計判断があれば記載してください -->

## 📚 参考資料

<!-- 関連するドキュメント、記事、ディスカッションなどがあればリンクしてください -->
- 
- 

---

## 🚨 破壊的変更（該当する場合のみ）

<!-- この変更が既存の機能を壊す場合、詳細を記載してください -->

### 影響範囲
<!-- どの機能・スクリプトが影響を受けるか -->

### 移行ガイド
<!-- ユーザーがどのように対応すべきか -->

### 回避策
<!-- 既存のコードを変更せずに対応する方法があれば記載 -->
