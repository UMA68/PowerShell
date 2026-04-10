# Playbook — PSScriptAnalyzerの`Argument types do not match`再発対応手順

> 本Playbookは CI 運用全体の方針については [Playbook.md](Playbook.md) を前提とし、
> 本事象（Argument types do not match）の再発対応手順のみを定義する。
> 背景説明や設計判断は[ADR-0022](../ADR/0022-scriptanalyzer-argument-types-do-not-match-root-cause.md)に任せる。

## TL;DR
- GitHub ActionsのPSScriptAnalyzerが`Argument types do not match`でREDになったら、まずworkflowのパラメーター型ログを確認する
- `BaseRef`、`HeadRef`、`FailOnSeverity`、`OutputJsonPath`の型を実測し、パラメーター定義の問題か内部処理かを切り分ける
- 今回の既知真因は`scripts/Invoke-ScriptAnalyzerChanged.ps1`内の`$analysisResults = @($analysisResults)`である
- 修正は`$analysisResults = $analysisResults.ToArray()`を優先し、workflow側は`-FailOnSeverity @('Error')`と型ログステップを維持する
- 検証は「同一引数で再実行して`Argument types do not match`が消えること」で完了とする

---

## この Playbook の目的
本Playbookは、  
**GitHub ActionsのPSScriptAnalyzerが`Argument types do not match`で失敗したときに、思考停止で同じ切り分けと修正を再実行できるようにする**ことを目的とする。

背景説明や設計判断はADRに任せる。  
この文書では、**何を確認するか、どの順で直すか、どう成功判定するか**だけを固定する。

---

## 対象となる症状

### RED とみなす条件
- GitHub ActionsのPSScriptAnalyzerジョブがREDで終了している
- ログに`Argument types do not match`が含まれている
- 失敗箇所が`scripts/Invoke-ScriptAnalyzerChanged.ps1`呼び出し前後に見える

### 最初に持つべき前提
- 表面上はパラメーターバインドエラーに見えても、実際はスクリプト内部処理で失敗している場合がある
- 今回の既知事例では、パラメーター型は正常で、真因は結果集約処理だった

---

## 最初に確認すること

### 1. workflowログでパラメーター型出力ステップが実行されているか
Yes:
そのまま出力結果を読む。

No:
`.github/workflows/psscriptanalyzer.yml`にパラメーター型ログステップが残っているか確認する。

確認対象:
- `Invoke-ScriptAnalyzerChanged のパラメータ型を表示`ステップが存在するか
- 以下のコマンドで型を出しているか

```powershell
$cmd = Get-Command .\scripts\Invoke-ScriptAnalyzerChanged.ps1
$cmd.Parameters.GetEnumerator() |
  Sort-Object Key |
  ForEach-Object { "{0} : {1}" -f $_.Key, $_.Value.ParameterType.FullName }
```

### 2. 4つのパラメーター型を確認する
期待値は次のとおり。

- `BaseRef`: `System.String`
- `HeadRef`: `System.String`
- `FailOnSeverity`: `System.String[]`
- `OutputJsonPath`: `System.String`

Yes:
型は既知の状態なので、次の切り分けへ進む。

No:
パラメーター定義が変わっている。  
まず [scripts/Invoke-ScriptAnalyzerChanged.ps1](scripts/Invoke-ScriptAnalyzerChanged.ps1) の `param()` を確認し、既知状態との差分を把握する。

### 3. workflowの呼び出し引数を確認する
確認対象:

- `-BaseRef $baseRef`
- `-HeadRef 'HEAD'`
- `-FailOnSeverity @('Error')`
- `-OutputJsonPath 'LOG/psscriptanalyzer-changed.json'`

Yes:
既知の呼び出し形に一致する。スクリプト内部を疑う。

No:
まずworkflow側を既知形に戻してから再実行する。

---

## 再現手順

### ローカルで同じ引数を再実行する
作業ディレクトリをリポジトリルートに合わせ、次を実行する。

```powershell
.\scripts\Invoke-ScriptAnalyzerChanged.ps1 `
  -BaseRef HEAD~1 `
  -HeadRef HEAD `
  -FailOnSeverity @('Error') `
  -OutputJsonPath "LOG/psscriptanalyzer-changed.json"
```

期待する観測:
- 失敗が再現する場合、ローカルで例外スタックを取れる
- 再現しない場合、workflow側ログとの差分を確認できる

### 例外スタックを取る
`Argument types do not match` が出たら、次で発生行を確認する。

```powershell
try {
  .\scripts\Invoke-ScriptAnalyzerChanged.ps1 `
    -BaseRef HEAD~1 `
    -HeadRef HEAD `
    -FailOnSeverity @('Error') `
    -OutputJsonPath "LOG/psscriptanalyzer-changed.json"
}
catch {
  $_ | Format-List * -Force
  $_.InvocationInfo | Format-List * -Force
  $_.ScriptStackTrace | Out-String
}
```

Yes:
`scripts/Invoke-ScriptAnalyzerChanged.ps1` の内部行番号が出る。内部処理を確認する。

No:
workflow側の生成スクリプト行しか出ない場合は、パラメーター型ログと呼び出し引数を再確認する。

---

## 切り分け手順

### 1. パラメーターバインドか、スクリプト内部かを分ける
判定基準:

- パラメーター型が既知の状態である
- 呼び出し引数が既知の状態である
- 例外スタックが`scripts/Invoke-ScriptAnalyzerChanged.ps1`内部行を指す

Yes:
スクリプト内部処理が原因。次へ進む。

No:
workflowの引数形かパラメーター定義変更を先に戻す。

### 2. 結果集約処理を確認する
確認箇所は [scripts/Invoke-ScriptAnalyzerChanged.ps1](scripts/Invoke-ScriptAnalyzerChanged.ps1) の解析結果集約直後。

悪い状態:

```powershell
$analysisResults = @($analysisResults)
```

既知の正常状態:

```powershell
$analysisResults = $analysisResults.ToArray()
```

Yes:
悪い状態なら、この1行が真因候補である。

No:
すでに`ToArray()`なら、今回のPlaybook対象外の別原因として扱い、追加調査に切り替える。

---

## 修正手順

### 1. スクリプト側を直す
[scripts/Invoke-ScriptAnalyzerChanged.ps1](scripts/Invoke-ScriptAnalyzerChanged.ps1) の結果集約処理を次のように直す。

```powershell
$analysisResults = @($analysisResults)
```

↓

```powershell
$analysisResults = $analysisResults.ToArray()
```

### 2. workflow側を確認する
[.github/workflows/psscriptanalyzer.yml](.github/workflows/psscriptanalyzer.yml)で次の2点を確認する。

- パラメーター型ログステップが存在すること
- `-FailOnSeverity @('Error')` で呼んでいること

確認用の既知形:

```powershell
$cmd = Get-Command .\scripts\Invoke-ScriptAnalyzerChanged.ps1
$cmd.Parameters.GetEnumerator() |
  Sort-Object Key |
  ForEach-Object { "{0} : {1}" -f $_.Key, $_.Value.ParameterType.FullName }

& .\scripts\Invoke-ScriptAnalyzerChanged.ps1 `
  -BaseRef $baseRef `
  -HeadRef 'HEAD' `
  -FailOnSeverity @('Error') `
  -OutputJsonPath 'LOG/psscriptanalyzer-changed.json'
```

### 3. LOG出力先を確認する
`OutputJsonPath`は文字列であり、既知の出力先は`LOG/psscriptanalyzer-changed.json`である。

Yes:
そのままでよい。スクリプト側でディレクトリ作成まで処理する。

No:
無関係な出力先変更は入れない。既知の出力先に戻す。

---

## 検証手順

### ローカル検証
次を実行する。

```powershell
.\scripts\Invoke-ScriptAnalyzerChanged.ps1 `
  -BaseRef HEAD~1 `
  -HeadRef HEAD `
  -FailOnSeverity @('Error') `
  -OutputJsonPath "LOG/psscriptanalyzer-changed.json"
```

成功条件:
- `Argument types do not match` が出ない
- `LOG/psscriptanalyzer-changed.json` が出力される
- 終了結果が本来のPSScriptAnalyzer結果だけで決まる

### workflow検証
GitHub ActionsのPSScriptAnalyzerジョブで次を確認する。

- パラメーター型ログが出ている
- `FailOnSeverity` が配列として渡されている
- `Argument types do not match` が消えている
- 残る失敗がある場合、それは本来の解析結果である

Yes:
修正完了。

No:
このPlaybookの対象外の別原因として追加調査する。

---

## やってはいけないこと
- `runs-on`やactionバージョンを変えて通そうとしない
- `PSScriptAnalyzerSettings.psd1` を変えて通そうとしない
- `paths` フィルターを変えて対象外にしない
- `FailOnSeverity`をWarningなどへ緩和しない
- パラメーター型を実測せず、見た目だけでパラメーターバインド原因と決めつけない
- スクリプト内部の例外スタックを取らずにworkflowだけを直して終わらせない

---

## 正本・関連資料
- `.github/workflows/psscriptanalyzer.yml`
- `scripts/Invoke-ScriptAnalyzerChanged.ps1`
- `PSScriptAnalyzerSettings.psd1`
- [ADR-0014: ScriptAnalyzer 差分チェックの FailOnSeverity を当面 Error のみにする](../adr/0014-psscriptanalyzer-failonseverity-error-only.md)
- [ADR-0018: PSScriptAnalyzer の Path 型差異を吸収するため、差分チェック実装を単一ファイル解析方式に変更する](../adr/0018-scriptanalyzer-single-file-analysis-for-path-type-compatibility.md)
- [ADR-0019: GitHub Actions のドットソース実行経路で ValidateSet パラメーターバインディングの型不一致が起きるため、workflow 側で型を確定させて回避する](../adr/0019-github-actions-dot-source-validateset-parameter-binding.md)
- [ADR-0022: PSScriptAnalyzer 差分チェックの Argument types do not match は結果集約処理を修正し、workflow には型観測ログを追加して再発調査を容易にする](../adr/0022-scriptanalyzer-argument-types-do-not-match-root-cause.md)

---

## この Playbook について
- 再発時は、上から順にそのまま実行する
- 背景判断を確認したい場合だけADRを参照する
- 迷ったときは、まずパラメーター型実測とスクリプト内部スタック取得に戻る