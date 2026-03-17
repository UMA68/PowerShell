<#
.SYNOPSIS
    Git 差分で変更された PowerShell ファイルだけを PSScriptAnalyzer で解析します。

.DESCRIPTION
    BaseRef と HeadRef の差分（git diff --name-status）から追加/変更/リネームを抽出し、
    指定拡張子かつ除外グロブに該当しない既存ファイルのみを解析対象にします。

    失敗条件は -FailOnSeverity で指定した Severity に一致する結果の有無です。

.PARAMETER BaseRef
    差分の基準 ref。既定値は origin/main。

.PARAMETER HeadRef
    差分の比較先 ref。既定値は HEAD。

.PARAMETER IncludeExtensions
    解析対象の拡張子。既定値は .ps1, .psm1, .psd1。

.PARAMETER ExcludeGlobs
    解析対象から除外するグロブ。既定値は Tests/**, docs/**, .github/**, **/*.md など。

.PARAMETER FailOnSeverity
    失敗条件とする Severity。既定値は Error, Warning。

.PARAMETER SettingsPath
    PSScriptAnalyzer 設定ファイルのパス。既定値は ./PSScriptAnalyzerSettings.psd1。

.PARAMETER OutputJsonPath
    任意。指定時は解析結果を JSON 形式で保存します。
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$BaseRef = 'origin/main',

    [Parameter()]
    [string]$HeadRef = 'HEAD',

    [Parameter()]
    [string[]]$IncludeExtensions = @('.ps1', '.psm1', '.psd1'),

    [Parameter()]
    [string[]]$ExcludeGlobs = @(
        'Tests/**',
        'docs/**',
        '.github/**',
        'adr/**',
        '**/*.md',
        '**/*.xml',
        '**/*.lnk',
        '**/LOG/**',
        'LOG/**',
        '.localmodules/**'
    ),

    [Parameter()]
    [ValidateSet('Error', 'Warning', 'Information', 'ParseError')]
    [string[]]$FailOnSeverity = @('Error', 'Warning'),

    [Parameter()]
    [string]$SettingsPath = '.\PSScriptAnalyzerSettings.psd1',

    [Parameter()]
    [string]$OutputJsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    絶対/相対パスを指定ルート基準の相対パスに変換します。
#>
function ConvertTo-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Root
    )

    $resolvedRoot = (Resolve-Path -Path $Root).Path

    $candidatePath = $Path
    if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
        $rootRelativePath = Join-Path -Path $resolvedRoot -ChildPath $candidatePath
        if (Test-Path -LiteralPath $rootRelativePath) {
            $candidatePath = $rootRelativePath
        }
    }

    try {
        $resolvedPath = (Resolve-Path -Path $candidatePath -ErrorAction Stop).Path
    } catch {
        return ($Path -replace '\\', '/').TrimStart([char[]]@('.', '/'))
    }

    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path -replace '\\', '/'
    }

    $relative = $resolvedPath.Substring($resolvedRoot.Length).TrimStart([char[]]@('\', '/'))
    return $relative -replace '\\', '/'
}

<#
.SYNOPSIS
    パスがいずれかのグロブに一致するか判定します。
#>
function Test-MatchGlob {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        if ($Path -like $pattern) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
    Git 差分から解析対象の変更ファイル一覧を取得します。
#>
function Get-ChangedFile {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$Base,

        [Parameter(Mandatory)]
        [string]$Head,

        [Parameter(Mandatory)]
        [string[]]$Extensions,

        [Parameter(Mandatory)]
        [string[]]$ExcludePatterns
    )

    $null = & git -C $RepositoryRoot rev-parse --verify $Base 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "BaseRef '$Base' が見つかりません。ローカル実行では -BaseRef HEAD~1 などを指定してください。"
    }

    $null = & git -C $RepositoryRoot rev-parse --verify $Head 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "HeadRef '$Head' が見つかりません。"
    }

    $diffLines = & git -C $RepositoryRoot diff --name-status --diff-filter=AMR $Base $Head
    if ($LASTEXITCODE -ne 0) {
        throw "git diff の実行に失敗しました。BaseRef='$Base' HeadRef='$Head' を確認してください。"
    }

    $result = New-Object System.Collections.Generic.List[string]

    foreach ($line in $diffLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split "`t"
        if ($parts.Count -lt 2) {
            continue
        }

        $status = $parts[0]
        $relativePath = $parts[1]

        if ($status -like 'R*') {
            if ($parts.Count -lt 3) {
                continue
            }

            $relativePath = $parts[2]
        }

        $normalizedRelativePath = ($relativePath -replace '\\', '/').TrimStart([char[]]@('.', '/'))
        $extension = [System.IO.Path]::GetExtension($normalizedRelativePath)

        if ($Extensions -notcontains $extension.ToLowerInvariant()) {
            continue
        }

        if (Test-MatchGlob -Path $normalizedRelativePath -Patterns $ExcludePatterns) {
            continue
        }

        $fullPath = Join-Path -Path $RepositoryRoot -ChildPath $relativePath
        if (-not (Test-Path -LiteralPath $fullPath)) {
            Write-Warning "存在しないためスキップ: $normalizedRelativePath"
            continue
        }

        $resolved = (Resolve-Path -LiteralPath $fullPath).Path
        if (-not $result.Contains($resolved)) {
            $result.Add($resolved)
        }
    }

    return $result.ToArray()
}

if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
    Write-Error 'git が見つかりません。Git をインストールし、PATH を確認してください。'
    exit 2
}

if (-not (Get-Command -Name Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
    Write-Error 'Invoke-ScriptAnalyzer が見つかりません。Install-Module PSScriptAnalyzer -Scope CurrentUser を実行してください。'
    exit 2
}

$repositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path

$null = & git -C $repositoryRoot rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "git リポジトリとして認識できません: $repositoryRoot"
    exit 2
}

$settingsFullPath = Join-Path -Path $repositoryRoot -ChildPath $SettingsPath
if (-not (Test-Path -LiteralPath $settingsFullPath)) {
    Write-Error "PSScriptAnalyzer 設定ファイルが見つかりません: $settingsFullPath"
    exit 2
}

Write-Host "差分解析: $BaseRef..$HeadRef" -ForegroundColor Cyan
Write-Host "設定ファイル: $settingsFullPath" -ForegroundColor DarkCyan

$changedFiles = @(Get-ChangedFile -RepositoryRoot $repositoryRoot -Base $BaseRef -Head $HeadRef -Extensions ($IncludeExtensions | ForEach-Object { $_.ToLowerInvariant() }) -ExcludePatterns $ExcludeGlobs)

if ($changedFiles.Count -eq 0) {
    Write-Host '解析対象の変更ファイルはありません。' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host '解析対象ファイル:' -ForegroundColor Yellow
$displayTargets = $changedFiles | Sort-Object
foreach ($target in $displayTargets) {
    $relative = ConvertTo-RelativePath -Path $target -Root $repositoryRoot
    Write-Host "  - $relative" -ForegroundColor Gray
}

$analysisResults = New-Object System.Collections.Generic.List[object]
foreach ($targetPath in $displayTargets) {
    $fileResults = Invoke-ScriptAnalyzer -Path $targetPath -Settings $settingsFullPath
    if ($fileResults) {
        foreach ($item in @($fileResults)) {
            $analysisResults.Add($item)
        }
    }
}

$analysisResults = @($analysisResults)

Write-Host ''
Write-Host 'PSScriptAnalyzer 結果:' -ForegroundColor Yellow

if (-not $analysisResults -or $analysisResults.Count -eq 0) {
    Write-Host '  ✅ 問題は見つかりませんでした。' -ForegroundColor Green
}
else {
    $grouped = $analysisResults | Group-Object -Property ScriptName
    foreach ($group in ($grouped | Sort-Object Name)) {
        $relative = ConvertTo-RelativePath -Path $group.Name -Root $repositoryRoot
        Write-Host "`n[$relative]" -ForegroundColor Cyan
        foreach ($item in $group.Group | Sort-Object @{ Expression = { $_.Line }; Ascending = $true }, @{ Expression = { $_.RuleName }; Ascending = $true }) {
            Write-Host ("  {0,-11} L{1,-4} {2} - {3}" -f $item.Severity, $item.Line, $item.RuleName, $item.Message)
        }
    }
}

if ($OutputJsonPath) {
    $jsonTarget = if ([System.IO.Path]::IsPathRooted($OutputJsonPath)) {
        $OutputJsonPath
    }
    else {
        Join-Path -Path $repositoryRoot -ChildPath $OutputJsonPath
    }

    $jsonDir = Split-Path -Path $jsonTarget -Parent
    if (-not [string]::IsNullOrWhiteSpace($jsonDir) -and -not (Test-Path -LiteralPath $jsonDir)) {
        New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
    }

    $analysisResults | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonTarget -Encoding UTF8
    Write-Host "`nJSON 出力: $jsonTarget" -ForegroundColor DarkCyan
}

$failSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($severity in $FailOnSeverity) {
    [void]$failSet.Add($severity)
}

$failingResults = @($analysisResults | Where-Object { $failSet.Contains($_.Severity) })

$summaryBySeverity = @('Error', 'Warning', 'Information', 'ParseError')
Write-Host "`nサマリー:" -ForegroundColor Yellow
foreach ($severity in $summaryBySeverity) {
    $count = @($analysisResults | Where-Object Severity -eq $severity).Count
    if ($count -gt 0) {
        Write-Host ("  {0,-11}: {1}" -f $severity, $count)
    }
}

if ($failingResults.Count -gt 0) {
    Write-Host "`n❌ 失敗: FailOnSeverity に一致する結果が $($failingResults.Count) 件あります。" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ 成功: FailOnSeverity に一致する結果はありません。" -ForegroundColor Green
exit 0
