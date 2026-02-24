<#
.SYNOPSIS
  PowerShell リポジトリ公開前の簡易監査ゲート。

.DESCRIPTION
  このスクリプトは、リポジトリ公開前に最低限チェックしておきたい「地雷」を機械的に洗い出します。
  主な観点は次のとおりです。
    - 実在メールアドレス／社内ドメイン（※具体値はパラメーターで与える）
    - password / token / secret など「それっぽい」キーワード
    - ユーザー名・マシン名を含む絶対パス（C:\Users\..., /Users/..., UNC パスなど）
    - HOSTNAME / COMPUTERNAME などの環境情報の漏洩
    - testResults.xml や LOG/*.xml など、テスト結果・ログのコミット

  IMPORTANT（クリーンルーム前提）:
    - このスクリプトの中に、会社名・会社ドメイン・内部 URL・機密キーワードをハードコードしてはいけません。
    - 組織固有のパターンは、パラメーターや環境変数から与えてください。

  終了コード:
    0 = 監査 OK（検出なし）
    1 = 監査 NG（1件以上の検出あり）

.REQUIRES
  PowerShell 7+ 推奨。Windows PowerShell 5.1 でも基本動作はしますが、一部の挙動が異なる可能性があります。

.PARAMETER RepoRoot
  監査対象のリポジトリルート。既定値はカレントディレクトリ。

.PARAMETER ForbiddenDomainRegex
  （任意）禁止したいドメインを表す正規表現。
  例: '@(example\\.co\\.jp)$' など。
  パラメーター、または環境変数 FORBIDDEN_DOMAIN_REGEX で与えます。

.PARAMETER AllowEmailDomainRegex
  （任意）サンプルとして許可するメールドメインの正規表現。
  既定値: example.com / example.jp / example.org のみ許可。

.PARAMETER AllowedPathRegex
  （任意）絶対パスであっても許可したいパスの正規表現。
  CI 環境など、あらかじめ非機密と判断しているパスを除外する用途。

.PARAMETER IncludeGlobs
  スキャン対象とするファイルのグロブパターン。
  既定値: .ps1, .psm1, .psd1, .md, .txt, .yml, .yaml, .json, .xml, .sql, .csv

.PARAMETER ExcludeGlobs
  スキャン対象から除外するパスのグロブパターン。

.PARAMETER UseRipgrep
  指定された場合、rg コマンドが見つかれば優先的に使用します（高速化目的）。

.EXAMPLE
  pwsh ./audit-prepublic.ps1 -ForbiddenDomainRegex '@(example\\.co\\.jp)$'

.EXAMPLE
  $env:FORBIDDEN_DOMAIN_REGEX='@(example\\.co\\.jp)$'
  pwsh ./audit-prepublic.ps1
#>

[CmdletBinding()]
param(
  [Parameter()] [string]$RepoRoot = (Get-Location).Path,
  [Parameter()] [string]$ForbiddenDomainRegex = $env:FORBIDDEN_DOMAIN_REGEX,
  [Parameter()] [string]$AllowEmailDomainRegex = '^(example\\.com|example\\.jp|example\\.org)$',
  [Parameter()] [string]$AllowedPathRegex = $env:ALLOWED_PATH_REGEX,
  [Parameter()] [string[]]$IncludeGlobs = @('**/*.ps1','**/*.psm1','**/*.psd1','**/*.md','**/*.txt','**/*.yml','**/*.yaml','**/*.json','**/*.xml','**/*.sql','**/*.csv'),
  [Parameter()] [string[]]$ExcludeGlobs = @('**/.git/**','**/bin/**','**/obj/**','**/.vs/**','**/.vscode/**','**/node_modules/**','**/.venv/**','**/__pycache__/**'),
  [Parameter()] [switch]$UseRipgrep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Finding {
  param(
    [ValidateSet('CRITICAL','WARNING','INFO')] [string]$Severity,
    [string]$Rule,
    [string]$File,
    [int]$Line,
    [string]$Text
  )
  [PSCustomObject]@{
    Severity = $Severity
    Rule     = $Rule
    File     = $File
    Line     = $Line
    Text     = $Text
  }
}

function Test-CommandExists([string]$Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-TargetFiles {
  param([string]$Root)

  # Get-ChildItem で全ファイルを取得し、拡張子ベースでフィルタリングします。
  $all = Get-ChildItem -Path $Root -Recurse -File -Force -ErrorAction SilentlyContinue

  $excluded = New-Object System.Collections.Generic.HashSet[string]
  foreach ($g in $ExcludeGlobs) {
    foreach ($f in $all) {
      # よくあるパターンだけ簡易に除外（完全なグロブ実装ではなく「実用優先」）
      if ($g -like '**/.git/**' -and $f.FullName -match '\\|/' ) {
        if ($f.FullName -match '([\\/])\\.git([\\/])') { $excluded.Add($f.FullName) | Out-Null }
      }
      elseif ($g -like '**/bin/**' -and $f.FullName -match '([\\/])bin([\\/])') { $excluded.Add($f.FullName) | Out-Null }
      elseif ($g -like '**/obj/**' -and $f.FullName -match '([\\/])obj([\\/])') { $excluded.Add($f.FullName) | Out-Null }
      elseif ($g -like '**/node_modules/**' -and $f.FullName -match '([\\/])node_modules([\\/])') { $excluded.Add($f.FullName) | Out-Null }
      elseif ($g -like '**/.vscode/**' -and $f.FullName -match '([\\/])\\.vscode([\\/])') { $excluded.Add($f.FullName) | Out-Null }
      elseif ($g -like '**/.vs/**' -and $f.FullName -match '([\\/])\\.vs([\\/])') { $excluded.Add($f.FullName) | Out-Null }
      elseif ($g -like '**/.venv/**' -and $f.FullName -match '([\\/])\\.venv([\\/])') { $excluded.Add($f.FullName) | Out-Null }
      elseif ($g -like '**/__pycache__/**' -and $f.FullName -match '([\\/])__pycache__([\\/])') { $excluded.Add($f.FullName) | Out-Null }
    }
  }

  # 拡張子でシンプルにフィルタ（バイナリを避ける目的）
  $extAllow = @('.ps1','.psm1','.psd1','.md','.txt','.yml','.yaml','.json','.xml','.sql','.csv')
  $targets = $all | Where-Object { $extAllow -contains $_.Extension.ToLowerInvariant() } | Where-Object { -not $excluded.Contains($_.FullName) }
  return $targets
}

function Scan-WithSelectString {
  param(
    [System.IO.FileInfo[]]$Files,
    [string]$Regex,
    [string]$Rule,
    [ValidateSet('CRITICAL','WARNING','INFO')] [string]$Severity,
    [switch]$SkipIfEmpty
  )

  if ($SkipIfEmpty -and [string]::IsNullOrWhiteSpace($Regex)) { return @() }

  $findings = @()
  foreach ($f in $Files) {
    try {
      $matches = Select-String -Path $f.FullName -Pattern $Regex -AllMatches -Encoding UTF8 -ErrorAction SilentlyContinue
      foreach ($m in $matches) {
        $findings += Write-Finding -Severity $Severity -Rule $Rule -File (Resolve-Path $f.FullName).Path -Line $m.LineNumber -Text $m.Line.Trim()
      }
    } catch {
      # バイナリなど読み取れないファイルは黙ってスキップ
    }
  }
  return $findings
}

function Scan-WithRipgrep {
  param(
    [string]$Root,
    [string]$Regex,
    [string]$Rule,
    [ValidateSet('CRITICAL','WARNING','INFO')] [string]$Severity,
    [switch]$SkipIfEmpty
  )

  if ($SkipIfEmpty -and [string]::IsNullOrWhiteSpace($Regex)) { return @() }
  $findings = @()
  $cmd = @('rg','-n','--hidden','--no-heading','--color','never','-uu','-P',$Regex,$Root)
  # 除外パターンは .gitignore と ExcludeGlobs に任せて簡素化
  $out = & $cmd 2>$null
  if (-not $out) { return @() }
  foreach ($line in $out) {
    # 出力形式: file:line:match
    $parts = $line -split ':',3
    if ($parts.Count -ge 3) {
      $findings += Write-Finding -Severity $Severity -Rule $Rule -File $parts[0] -Line ([int]$parts[1]) -Text ($parts[2].Trim())
    }
  }
  return $findings
}

function Assert-NoFindings {
  param([object[]]$Findings)
  if ($Findings.Count -eq 0) { return }

  $grouped = $Findings | Group-Object Severity | Sort-Object Name
  foreach ($g in $grouped) {
    $color = if ($g.Name -eq 'CRITICAL') {'Red'} elseif ($g.Name -eq 'WARNING') {'Yellow'} else {'Gray'}
    Write-Host "\n[$($g.Name)] $($g.Count) 件" -ForegroundColor $color
    $g.Group | Select-Object Severity,Rule,File,Line,Text | Format-Table -AutoSize | Out-String | Write-Host
  }

  throw "公開前監査で $($Findings.Count) 件の指摘が見つかりました。"
}

# --- ルール定義 ---

# (A) 禁止ドメイン（実行時に与える）
#     例: -ForbiddenDomainRegex '@(example\\.co\\.jp)$'
$emailRegex = '(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})(?![A-Za-z0-9._%+-])'

# (B) 絶対パス／ユーザー・マシン名を含むパス
$absPathRegex = 'C:\\Users\\|/Users/|/home/|\\\\[A-Za-z0-9._-]+\\[A-Za-z0-9._-]+'
$hostEnvRegex = '(?i)DESKTOP-|LAPTOP-|WIN-|HOSTNAME\b|COMPUTERNAME\b|USERPROFILE\b'

# (C) secret っぽいキーワード（ヒューリスティック）
$secretsRegex = '(?i)\b(password|passwd|pwd|api[_-]?key|token|secret|connectionstring|connstr|credential)\b'

# (D) テスト結果・ログのファイル名（コミット禁止対象）
$artifactFileRegex = '(?i)(testresults\.xml$|alltests-report\.xml$|releaseprocess-test\.xml$)'

$scanWithRg = $UseRipgrep -and (Test-CommandExists 'rg')
$files = Get-TargetFiles -Root $RepoRoot

$findings = New-Object System.Collections.Generic.List[object]

# 1) 禁止ドメインの直接ヒット
if ($scanWithRg) {
  $findings.AddRange((Scan-WithRipgrep -Root $RepoRoot -Regex $ForbiddenDomainRegex -Rule 'ForbiddenDomain' -Severity 'CRITICAL' -SkipIfEmpty:$true))
} else {
  $findings.AddRange((Scan-WithSelectString -Files $files -Regex $ForbiddenDomainRegex -Rule 'ForbiddenDomain' -Severity 'CRITICAL' -SkipIfEmpty:$true))
}

# 2) メールアドレス検出 → 許可ドメインかどうか判定
$emailHits = if ($scanWithRg) {
  Scan-WithRipgrep -Root $RepoRoot -Regex $emailRegex -Rule 'EmailAddress' -Severity 'WARNING'
} else {
  Scan-WithSelectString -Files $files -Regex $emailRegex -Rule 'EmailAddress' -Severity 'WARNING'
}

foreach ($h in $emailHits) {
  if ($h.Text -match $emailRegex) {
    $domain = $Matches[1]
    if ($domain -notmatch $AllowEmailDomainRegex) {
      $sev = 'WARNING'
      if (-not [string]::IsNullOrWhiteSpace($ForbiddenDomainRegex) -and ($h.Text -match $ForbiddenDomainRegex)) { $sev = 'CRITICAL' }
      $findings.Add((Write-Finding -Severity $sev -Rule 'EmailAddressNotAllowlisted' -File $h.File -Line $h.Line -Text $h.Text))
    }
  }
}

# 3) 絶対パスとホスト／環境情報
$pathHits = if ($scanWithRg) {
  Scan-WithRipgrep -Root $RepoRoot -Regex $absPathRegex -Rule 'AbsolutePath' -Severity 'CRITICAL'
} else {
  Scan-WithSelectString -Files $files -Regex $absPathRegex -Rule 'AbsolutePath' -Severity 'CRITICAL'
}
foreach ($h in $pathHits) {
  if (-not [string]::IsNullOrWhiteSpace($AllowedPathRegex) -and ($h.Text -match $AllowedPathRegex)) { continue }
  $findings.Add($h)
}

$findings.AddRange((($scanWithRg) ? (Scan-WithRipgrep -Root $RepoRoot -Regex $hostEnvRegex -Rule 'HostEnvLeak' -Severity 'WARNING') : (Scan-WithSelectString -Files $files -Regex $hostEnvRegex -Rule 'HostEnvLeak' -Severity 'WARNING')))

# 4) secret っぽいキーワード（警告扱い）
$findings.AddRange((($scanWithRg) ? (Scan-WithRipgrep -Root $RepoRoot -Regex $secretsRegex -Rule 'SecretsKeyword' -Severity 'WARNING') : (Scan-WithSelectString -Files $files -Regex $secretsRegex -Rule 'SecretsKeyword' -Severity 'WARNING')))

# 5) テスト／ログ成果物がリポジトリに含まれていないか
foreach ($f in $files) {
  if ($f.FullName -match $artifactFileRegex) {
    $findings.Add((Write-Finding -Severity 'CRITICAL' -Rule 'CommittedArtifact' -File $f.FullName -Line 0 -Text 'テスト結果 XML は Git 管理せず、CI の成果物などで扱ってください。'))
  }
  if ($f.FullName -match '(?i)([\\/])LOG[\\/].*\.xml$') {
    $findings.Add((Write-Finding -Severity 'CRITICAL' -Rule 'CommittedLogXml' -File $f.FullName -Line 0 -Text 'LOG/*.xml はユーザー名・パスなどを含む可能性があるため、コミットしないでください。'))
  }
}

try {
  Assert-NoFindings -Findings $findings
  Write-Host "\n✅ 公開前監査: 問題は検出されませんでした" -ForegroundColor Green
  exit 0
} catch {
  Write-Host "\n❌ 公開前監査: 修正が必要な項目があります" -ForegroundColor Red
  exit 1
}
