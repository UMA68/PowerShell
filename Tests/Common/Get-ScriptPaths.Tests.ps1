<#
.SYNOPSIS
    Get-ScriptPaths 関数のユニットテスト

.DESCRIPTION
    Get-ScriptPaths 関数のユニットテスト
    - 正常系: パスが正しく計算されることを検証
    - パラメータ: EnvFileName パラメータの検証
    - 異常系: エラーハンドリングの検証
    - パスの構造: パスの階層関係の検証
    - パス形式: 絶対パスとパス区切り文字の検証

.NOTES
    Author: Test Suite
    Version: 1.1.0
    Last Updated: 2026-01-19
#>

BeforeAll {
    # テスト対象の関数を読み込み
    $commonPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $commonPath 'Common\Get-ScriptPaths.ps1')
    
    # テスト用の一時ディレクトリを作成
    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PSTest_$(New-Guid)"
    $script:TestScriptDir = Join-Path $script:TestRoot 'Script'
    $script:TestYamlDir = Join-Path $script:TestRoot 'YAML'
    
    New-Item -ItemType Directory -Path $script:TestScriptDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestYamlDir -Force | Out-Null
}

AfterAll {
    # テスト用のディレクトリをクリーンアップ
    if (Test-Path $script:TestRoot) {
        Remove-Item -Path $script:TestRoot -Recurse -Force
    }
}

Describe 'Get-ScriptPaths' -Tag 'Unit', 'Common' {
    Context '正常系: パス計算' {
        It 'スクリプトパスからすべての必要なパスを計算する' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result -is [hashtable] | Should -BeTrue
            $result.ContainsKey('Script') | Should -BeTrue
            $result.ContainsKey('Upper') | Should -BeTrue
            $result.ContainsKey('PowerShell') | Should -BeTrue
            $result.ContainsKey('Yaml') | Should -BeTrue
            $result.ContainsKey('Log') | Should -BeTrue
            $result.ContainsKey('Common') | Should -BeTrue
        }
        
        It 'EnvFileName を指定すると EnvFile キーが追加される' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            $envFileName = 'Env.yaml'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath -EnvFileName $envFileName
            
            # Assert
            $result.ContainsKey('EnvFile') | Should -BeTrue
            $result.EnvFile | Should -Match $envFileName
        }
        
        It 'EnvFileName を指定しない場合 EnvFile キーは追加されない' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            $result.ContainsKey('EnvFile') | Should -BeFalse
        }
        
        It 'パスの値がすべて文字列である' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            foreach ($key in $result.Keys) {
                $result[$key] -is [string] | Should -BeTrue
            }
        }
        
        It 'パスが存在するか存在しないかに関わらず動作する' -Tag 'Positive' {
            # Arrange
            $nonExistentPath = Join-Path $script:TestRoot 'NonExistent\Script\test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $nonExistentPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Script | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'パラメータの検証' {
        It 'ScriptPath パラメータはオプション（デフォルト値がある）' -Tag 'Positive' {
            # Act & Assert
            # パラメータなしで実行可能（MyInvocation.MyCommand.Path を使用）
            { Get-ScriptPaths } | Should -Not -Throw
        }
        
        It 'EnvFileName パラメータはオプション' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $testScriptPath } | Should -Not -Throw
        }
        
        It 'EnvFileName に空文字列を指定すると EnvFile キーが追加されない' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath -EnvFileName ''
            
            # Assert
            $result.ContainsKey('EnvFile') | Should -BeFalse
        }
    }
    
    Context '異常系: エラーハンドリング' {
        It 'スクリプトパスが null の場合、エラーが発生する' -Tag 'Negative' {
            # Arrange
            $testScriptPath = $null
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $testScriptPath } | Should -Throw
        }
        
        It 'スクリプトパスが空文字列の場合、エラーが発生する' -Tag 'Negative' {
            # Arrange
            $testScriptPath = ''
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $testScriptPath } | Should -Throw
        }
        
        It 'スクリプトパスが空白文字列のみの場合、エラーが発生する' -Tag 'Negative' {
            # Arrange
            $testScriptPath = '   '
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $testScriptPath } | Should -Throw
        }
    }
    
    Context 'パスの構造' {
        It 'Script, Upper, PowerShell の階層関係が正しい' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            # Script パスは Upper パスを含む
            $result.Script | Should -Match ([regex]::Escape($result.Upper))
            # Upper パスは PowerShell パスを含む
            $result.Upper | Should -Match ([regex]::Escape($result.PowerShell))
        }
        
        It 'Yaml と Log パスが Upper パスの直下である' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            # Yaml パスが Upper/YAML であること
            $expectedYaml = Join-Path $result.Upper 'YAML'
            $result.Yaml | Should -Be $expectedYaml
            
            # Log パスが Upper/LOG であること
            $expectedLog = Join-Path $result.Upper 'LOG'
            $result.Log | Should -Be $expectedLog
        }
        
        It 'Common パスが PowerShell/Common である' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            $expectedCommon = Join-Path $result.PowerShell 'Common'
            $result.Common | Should -Be $expectedCommon
        }
        
        It 'EnvFile パスが Yaml ディレクトリ配下である' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            $envFileName = 'Env.yaml'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath -EnvFileName $envFileName
            
            # Assert
            $expectedEnvFile = Join-Path $result.Yaml $envFileName
            $result.EnvFile | Should -Be $expectedEnvFile
        }
    }
    
    Context 'パス形式' {
        It 'すべてのパスが絶対パスである' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            foreach ($key in $result.Keys) {
                $path = $result[$key]
                [System.IO.Path]::IsPathRooted($path) | Should -BeTrue
            }
        }
        
        It 'パスにバックスラッシュが使用されている' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            # Windows の場合、バックスラッシュが使用される
            if ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) {
                foreach ($key in $result.Keys) {
                    $result[$key] | Should -Match '\\'
                }
            }
        }
    }
    
    Context 'ScriptPath 自動検出' {
        It 'パラメータ未指定で例外が発生しない' -Tag 'Positive' {
            # Act & Assert
            { Get-ScriptPaths } | Should -Not -Throw
        }
        
        It 'パラメータ未指定時の戻り値キー構成が正しい' -Tag 'Positive' {
            # Act
            $result = Get-ScriptPaths
            
            # Assert
            $result.ContainsKey('Script') | Should -BeTrue
            $result.ContainsKey('Upper') | Should -BeTrue
            $result.ContainsKey('PowerShell') | Should -BeTrue
            $result.ContainsKey('Yaml') | Should -BeTrue
            $result.ContainsKey('Log') | Should -BeTrue
            $result.ContainsKey('Common') | Should -BeTrue
        }
    }
    
    Context 'パス構造の具体値' {
        It 'Common パスが PowerShell 直下の Common ディレクトリである' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            $expectedCommon = Join-Path $result.PowerShell 'Common'
            $result.Common | Should -Be $expectedCommon
        }
        
        It 'EnvFile が Yaml 直下のファイルパスである' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            $envFileName = 'config.yaml'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath -EnvFileName $envFileName
            
            # Assert
            $expectedEnvFile = Join-Path $result.Yaml $envFileName
            $result.EnvFile | Should -Be $expectedEnvFile
        }
    }
    
    Context 'ScriptPath エッジケース' {
        It 'UNC パス（\\server\share\Script\test.ps1）で例外が発生しない' -Tag 'Positive' {
            # Arrange
            $uncPath = '\\server\share\Script\test.ps1'
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $uncPath } | Should -Not -Throw
        }
        
        It 'UNC パスの戻り値がすべて絶対パスである' -Tag 'Positive' {
            # Arrange
            $uncPath = '\\server\share\Script\test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $uncPath
            
            # Assert
            foreach ($key in $result.Keys) {
                [System.IO.Path]::IsPathRooted($result[$key]) | Should -BeTrue
            }
        }
        
        It 'スペースを含むパスで例外が発生しない' -Tag 'Positive' {
            # Arrange
            $pathWithSpaces = Join-Path $script:TestRoot 'My Script\Script\test.ps1'
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $pathWithSpaces } | Should -Not -Throw
        }
        
        It 'スペース含むパスの戻り値がすべて絶対パスである' -Tag 'Positive' {
            # Arrange
            $pathWithSpaces = Join-Path $script:TestRoot 'My Script\Script\test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $pathWithSpaces
            
            # Assert
            foreach ($key in $result.Keys) {
                [System.IO.Path]::IsPathRooted($result[$key]) | Should -BeTrue
            }
        }
        
        It '日本語を含むパスで例外が発生しない' -Tag 'Positive' {
            # Arrange
            $pathWithJapanese = Join-Path $script:TestRoot 'スクリプト\Script\test.ps1'
            
            # Act & Assert
            { Get-ScriptPaths -ScriptPath $pathWithJapanese } | Should -Not -Throw
        }
        
        It '日本語含むパスの戻り値がすべて絶対パスである' -Tag 'Positive' {
            # Arrange
            $pathWithJapanese = Join-Path $script:TestRoot 'スクリプト\Script\test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $pathWithJapanese
            
            # Assert
            foreach ($key in $result.Keys) {
                [System.IO.Path]::IsPathRooted($result[$key]) | Should -BeTrue
            }
        }
    }
    
    Context '戻り値キー数の検証' {
        It 'EnvFileName 未指定時はキー数が 6 で EnvFile キーが無い' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath
            
            # Assert
            $result.Keys.Count | Should -Be 6
            $result.ContainsKey('EnvFile') | Should -BeFalse
        }
        
        It 'EnvFileName 指定時はキー数が 7 で EnvFile キーがある' -Tag 'Positive' {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            $envFileName = 'settings.yaml'
            
            # Act
            $result = Get-ScriptPaths -ScriptPath $testScriptPath -EnvFileName $envFileName
            
            # Assert
            $result.Keys.Count | Should -Be 7
            $result.ContainsKey('EnvFile') | Should -BeTrue
        }
    }
    
    Context 'Windows 大小文字混在パス' {
        It 'Windows で大小文字を変えた ScriptPath で結果が等価である' -Tag 'Positive', 'Windows' -Skip:($PSVersionTable.Platform -ne 'Win32NT' -and $null -ne $PSVersionTable.Platform) {
            # Arrange
            $testScriptPath = Join-Path $script:TestScriptDir 'test.ps1'
            $testScriptPathUpper = $testScriptPath.ToUpper()
            $testScriptPathMixed = [string]::Concat(
                $testScriptPath.Substring(0, 1).ToUpper(),
                $testScriptPath.Substring(1).ToLower()
            )
            
            # Act
            $result1 = Get-ScriptPaths -ScriptPath $testScriptPath
            $result2 = Get-ScriptPaths -ScriptPath $testScriptPathUpper
            $result3 = Get-ScriptPaths -ScriptPath $testScriptPathMixed
            
            # Assert
            # キー/値が等価（大小文字を無視）
            foreach ($key in $result1.Keys) {
                $result1[$key] | Should -Be $result2[$key]
                $result1[$key] | Should -Be $result3[$key]
            }
        }
    }
}
