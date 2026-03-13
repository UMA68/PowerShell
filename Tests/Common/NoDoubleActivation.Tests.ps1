<#
.SYNOPSIS
    Test-NoDoubleActivation 関数のユニットテスト

.DESCRIPTION
    Common\NoDoubleActivation.ps1 に含まれる Test-NoDoubleActivation 関数を
    Pester v5 形式でテストします。
    Mutex や COM 依存は可能な範囲で Mock し、CI で安定実行できる構成にします。
#>

BeforeAll {
    # テスト対象の関数を読み込み
    $commonPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $commonPath 'Common\NoDoubleActivation.ps1')
}

AfterAll {
    # 本テストで明示的な後始末は不要
}

Describe 'Test-NoDoubleActivation' -Tag 'Unit', 'Common' {
    Context '正常系: 初回起動' {
        It 'Mutex を取得できた場合に true を返す' -Tag 'Positive' {
            # Arrange
            $fakeMutex = [PSCustomObject]@{}
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name WaitOne -Value { param([int]$ms) $true }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Close -Value { }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

            Mock New-Object {
                return $fakeMutex
            } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }

            Mock Get-EventSubscriber { $null }
            Mock Register-EngineEvent { [PSCustomObject]@{ Name = 'NoDoubleActivationCleanup' } }

            # Act
            $result = Test-NoDoubleActivation -Thread 'sqlMain'

            # Assert
            $result | Should -BeTrue
            Should -Invoke New-Object -Times 1 -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }
            Should -Invoke Register-EngineEvent -Times 1
        }

        It '既にイベント購読がある場合は Register-EngineEvent を呼ばない' -Tag 'Positive' {
            # Arrange
            $fakeMutex = [PSCustomObject]@{}
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name WaitOne -Value { param([int]$ms) $true }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Close -Value { }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

            Mock New-Object {
                return $fakeMutex
            } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }

            Mock Get-EventSubscriber { [PSCustomObject]@{ SourceIdentifier = 'existing' } }
            Mock Register-EngineEvent { }

            # Act
            $result = Test-NoDoubleActivation -Thread 'releaseMain'

            # Assert
            $result | Should -BeTrue
            Should -Invoke Register-EngineEvent -Times 0
        }
    }

    Context '異常系: 二重起動検出' {
        It 'Mutex を取得できない場合に false を返し、警告を出す' -Tag 'Negative' {
            # Arrange
            $fakeMutex = [PSCustomObject]@{}
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name WaitOne -Value { param([int]$ms) $false }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Close -Value { }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

            Mock New-Object {
                return $fakeMutex
            } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }

            Mock Write-Warning { }

            # Act
            $result = Test-NoDoubleActivation -Thread 'sqlMain'

            # Assert
            $result | Should -BeFalse
            Should -Invoke Write-Warning -Times 1
        }

        It 'ShowDialog 指定時は WScript.Shell の生成を試みる' -Tag 'Negative' {
            # Arrange
            $fakeMutex = [PSCustomObject]@{}
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name WaitOne -Value { param([int]$ms) $false }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Close -Value { }
            $fakeMutex | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

            Mock New-Object {
                return $fakeMutex
            } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }

            Mock New-Object {
                throw [System.InvalidOperationException]::new('WScript.Shell mocked for test')
            } -ParameterFilter { $ComObject -eq 'WScript.Shell' }

            Mock Write-Error { throw 'Dialog path error is expected in unit test' }

            # Act & Assert
            { Test-NoDoubleActivation -Thread 'sqlMain' -ShowDialog } | Should -Throw
            Should -Invoke New-Object -Times 1 -ParameterFilter { $ComObject -eq 'WScript.Shell' }
        }
    }

    Context 'パラメータ検証' {
        It 'Thread が null の場合は例外を投げる' -Tag 'Negative' {
            # Act & Assert
            { Test-NoDoubleActivation -Thread $null } | Should -Throw
        }

        It 'Thread が空文字の場合は例外を投げる' -Tag 'Negative' {
            # Act & Assert
            { Test-NoDoubleActivation -Thread '' } | Should -Throw
        }

        It 'Thread に無効文字を含む場合は例外を投げる' -Tag 'Negative' {
            # Act & Assert
            { Test-NoDoubleActivation -Thread 'bad:name' } | Should -Throw
        }
    }

    Context 'Mutex 生成エラー' {
        It 'InvalidOperationException 発生時はエラーとして停止する' -Tag 'Negative' {
            # Arrange
            Mock New-Object {
                throw [System.InvalidOperationException]::new('mutex create failed')
            } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }

            # Act & Assert
            { Test-NoDoubleActivation -Thread 'sqlMain' } | Should -Throw
        }

        It 'UnauthorizedAccessException 発生時はエラーとして停止する' -Tag 'Negative' {
            # Arrange
            Mock New-Object {
                throw [System.UnauthorizedAccessException]::new('access denied')
            } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }

            # Act & Assert
            { Test-NoDoubleActivation -Thread 'sqlMain' } | Should -Throw
        }

        It '想定外の例外でもエラーとして停止する' -Tag 'Negative' {
            # Arrange
            Mock New-Object {
                throw [System.Exception]::new('unexpected')
            } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }

            # Act & Assert
            { Test-NoDoubleActivation -Thread 'sqlMain' } | Should -Throw
        }
    }
}
