Describe 'audit-prepublic.ps1' -Tag 'Unit' {
    BeforeAll {
        # テスト対象スクリプトのパスを決定（Tests/ 直下から想定）
        $scriptPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ChildPath 'audit-prepublic.ps1'
        if (-not (Test-Path $scriptPath)) {
            throw "audit-prepublic.ps1 が見つかりません。パスを確認してください: $scriptPath"
        }
        Set-Variable -Name 'AuditScriptPath' -Scope Script -Value (Resolve-Path $scriptPath).Path
    }

    It 'クリーンなリポジトリでは終了コード 0 を返す' {
        # TestDrive: に空のリポジトリを用意
        Remove-Item -Path 'TestDrive:\*' -Recurse -Force -ErrorAction SilentlyContinue
        $repoRoot = (Get-Item 'TestDrive:\').FullName

        # Forbidden ドメインは未指定
        Remove-Item Env:FORBIDDEN_DOMAIN_REGEX -ErrorAction SilentlyContinue

        $null = & pwsh -NoProfile -File $Script:AuditScriptPath -RepoRoot $repoRoot

        $LASTEXITCODE | Should -Be 0
    }

    It 'Forbidden ドメインを含むメールアドレスがあれば終了コード 1 (CRITICAL) になる' {
        Remove-Item -Path 'TestDrive:\*' -Recurse -Force -ErrorAction SilentlyContinue
        $repoRoot = (Get-Item 'TestDrive:\').FullName

        # Forbidden ドメインを環境変数で指定（example.co.jp はサンプル）
        $env:FORBIDDEN_DOMAIN_REGEX = '@(example\.co\.jp)$'

        # Forbidden ドメインを含むメールアドレスを配置
        $filePath = Join-Path $repoRoot 'forbidden_domain.txt'
        Set-Content -Path $filePath -Value 'contact@example.co.jp' -Encoding UTF8

        $output = & pwsh -NoProfile -File $Script:AuditScriptPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'ForbiddenDomain'
    }

    It '許可されていないメールドメインのみでも終了コード 1 (WARNING) になる' {
        Remove-Item -Path 'TestDrive:\*' -Recurse -Force -ErrorAction SilentlyContinue
        $repoRoot = (Get-Item 'TestDrive:\').FullName

        # Forbidden ドメインは指定しない（AllowEmailDomainRegex のみで判定）
        Remove-Item Env:FORBIDDEN_DOMAIN_REGEX -ErrorAction SilentlyContinue

        # AllowEmailDomainRegex に含まれないドメイン
        $filePath = Join-Path $repoRoot 'not_allowed_mail.txt'
        Set-Content -Path $filePath -Value 'user@not-allowed.com' -Encoding UTF8

        $output = & pwsh -NoProfile -File $Script:AuditScriptPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'EmailAddressNotAllowlisted'
    }

    It '絶対パスを含む行があれば終了コード 1 (AbsolutePath) になる' {
        Remove-Item -Path 'TestDrive:\*' -Recurse -Force -ErrorAction SilentlyContinue
        $repoRoot = (Get-Item 'TestDrive:\').FullName

        Remove-Item Env:FORBIDDEN_DOMAIN_REGEX -ErrorAction SilentlyContinue

        $filePath = Join-Path $repoRoot 'abs_path.txt'
        @(
            'C:\Users\someone\secret.txt'
            '/Users/test/data.txt'
            '\\SERVER01\Share\path.txt'
        ) | Set-Content -Path $filePath -Encoding UTF8

        $output = & pwsh -NoProfile -File $Script:AuditScriptPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'AbsolutePath'
    }

    It 'LOG 配下の *.xml や testResults.xml があれば終了コード 1 (CommittedArtifact/CommittedLogXml) になる' {
        Remove-Item -Path 'TestDrive:\*' -Recurse -Force -ErrorAction SilentlyContinue
        $repoRoot = (Get-Item 'TestDrive:\').FullName

        Remove-Item Env:FORBIDDEN_DOMAIN_REGEX -ErrorAction SilentlyContinue

        # testResults.xml（コミット禁止）
        Set-Content -Path (Join-Path $repoRoot 'testResults.xml') -Value 'dummy' -Encoding UTF8

        # LOG/ 配下の *.xml（コミット禁止）
        $logDir = Join-Path $repoRoot 'LOG'
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $logDir 'operation.log.xml') -Value 'dummy' -Encoding UTF8

        $output = & pwsh -NoProfile -File $Script:AuditScriptPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'CommittedArtifact'
        ($output -join "`n") | Should -Match 'CommittedLogXml'
    }
}