# ObsidianのCopilot(Plugin)

## Index化時のコストをざっくり計算

Copilot Pluginで、OpenAIをAPI越しに利用している。

実際のファイルサイズに基づいてトークン数を推定し、ChatGPT API使用時のコストを見積もるPowerShellスクリプトを作成した。

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
  結果を保存して時系列で追跡可能
  
- **進捗表示とエラー耐性**  
  大規模なVaultでも安心して実行可能

## 使用例

### 基本的な使用

```PowerShell
.\count_md_files_and_estimate_cost.ps1
```

### モデル比較と出力トークンを含めた見積もり

```PowerShell
.\count_md_files_and_estimate_cost.ps1 -ShowModelComparison -OutputTokenRatio 0.5
```

### 実行結果の例

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

