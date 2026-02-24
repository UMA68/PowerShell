# ADR-0012: PSScriptAnalyzer を CI に組み込むタイミングとローカル実行との責務分離

## Status
Accepted

## Context
ADR-0011により、リポジトリ全体に対するPSScriptAnalyzerの実行方針・ルール管理方法・Severityごとの扱いは確定した。

一方で、いつCIで実行するのか、またローカル実行とCI実行でそれぞれ何を責務とするのかについては暗黙の理解に留まっていた。

これらは開発体験と品質保証のバランスに直結するため、明示的な設計判断として切り出す必要があった。

## Decision

### 1. CI における PSScriptAnalyzer の実行タイミング
PSScriptAnalyzerはCI（GitHub Actions）で常に実行する。

ただし、品質ゲートとして失敗扱いにする条件は以下に限定する。

- CIではError / Warningレベルのみを失敗条件とする
- InformationレベルはCIの成否に影響させない

### 2. ローカル実行と CI 実行の責務分離

#### ローカル実行の責務
- 早期フィードバック
- Informationレベルを含めた全警告の把握
- 実装方針・書き方の改善検討

ローカルでの実行は強く推奨するが、強制はしない。

#### CI 実行の責務
- mainブランチの品質を守る最終ゲート
- Error / Warningレベルのみを対象とした合否判定
- 環境差異の排除と再現性の担保

### 3. ルールおよび除外設定の正本
- 正本はPSScriptAnalyzerSettings.psd1とする
- CI / ローカルとも同一設定を使用する
- Severityの解釈のみを分離する

## Consequences

### 👍 良い点
- CIノイズを抑えつつ品質を守れる
- ローカルでの改善余地を確保できる

### 👎 悪い点・割り切り
- Informationを無視してもCIは通る
- 開発者の自律性に依存する

## Revisit
- 品質ゲートを厳格化する場合
- ルールセットやSeverity方針を変更する場合

## Notes
- CIを教育の場にしない判断は開発体験を優先した結果
