<#
.SYNOPSIS
    Integration-like unit tests for sqlMain.ps1.

.DESCRIPTION
    These tests execute sqlMain.ps1 in-process using a temporary project layout.
    File system behavior is real (YAML/SQL/LOG), while DB and external dependencies
    are mocked for deterministic CI execution.
#>

Describe 'sqlMain.ps1' -Tag 'Unit', 'SQL', 'Integration' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:SourceScriptPath = Join-Path $script:RepoRoot 'SQLクエリー実行\Script\sqlMain.ps1'

        if (-not (Test-Path $script:SourceScriptPath)) {
            throw "Target script not found: $script:SourceScriptPath"
        }

        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PSSqlMainTest_$(New-Guid)"
        $script:PowerShellRoot = Join-Path $script:TestRoot 'PowerShell'
        $script:SqlProjectRoot = Join-Path $script:PowerShellRoot 'SQLクエリー実行'

        $script:CommonDir = Join-Path $script:PowerShellRoot 'Common'
        $script:ScriptDir = Join-Path $script:SqlProjectRoot 'Script'
        $script:YamlDir = Join-Path $script:SqlProjectRoot 'YAML'
        $script:SqlDir = Join-Path $script:SqlProjectRoot 'SQL'
        $script:LogDir = Join-Path $script:SqlProjectRoot 'LOG'

        @(
            $script:CommonDir,
            $script:ScriptDir,
            $script:YamlDir,
            $script:SqlDir,
            $script:LogDir
        ) | ForEach-Object {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
        }

        # sqlMain.ps1 has interactive key-read calls at end; neutralize only in test copy.
        $copiedScript = Get-Content -Path $script:SourceScriptPath -Raw -Encoding UTF8
        $copiedScript = $copiedScript -replace [regex]::Escape('$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null'), 'Write-Information "ReadKey is skipped in tests."'
        $script:TestScriptPath = Join-Path $script:ScriptDir 'sqlMain.ps1'
        Set-Content -Path $script:TestScriptPath -Value $copiedScript -Encoding UTF8

        # Provide minimal Common scripts, then dot-source them for Mock targets.
        $script:NoDoubleActivationPath = Join-Path $script:CommonDir 'NoDoubleActivation.ps1'
        $script:CheckCommandPath = Join-Path $script:CommonDir 'CheckCommand.ps1'

        Set-Content -Path $script:NoDoubleActivationPath -Encoding UTF8 -Value @'
function Test-NoDoubleActivation {
    param([string]$Thread = 'sqlMain')
    return $true
}
'@

        Set-Content -Path $script:CheckCommandPath -Encoding UTF8 -Value @'
function Test-Command {
    param([string]$ComName = 'nkf32')
    return $true
}
'@

        . $script:NoDoubleActivationPath
        . $script:CheckCommandPath

        <#
        .SYNOPSIS
            テスト用の YAML 設定オブジェクトを生成して返す。
        #>
        function script:New-YamlObject {
            return [ordered]@{
                PowerShell = [ordered]@{
                    Version = ($PSVersionTable.PSVersion).ToString()
                }
                Module = [ordered]@{
                    'Powershell-Yaml' = [ordered]@{
                        Name = 'Powershell-Yaml'
                        Version = '0.4.7'
                    }
                    'SqlServer' = [ordered]@{
                        Name = 'SqlServer'
                        Version = '22.1.1'
                    }
                }
                HOST = [ordered]@{
                    SERVER = '127.0.0.1'
                    PORT = 11433
                    DATABASE = 'appdb'
                    USERNAME = 'sa'
                    PWF = 'test-db.pass'
                    VERSION = 'Microsoft SQL Server 2022 (RTM-CU5)'
                }
                LOG = [ordered]@{
                    FOLDER = 'LOG'
                    FILENAME = 'log'
                    EXTENSION = '.log'
                }
                RELEASE = [ordered]@{
                    SQL = [ordered]@{
                        FolderBy = @('SQL')
                    }
                }
            }
        }

        <#
        .SYNOPSIS
            テストプロジェクトの SQL・LOG・YAML・パスファイルを初期状態にリセットする。
        #>
        function script:Reset-TestProject {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'テスト用の既知パスワードを暗号化してパスファイルを作成するため')]
            param()
            Get-ChildItem -Path $script:SqlDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $script:LogDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

            Set-Content -Path (Join-Path $script:YamlDir 'sql.yaml') -Value "Project: Test`n" -Encoding UTF8

            Set-Content -Path (Join-Path $script:SqlDir 'test1.sql') -Value 'SELECT 1 AS Value1;' -Encoding UTF8
            Set-Content -Path (Join-Path $script:SqlDir 'test2.sql') -Value 'SELECT 2 AS Value2;' -Encoding UTF8

            [byte[]]$keyBytes = 1..16
            [System.IO.File]::WriteAllBytes((Join-Path $script:CommonDir 'Encryption.Key'), $keyBytes)
            $secure = ConvertTo-SecureString -String 'P@ssw0rd!' -AsPlainText -Force
            $encryptedText = ConvertFrom-SecureString -SecureString $secure -Key $keyBytes
            Set-Content -Path (Join-Path $script:SqlProjectRoot 'test-db.pass') -Value $encryptedText -Encoding UTF8

            $script:CurrentYamlObject = New-YamlObject
        }

        <#
        .SYNOPSIS
            テスト用ログディレクトリ内で最新の .log ファイルのパスを返す。
        #>
        function script:Get-LatestLogPath {
            $log = Get-ChildItem -Path $script:LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($null -eq $log) {
                return $null
            }
            return $log.FullName
        }

        <#
        .SYNOPSIS
            Popup を即時 return するテスト用 WScript.Shell 代替オブジェクトを返す。
        #>
        function script:New-WScriptShellMock {
            $shell = [PSCustomObject]@{}
            $shell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
                param($message, $timeout, $title, $icon)

                $script:PopupCalls += [PSCustomObject]@{
                    Message = $message
                    Timeout = $timeout
                    Title = $title
                    Icon = $icon
                }

                return 1
            }

            return $shell
        }

        <#
        .SYNOPSIS
            テスト用に sqlMain.ps1 をドットソースで実行し、出力を返す。
        #>
        function script:Invoke-TestSqlMain {
            param(
                [string]$DecryptionKey = 'Encryption.Key',
                [string]$EnvYaml = 'sql.yaml'
            )

            . $script:TestScriptPath -DecryptionKey $DecryptionKey -EnvYaml $EnvYaml *>&1
        }
    }

    AfterAll {
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force
        }
    }

    BeforeEach {
        Reset-TestProject
        $script:PopupCalls = @()

        Mock Test-NoDoubleActivation { $true }
        Mock Test-Command { $true }
        Mock New-Object {
            New-WScriptShellMock
        } -ParameterFilter { $ComObject -eq 'WScript.Shell' }

        Mock ConvertTo-SecureString {
            $secure = New-Object System.Security.SecureString
            foreach ($ch in 'UnitTestPassword!'.ToCharArray()) {
                $secure.AppendChar($ch)
            }
            $secure.MakeReadOnly()
            return $secure
        }

        Mock Microsoft.PowerShell.Security\ConvertTo-SecureString {
            $secure = New-Object System.Security.SecureString
            foreach ($ch in 'UnitTestPassword!'.ToCharArray()) {
                $secure.AppendChar($ch)
            }
            $secure.MakeReadOnly()
            return $secure
        }

        Mock Get-Module {
            [PSCustomObject]@{ Name = 'PowerShell-Yaml' }
        } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShell-Yaml' }

        Mock ConvertFrom-Yaml {
            return $script:CurrentYamlObject
        }

        Mock Import-Module {}

        Mock nkf32 {
            if ($args.Count -ge 1 -and $args[0] -eq '--guess') {
                return 'UTF-8 (CRLF)'
            }

            if ($args -contains '-O') {
                $sourcePath = $args[$args.Count - 2]
                $targetPath = $args[$args.Count - 1]
                Copy-Item -Path $sourcePath -Destination $targetPath -Force
            }
        }

        Mock Invoke-Sqlcmd {
            return @([PSCustomObject]@{ Result = 'ok' })
        }

        Mock Invoke-Item {}
    }

    Context 'Parameter validation' {
        It 'throws when EnvYaml has invalid extension' {
            { Invoke-TestSqlMain -EnvYaml 'invalid.txt' } | Should -Throw
        }

        It 'throws when DecryptionKey includes invalid filename chars' {
            { Invoke-TestSqlMain -DecryptionKey 'bad:key.key' } | Should -Throw
        }
    }

    Context 'Prerequisite checks' {
        It 'stops when double-activation check fails' {
            Mock Test-NoDoubleActivation { $false }

            Invoke-TestSqlMain | Out-Null

            Should -Invoke Test-NoDoubleActivation -Times 1
            Should -Invoke Invoke-Sqlcmd -Times 0
        }

        It 'shows popup and stops when nkf32 command check fails' {
            Mock Test-Command { $false }

            Invoke-TestSqlMain | Out-Null

            Should -Invoke New-Object -Times 1 -ParameterFilter { $ComObject -eq 'WScript.Shell' }
            Should -Invoke Invoke-Sqlcmd -Times 0
        }
    }

    Context 'YAML loading and module import' {
        It 'loads YAML and imports required modules before SQL execution' {
            Invoke-TestSqlMain | Out-Null

            Should -Invoke ConvertFrom-Yaml -Times 1
            Should -Invoke Import-Module -Times 2
            Should -Invoke Invoke-Sqlcmd -Times 2

            $logPath = Get-LatestLogPath
            $logPath | Should -Not -BeNullOrEmpty
            (Get-Content -Path $logPath -Raw -Encoding UTF8) | Should -Match 'Server:\s+127\.0\.0\.1,11433'
        }
    }

    Context 'Key file and password decryption' {
        It 'stops before SQL execution when key file is missing' {
            Remove-Item -Path (Join-Path $script:CommonDir 'Encryption.Key') -Force
            Mock Write-Error {}

            Invoke-TestSqlMain | Out-Null

            Should -Invoke Invoke-Sqlcmd -Times 0
        }

        It 'stops before SQL execution when encrypted password file is missing' {
            Remove-Item -Path (Join-Path $script:SqlProjectRoot 'test-db.pass') -Force

            Invoke-TestSqlMain | Out-Null

            Should -Invoke Invoke-Sqlcmd -Times 0
        }
    }

    Context 'SQL folder and file detection' {
        It 'stops when SQL folder configured in YAML does not exist' {
            $script:CurrentYamlObject.RELEASE.SQL.FolderBy = @('SQL_NOT_FOUND')

            Invoke-TestSqlMain | Out-Null

            Should -Invoke Invoke-Sqlcmd -Times 0

            $logPath = Get-LatestLogPath
            $logPath | Should -Not -BeNullOrEmpty
            (Get-Content -Path $logPath -Raw -Encoding UTF8) | Should -Match 'SQLフォルダ'
        }

        It 'stops when SQL folder has no .sql files' {
            Get-ChildItem -Path $script:SqlDir -File | Remove-Item -Force

            Invoke-TestSqlMain | Out-Null

            Should -Invoke Invoke-Sqlcmd -Times 0

            $logPath = Get-LatestLogPath
            $logPath | Should -Not -BeNullOrEmpty
            (Get-Content -Path $logPath -Raw -Encoding UTF8) | Should -Match '\.sqlファイル'
        }
    }

    Context 'SQL execution and log output' {
        It 'continues processing when one SQL file fails and writes summary' {
            Mock Invoke-Sqlcmd {
                if ($InputFile -like '*test2.sql') {
                    throw [System.InvalidOperationException]::new('Simulated SQL execution failure')
                }
                return @([PSCustomObject]@{ Result = 'ok' })
            }

            Invoke-TestSqlMain | Out-Null

            Should -Invoke Invoke-Sqlcmd -Times 2
            Should -Invoke Invoke-Item -Times 1

            $logPath = Get-LatestLogPath
            $logPath | Should -Not -BeNullOrEmpty
            $logText = Get-Content -Path $logPath -Raw -Encoding UTF8
            $logText | Should -Match '実行完了: 合計 2 件 \(成功: 1 件, エラー: 1 件\)'
            $logText | Should -Match '成功率: 50'
            $logText | Should -Match 'Error Type:'
        }

        It 'creates and deletes temporary UTF-8 files when encoding conversion is required' {
            Mock nkf32 {
                if ($args.Count -ge 1 -and $args[0] -eq '--guess') {
                    if ($args[1] -like '*test1.sql') {
                        return 'Shift_JIS (CRLF)'
                    }
                    return 'UTF-8 (CRLF)'
                }

                if ($args -contains '-O') {
                    $sourcePath = $args[$args.Count - 2]
                    $targetPath = $args[$args.Count - 1]
                    Copy-Item -Path $sourcePath -Destination $targetPath -Force
                }
            }

            Invoke-TestSqlMain | Out-Null

            $temporaryFiles = Get-ChildItem -Path $script:SqlDir -Filter '*.utf8(CRLF)' -File -ErrorAction SilentlyContinue
            @($temporaryFiles).Count | Should -Be 0
            Should -Invoke nkf32 -Times 3
        }
    }
}
