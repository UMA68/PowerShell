# ADR-0019: GitHub Actionsのドットソース実行経路でValidateSetパラメーターバインディングの型不一致が起きるため、workflow側で型を確定させて回避する

## Status

Accepted

## Context

GitHub Actionsのrun:ブロックは、ランナーが一時的な .ps1ファイルに書き出し、
`pwsh -command ". '{0}'"` の形式でドットソース実行する。

この実行経路では、`[CmdletBinding()]`を持つ子スクリプトを呼び出す際、
`[ValidateSet]`属性を持つパラメーターのバインディング検証が .NETリフレクション経路を経由する場合がある（以下「リフレクション経路」）。
リフレクション経由の検証は型の暗黙変換を行わないため、
PowerShellの配列リテラル`@('Error')`が`[System.Object[]]`のまま渡ると
`[string[]]`との型不一致で例外になる。

実際に以下のエラーが確認された。

```text
Invoke-ScriptAnalyzerChanged.ps1: D:\a\_temp\bacf6d45-25b2-473a-9d2b-8dd6f07d24e4.ps1:19
Line |
  19 |  .\scripts\Invoke-ScriptAnalyzerChanged.ps1 `
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Argument types do not match
```

WorkflowのshellログにはGitHub Actionsが生成した呼び出し形式が確認できる。

```text
shell: C:\Program Files\PowerShell\7\pwsh.EXE -command ". '{0}'"
```

ローカルで`pwsh .\scripts\Invoke-ScriptAnalyzerChanged.ps1 -FailOnSeverity @('Error')`を
直接実行した場合はこの経路を通らないため、同じコードでも再現しない。

## Decision

workflow側（psscriptanalyzer.yml）で、配列リテラルを`[string[]]`型でアノテーションした変数に代入してから、スクリプトへ渡す。

```powershell
[string[]] $failSeverity = @('Error')
.\scripts\Invoke-ScriptAnalyzerChanged.ps1 `
  -BaseRef $baseRef `
  -HeadRef 'HEAD' `
  -FailOnSeverity $failSeverity `
  -OutputJsonPath 'LOG/psscriptanalyzer-changed.json'
```

- `@('Error')`を直接`-FailOnSeverity`へ渡す書き方は廃止する
- 複数のSeverityを渡す場合も同様の代入パターンを使用する
- Invoke-ScriptAnalyzerChanged.ps1のパラメーター定義（`[ValidateSet][string[]]`）は変更しない

## Rationale

- 代入は常にPowerShellの`LanguagePrimitives.ConvertTo`を経由するため、`object[] → string[]`の変換が保証される
- スクリプト呼び出し時点では変数はすでに`string[]`に確定しているため、リフレクション経路でも型が一致する
- スクリプト側のパラメーター設計は正しく、問題の発生源はworkflowの渡し方にあるため、workflow側で解決する
- Invoke-ScriptAnalyzerChanged.ps1は他の呼び出し元（ローカル・他workflow）でも使われる可能性があるため、呼び出し元ごとに型を確定させる方針を採る

## Consequences

- psscriptanalyzer.ymlにおける`Argument types do not match`エラーが解消される
- Invoke-ScriptAnalyzerChanged.ps1のインターフェイスは変更されないため、既存の呼び出し元への影響はない
- 同種のパターン（`[ValidateSet][string[]]`を持つスクリプトをrun:から呼ぶ）には今後も同じ方針を適用する
- run: で配列を直接渡すと、入力形状や環境更新によりCIが非決定的に壊れ、
  ローカル再現不能・原因追跡困難な障害を引き起こす。

## Options Considered

1. `-FailOnSeverity ([string[]]@('Error'))`のようにインラインキャストする

インラインキャストでも型変換は可能だが、可読性が低く、追加や変更の際に書き忘れが生じやすいため採用しない。

2. Invoke-ScriptAnalyzerChanged.ps1のFailOnSeverityを`[string[]]`でなく`[object[]]`に変更する

パラメーター定義を変えると`[ValidateSet]`の意図が薄れ、設計を後退させるため採用しない。

3. workflow側でSet-StrictModeをOFFにしてバインディング検証を緩める

Set-StrictModeはバインディング型変換とは独立しており、本エラーには直接効果がなく、デバッグ容易性も損なうため採用しない。

4. shell: powershell（Windows PowerShell 5.1）に切り替えて実行する

ADR-0007でPowerShell Core（7.x）への統一を決定済みであり、整合しないため採用しない。

## Follow-up

- 他のworkflowファイルに同様の配列リテラル直接渡しが存在しないか確認し、必要であれば同じパターンに揃える
- PowerShell側でドットソース実行とスクリプト直接実行の型変換挙動が統一された場合は、代入変数の要否を再評価する

## Links

- [ADR-0014: ScriptAnalyzer 差分チェックの FailOnSeverity を当面 Error のみにする](0014-psscriptanalyzer-failonseverity-error-only.md)
- [ADR-0018: PSScriptAnalyzer の Path 型差異を吸収するため、差分チェック実装を単一ファイル解析方式に変更する](0018-scriptanalyzer-single-file-analysis-for-path-type-compatibility.md)
- [.github/workflows/psscriptanalyzer.yml](../../.github/workflows/psscriptanalyzer.yml)
- [scripts/Invoke-ScriptAnalyzerChanged.ps1](../../scripts/Invoke-ScriptAnalyzerChanged.ps1)
- Playbook: [PowerShell リポジトリ CI 運用 Playbook](../guides/Playbook.md)
 （ScriptAnalyzer（差分チェック）運用指針：run: 経由呼び出し時は配列パラメーターを事前に型確定）
 