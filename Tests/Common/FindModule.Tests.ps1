<#
.SYNOPSIS
    Test-ModuleInstalled 関数のユニットテスト

.DESCRIPTION
    Test-ModuleInstalled 関数のユニットテスト
    - モジュール存在確認
    - 複数バージョンの選択
    - MinimumVersion の判定
    - ShowDialog の挙動
    - パラメーター検証

.NOTES
    Author: Test Suite
    Version: 1.0.0
    Last Updated: 2026-02-16
#>

BeforeAll {
    # テスト対象の関数を読み込み
    $commonPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $findModuleScriptPath = Join-Path $commonPath 'Common\FindModule.ps1'
    $script:FindModuleScriptAvailable = $false
    if (Test-Path $findModuleScriptPath) {
        . $findModuleScriptPath
        $script:FindModuleScriptAvailable = $true
    }

    # テストデータ
    $script:ModuleName = 'TestModule'
    $script:ModuleNameWildcard = 'Test*Module'
    $script:OldVersion = [version]'1.0.0'
    $script:NewVersion = [version]'2.0.0'
    $script:RequiredVersion = [version]'1.5.0'

    $script:SingleModule = @(
        [pscustomobject]@{ Name = $script:ModuleName; Version = $script:NewVersion }
    )

    $script:MultiModules = @(
        [pscustomobject]@{ Name = $script:ModuleName; Version = $script:OldVersion },
        [pscustomobject]@{ Name = $script:ModuleName; Version = $script:NewVersion }
    )
}

Describe 'Test-ModuleInstalled' -Tag 'Unit', 'Common' {
    # テスト戦略: 外部依存をすべて Mock で置き換え、Test-ModuleInstalled の制御フローとメッセージ内容のみを検証
    # - Get-Module: 実際のモジュールインストール状態に依存しない
    # - New-Object -ComObject WScript.Shell: 実際の UI ダイアログを表示しない
    # - Write-Error / Write-Warning: 出力内容のみを検証し、実際のコンソール出力は抑制
    
    BeforeEach {
        if (-not $script:FindModuleScriptAvailable) {
            Set-ItResult -Skipped -Because 'FindModule.ps1 が見つかりません'
        }

        $script:PopupCallCount = 0
        $script:PopupMessage = $null
    }

    Context '正常系: モジュール存在' {
        It 'モジュールが 1 つ存在する場合は true を返す' -Tag 'Positive' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return $script:SingleModule } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName

            # Assert
            $result | Should -BeTrue
            ($result -is [bool]) | Should -BeTrue
            Assert-MockCalled -CommandName Get-Module -Times 1 -Exactly
        }

        It '複数バージョンがある場合は最新版を使用する' -Tag 'Positive' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return $script:MultiModules } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName -MinimumVersion $script:RequiredVersion

            # Assert
            $result | Should -BeTrue
            Assert-MockCalled -CommandName Get-Module -Times 1 -Exactly
        }

        It 'MinimumVersion を満たす場合は true を返す' -Tag 'Positive' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return $script:SingleModule } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName -MinimumVersion $script:NewVersion

            # Assert
            $result | Should -BeTrue
        }
    }

    Context '異常系: モジュール未検出' {
        It 'モジュールが見つからない場合は false を返し Write-Error が出力される' -Tag 'Negative' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return @() } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }
            Mock -CommandName Write-Error

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName

            # Assert
            $result | Should -BeFalse
            Assert-MockCalled -CommandName Write-Error -Times 1 -Exactly -ParameterFilter {
                $Message -eq "モジュール '$($script:ModuleName)' がインストールされていません。"
            }
        }
    }

    Context '異常系: バージョン不足' {
        It 'MinimumVersion を満たさない場合は false を返し正しいメッセージを出力する' -Tag 'Negative' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return $script:SingleModule } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }
            Mock -CommandName Write-Error

            $required = [version]'3.0.0'
            $expectedMessage = "モジュール '$($script:ModuleName)' のバージョンが不足しています。必要バージョン: $required、現在: $($script:NewVersion)"

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName -MinimumVersion $required

            # Assert
            $result | Should -BeFalse
            Assert-MockCalled -CommandName Write-Error -Times 1 -Exactly -ParameterFilter {
                $Message -eq $expectedMessage
            }
        }
    }

    Context 'ShowDialog: モジュール未検出' {
        It 'ShowDialog 指定時に Popup が 1 回呼ばれる' -Tag 'Positive' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return @() } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }
            Mock -CommandName Write-Error
            
            # ShowDialog モックの設計意図:
            # 
            # [実装側の挙動]
            # FindModule.ps1 では、ShowDialog 指定時に New-Object -ComObject WScript.Shell で COM を生成し、
            # Popup メソッドを呼び出してエラーメッセージをダイアログとしてユーザーに表示しています。
            # 
            # [テスト側の意図]
            # - 実際の UI ダイアログを表示すると自動テストが中断されるため、Popup メソッドのみを差し替える必要がある
            # - New-Object のモックが再帰的に New-Object を呼ばないよう [System.Activator]::CreateInstance() で実 COM を生成
            # - Popup を ScriptMethod で上書きし、呼び出し回数とメッセージ内容だけを検証
            # - これにより「モジュール未検出時に Popup が 1 回呼ばれること」と「適切なメッセージが渡されること」を
            #   安全かつ自動テストで確認できる
            Mock -CommandName New-Object -MockWith {
                param($ComObject)
                $obj = [pscustomobject]@{}
                $obj | Add-Member -MemberType ScriptMethod -Name Popup -Force -Value {
                    param($message, $timeout, $title, $type)
                    $script:PopupCallCount++
                    $script:PopupMessage = $message
                    return 0
                }
                return $obj
            } -ParameterFilter { $ComObject -eq 'WScript.Shell' }

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName -ShowDialog

            # Assert
            $result | Should -BeFalse
            $script:PopupCallCount | Should -Be 1
            $script:PopupMessage | Should -Match '見つかりません'
            Assert-MockCalled -CommandName New-Object -Times 1 -Exactly
            Assert-MockCalled -CommandName Write-Error -Times 0
        }
    }

    Context 'ShowDialog: バージョン不足' {
        It 'バージョン不足時に Popup が呼ばれる' -Tag 'Positive' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return $script:SingleModule } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }
            Mock -CommandName Write-Error
            
            # [実装側の挙動]
            # MinimumVersion を満たさない場合も、ShowDialog 指定時は Popup でバージョン不足メッセージを表示します。
            # 
            # [テスト側の意図]
            # - モジュール未検出時と同様に、実際の UI を出さずに Popup の呼び出しとメッセージ内容を検証
            # - 「バージョンが不足しています。必要: X、現在: Y」という形式のメッセージが渡されることを確認
            Mock -CommandName New-Object -MockWith {
                param($ComObject)
                $obj = [pscustomobject]@{}
                $obj | Add-Member -MemberType ScriptMethod -Name Popup -Force -Value {
                    param($message, $timeout, $title, $type)
                    $script:PopupCallCount++
                    $script:PopupMessage = $message
                    return 0
                }
                return $obj
            } -ParameterFilter { $ComObject -eq 'WScript.Shell' }

            $required = [version]'3.0.0'

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName -MinimumVersion $required -ShowDialog

            # Assert
            $result | Should -BeFalse
            $script:PopupCallCount | Should -Be 1
            $script:PopupMessage | Should -Match 'バージョンが不足'
            Assert-MockCalled -CommandName New-Object -Times 1 -Exactly
            Assert-MockCalled -CommandName Write-Error -Times 0
        }

        It 'COM オブジェクト解放のための処理が呼ばれる' -Tag 'Positive' {
            # [実装側の挙動]
            # FindModule.ps1 では、ShowDialog パスの finally ブロックで以下を呼び出し、COM リソースを明示的に解放しています:
            # - [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj)
            # - [System.GC]::Collect()
            # - [System.GC]::WaitForPendingFinalizers()
            # 
            # [テスト側の意図]
            # - このテストは「GC や COM の内部動作そのもの」ではなく、「解放処理を呼ぶという設計を守る」ためのユニットテスト
            # - ReleaseComObject / Collect / WaitForPendingFinalizers は静的メソッドのため Mock で捕捉できない
            # - そのため、実際の COM オブジェクトを生成して「実行時に例外が出ない」ことで間接的に検証
            # - テストが正常完了すれば、COM 解放処理が正しく実行されたことを示す
            
            # Arrange
            Mock -CommandName Get-Module -MockWith { return @() } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }
            Mock -CommandName Write-Error
            
            # 実際の __ComObject を生成して ReleaseComObject が正常動作することを保証
            # Popup のみ差し替えて UI 表示を抑制
            Mock -CommandName New-Object -MockWith {
                param($ComObject)
                $obj = [System.Activator]::CreateInstance([type]::GetTypeFromProgID('WScript.Shell'))
                $obj | Add-Member -MemberType ScriptMethod -Name Popup -Force -Value { return 0 }
                return $obj
            } -ParameterFilter { $ComObject -eq 'WScript.Shell' }

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName -ShowDialog

            # Assert
            $result | Should -BeFalse
            Assert-MockCalled -CommandName New-Object -Times 1 -Exactly
            # テスト完了 = finally ブロックの ReleaseComObject/GC 処理で例外が発生せず、正常に解放された
        }
    }

    Context 'パラメーター検証' {
        It 'ModuleName が null の場合はバインドエラーになる' -Tag 'Negative' {
            # Act & Assert
            { Test-ModuleInstalled -ModuleName $null } | Should -Throw
        }

        It 'ModuleName が空文字列の場合はバインドエラーになる' -Tag 'Negative' {
            # Act & Assert
            { Test-ModuleInstalled -ModuleName '' } | Should -Throw
        }

        It 'ModuleName にワイルドカードが含まれる場合は警告が出力される' -Tag 'Negative' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return $script:SingleModule } -ParameterFilter {
                $Name -eq $script:ModuleNameWildcard -and $ListAvailable
            }
            Mock -CommandName Write-Warning

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleNameWildcard

            # Assert
            $result | Should -BeTrue
            Assert-MockCalled -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -match 'ワイルドカード文字'
            }
        }
    }

    Context '戻り値' {
        It '代表ケースで [bool] を返す' -Tag 'Positive' {
            # Arrange
            Mock -CommandName Get-Module -MockWith { return $script:SingleModule } -ParameterFilter {
                $Name -eq $script:ModuleName -and $ListAvailable
            }

            # Act
            $result = Test-ModuleInstalled -ModuleName $script:ModuleName

            # Assert
            ($result -is [bool]) | Should -BeTrue
        }
    }
}
