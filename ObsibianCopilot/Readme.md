# ObsidianのCopilot(Plugin)

## Index化時のコストをざっくり計算

Copilot Pluginで、OpenAIをAPI越しに利用している。

実際のファイルサイズに基づいてトークン数を推定し、ChatGPT API使用時のコストを見積もるPowerShellスクリプトです。

## 主な機能

- **実ファイルサイズベースの正確なトークン推定**  
  固定値ではなく、実際のファイルサイズから計算
  
- **入力・出力トークンの個別コスト計算**  
  `-OutputTokenRatio` パラメーターで出力トークン比率を指定可能
  
- **複数GPTモデルのコスト比較**  
  GPT-4o、GPT-4o-mini、GPT-3.5-turboの3モデルを同時比較
  
- **ディレクトリ別統計表示**  
  どのフォルダーがもっとも容量を消費しているか把握可能
  
- **不要フォルダーの自動除外**  
  `.obsidian`、`.git`、`.trash`などのメタデータフォルダーを除外
  
- **CSV/JSON形式でのエクスポート**  
  結果を保存して時系列で追跡可能（TopDirectories/TopFilesも含む）
  
- **進捗表示とエラー耐性**  
  100ファイルごとに件数＋パーセンテージ表示、終了時は必ず総括を表示

- **非対話実行オプション**  
  `-NoKeyWait`で終了時のキー待機を無効化（タスクスケジューラ向け）

- **除外フォルダー判定の精度向上**  
  ディレクトリ境界を考慮した正規表現で誤検知を防止

## 使用例

### 基本的な使用

```PowerShell
.\count_md_files_and_estimate_cost.ps1
```

### モデル比較と出力トークンを含めた見積もり

```PowerShell
.\count_md_files_and_estimate_cost.ps1 -ShowModelComparison -OutputTokenRatio 0.5 -NoKeyWait
```

### 実行結果の例（サンプル）

```PowerShell
===== Analysis Results =====
Markdown files found: 1112
Total size: 10.85 MB
Average file size: 9.99 KB

Estimated input tokens: 2,891,200
Estimated output tokens: 1,445,600
Estimated total tokens: 4,336,800

Estimated input cost (USD): $0.0072
Estimated output cost (USD): $0.0434
Estimated total cost (USD): $0.0506

===== Model Cost Comparison =====
GPT-4o: $0.0506 (Input: $0.0072 + Output: $0.0434)
GPT-4o-mini: $0.0130 (Input: $0.0043 + Output: $0.0087)
GPT-3.5-turbo: $0.0361 (Input: $0.0145 + Output: $0.0217)

===== Directory Statistics =====
  技術メモ: 456 files, 4.23 MB
  プロジェクト: 234 files, 2.15 MB
  日記: 189 files, 1.87 MB
  学習ノート: 156 files, 1.52 MB
  アイデア: 77 files, 1.08 MB

Top 10 largest files:
  245.67 KB - C:\Users\...\技術メモ\データベース設計.md
  198.34 KB - C:\Users\...\プロジェクト\要件定義.md
  ...

エクスポート（JSON/CSV）には、Top 5のディレクトリ統計とTop Nファイル（サイズとパス）も含まれます。
```

## コスト見積もりの精度

実際にObsidianでインデックス作成を実施し、OpenAIのサイトで確認したところ、  
スクリプトの見積もりと実コストの誤差は約±10%程度で、実用的な精度を確保している。

ファイルサイズからトークン数への変換式：

```text
トークン数 = (ファイルサイズ(bytes) ÷ 2) ÷ CharsPerToken
```

※ UTF-8で日本語は平均2-3バイト/文字と想定

## 価格情報（2024年時点）

| モデル | 入力価格 | 出力価格 |
|--------|---------|---------|
| GPT-4o | $2.50/1M tokens | $10.00/1M tokens |
| GPT-4o-mini | $0.15/1M tokens | $0.60/1M tokens |
| GPT-3.5-turbo | $0.50/1M tokens | $1.50/1M tokens |

## スクリプトの場所

`ObsibianCopilot\QA登録時かかるコストをざっくり予測\count_md_files_and_estimate_cost.ps1`

詳細なヘルプは以下で確認可能：

```PowerShell
Get-Help .\count_md_files_and_estimate_cost.ps1 -Full
```

### よく使うオプション例

```PowerShell
# 非対話（キー待機なし）で実行
.\count_md_files_and_estimate_cost.ps1 -NoKeyWait

# JSONで詳細を書き出し（TopFiles/TopDirectories含む）
.\count_md_files_and_estimate_cost.ps1 -ExportToFile .\result.json -NoKeyWait

# モデル比較＋出力トークン30%想定＋CSV出力
.\count_md_files_and_estimate_cost.ps1 -ShowModelComparison -OutputTokenRatio 0.3 -ExportToFile .\result.csv

# 情報メッセージを必ず表示（InformationAction）
.\count_md_files_and_estimate_cost.ps1 -InformationAction Continue
```

### 価格プリセットとモデル別試算

スクリプトは柔軟に価格を指定できます（`-CostPerMillionTokens`）。よく使うモデル別のプリセット値は以下です。`-PricingProfile` を指定した場合、`-CostPerMillionTokens` の値は上書きされます。

- GPT-4o: 入力 `$2.50/1M tokens`、出力 `$10.00/1M tokens`
- GPT-4o-mini: 入力 `$0.15/1M tokens`、出力 `$0.60/1M tokens`
- GPT-3.5-turbo: 入力 `$0.50/1M tokens`、出力 `$1.50/1M tokens`

モデル別の簡易指定例（入力価格プリセットを使用し、出力は `-OutputTokenRatio` に応じて自動算出。出力コストは入力単価の3倍で計算）:

```PowerShell
# GPT-4o（入力$2.50）で試算（PricingProfile推奨）
.\count_md_files_and_estimate_cost.ps1 -PricingProfile gpt-4o -OutputTokenRatio 0.5

# GPT-4o-mini（入力$0.15）で試算
.\count_md_files_and_estimate_cost.ps1 -PricingProfile 4o-mini -OutputTokenRatio 0.5 -ShowModelComparison

# GPT-3.5-turbo（入力$0.50）で試算
.\count_md_files_and_estimate_cost.ps1 -PricingProfile gpt-3.5 -OutputTokenRatio 0.3
```

補足:

- `-ShowModelComparison`を有効にすると、各モデルの入力・出力価格テーブル（固定）を使って合計コストを同時比較します。
- 個別（単一モデル）での試算は、`-CostPerMillionTokens`と`-OutputTokenRatio`で調整してください。

### 制約事項

- エクスポート拡張子は`.csv`または`.json`のみ対応
- トークン推定はファイルサイズ基準の概算であり、内容や言語で±10%程度の誤差が生じる可能性があります
- 大量ファイル処理時は実行時間が長くなる場合があります
- Obsidian Vaultのパスは適宜変更してください
- スクリプトはPowerShell 5.0+ で動作（Windows PowerShell / PowerShell 7系で確認）
- YAML設定ファイルはサポートしていません
- 出力トークン比率を指定しない場合（デフォルト0）は入力トークンのみ計算
- `-ShowTopFiles` は最大 1000 まで指定可能
- ディレクトリ除外は境界を考慮した正規表現で判定（`.obsidian` / `.git` / `.trash` が既定）
