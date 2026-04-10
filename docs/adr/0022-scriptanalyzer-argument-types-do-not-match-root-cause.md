# ADR-0022: PSScriptAnalyzer 差分チェックの Argument types do not match は結果集約処理を修正し、workflow には型観測ログを追加して再発調査を容易にする

## Status

Accepted

## Context

GitHub ActionsのPSScriptAnalyzerコード品質チェックがREDとなり、
`scripts/Invoke-ScriptAnalyzerChanged.ps1` の呼び出し時に以下のエラーが記録された。

```text
Argument types do not match
```

workflowログ上では`-FailOnSeverity 'Error'`を含むスクリプト呼び出しの直後に失敗していたため、
当初は`Invoke-ScriptAnalyzerChanged.ps1`のparamバインディングで型不一致が起きているように見えた。

しかし、`Get-Command .\scripts\Invoke-ScriptAnalyzerChanged.ps1` で実測したパラメーター型は次のとおりであり、
少なくともインターフェイス定義そのものは想定に沿っていた。

- `BaseRef`: `System.String`
- `HeadRef`: `System.String`
- `FailOnSeverity`: `System.String[]`
- `OutputJsonPath`: `System.String`

その後、同じ引数でローカル再現と例外スタックを確認したところ、
実際の例外発生点はparamバインディングではなく、
`scripts/Invoke-ScriptAnalyzerChanged.ps1` 内の結果整形処理であることが分かった。

修正前の実装は、`System.Collections.Generic.List[object]` に集約した解析結果を
次のコードで配列化していた。

```powershell
$analysisResults = @($analysisResults)
```

この式が実行環境によっては動的バインディング例外を起こし、
`Argument types do not match` でジョブ全体を失敗させていた。

今回必要なのは、
「実際の障害点を修正してREDを止めること」と、
「次回同種障害が起きた際にparam定義と呼び出し引数の切り分けをログだけで追えること」
の両立である。

## Decision

PSScriptAnalyzer差分チェックの安定化のため、script側とworkflow側を次の方針で修正する。

- `scripts/Invoke-ScriptAnalyzerChanged.ps1` の結果集約処理は、`@(...)` による配列化を廃止し、`ToArray()` に置き換える。
- `.github/workflows/psscriptanalyzer.yml` には、`Invoke-ScriptAnalyzerChanged.ps1` のパラメーター型を実行前に出力するstepを追加する。
- `.github/workflows/psscriptanalyzer.yml` では、`FailOnSeverity` を `@('Error')` として明示的に配列で渡す。
- `BaseRef`、`HeadRef`、`OutputJsonPath` の既存インターフェイスは変更しない。
- `PSScriptAnalyzerSettings.psd1`、解析対象paths、`runs-on`、利用actionのバージョンは変更しない。

修正後の結果集約処理は以下とする。

```powershell
$analysisResults = $analysisResults.ToArray()
```

## Rationale

- 実際の例外発生点はscript内の結果整形処理であり、workflowだけを変更しても根本原因は解消しないため。
- `ToArray()` は `List[object]` を明示的に `object[]` へ変換でき、`@(...)` による動的バインディング例外を回避できるため。
- workflow側にパラメーター型ログを残すことで、将来 `Argument types do not match` が再発した場合に、param定義と呼び出し値のどちらを疑うべきかを先に切り分けられるため。
- `FailOnSeverity` は実測で `System.String[]` だったため、呼び出し側でも配列形状を明示し、意図をログ上で読み取りやすくするため。

## Consequences

- GitHub ActionsのPSScriptAnalyzer差分チェックは、結果集約処理で `Argument types do not match` を起こさなくなる。
- workflowログにparam型の観測結果が残るため、今後の障害解析が容易になる。
- workflowのログ出力量はわずかに増えるが、診断性向上の利益が上回る。
- `FailOnSeverity`の運用方針自体は変わらず、従来どおりErrorを失敗条件として扱う。

## Alternatives Considered

1. workflow側だけを修正する

   エラー表示上は呼び出し時失敗に見えるが、実際の例外発生点はscript内の結果整形処理だった。
   workflowのみを修正しても根本原因が残るため採用しない。

2. `Invoke-ScriptAnalyzerChanged.ps1`のparam定義を変更する

   実測した `BaseRef`、`HeadRef`、`FailOnSeverity`、`OutputJsonPath` の型定義は要件に沿っており、
   問題箇所ではなかった。インターフェイスを変える理由がないため採用しない。

3. `FailOnSeverity`をWarningなどへ緩和して通す

   本件は解析ルール違反ではなく実装障害であり、失敗条件の緩和は問題の隠蔽になる。
   ADR-0014の方針とも整合しないため採用しない。

## Verification

修正後、workflow相当の引数で `scripts/Invoke-ScriptAnalyzerChanged.ps1` を再実行し、
次を確認した。

- `Argument types do not match` が再発しないこと
- `LOG/psscriptanalyzer-changed.json`へのJSON出力が完了すること
- ジョブ失敗の原因が型不一致ではなく、本来のPSScriptAnalyzer結果だけになること

確認時の実行では、対象差分に対して `FailOnSeverity = Error` に一致する結果はなく、正常終了した。

## Links

- [ADR-0014: ScriptAnalyzer 差分チェックの FailOnSeverity を当面 Error のみにする](0014-psscriptanalyzer-failonseverity-error-only.md)
- [ADR-0018: PSScriptAnalyzer の Path 型差異を吸収するため、差分チェック実装を単一ファイル解析方式に変更する](0018-scriptanalyzer-single-file-analysis-for-path-type-compatibility.md)
- [ADR-0019: GitHub Actions のドットソース実行経路で ValidateSet パラメーターバインディングの型不一致が起きるため、workflow 側で型を確定させて回避する](0019-github-actions-dot-source-validateset-parameter-binding.md)
- [.github/workflows/psscriptanalyzer.yml](../../.github/workflows/psscriptanalyzer.yml)
- [scripts/Invoke-ScriptAnalyzerChanged.ps1](../../scripts/Invoke-ScriptAnalyzerChanged.ps1)