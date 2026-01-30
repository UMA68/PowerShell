<#
.SYNOPSIS
    CheckCommand 関数のユニットテスト

.DESCRIPTION
    Test-Command 関数のユニットテスト
    - コマンドの存在確認
    - エラーハンドリング
    - さまざまなコマンドタイプの検証

.NOTES
    Author: Test Suite
    Version: 1.0.0
    Last Updated: 2026-01-13
#>

BeforeAll {
    # テスト対象の関数を読み込み
    $commonPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $commonPath 'Common\CheckCommand.ps1')
}

Describe 'Test-Command' -Tag 'Unit', 'Common' {
    Context '正常系: コマンド存在確認' {
        It 'PowerShell の組み込みコマンドが存在することを検出' -Tag 'Positive' {
            # Arrange
            $commandName = 'Get-ChildItem'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeTrue
        }
        
        It 'Cmdlet が存在することを検出' -Tag 'Positive' {
            # Arrange
            $commandName = 'Write-Host'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeTrue
        }
        
        It 'エイリアスが存在することを検出' -Tag 'Positive' {
            # Arrange
            # dir は Get-ChildItem のエイリアス
            $commandName = 'dir'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeTrue
        }
        
        It 'インストールされたモジュールのコマンドが存在することを検出' -Tag 'Positive' {
            # Arrange
            # PowerShell-Yaml がインストールされていることが前提
            $commandName = 'ConvertFrom-Yaml'
            
            # Act
            $result = Test-Command -ComName $commandName -ErrorAction SilentlyContinue
            
            # Assert
            # モジュールがインストールされている場合
            if ($null -ne (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
                $result | Should -BeTrue
            }
        }
    }
    
    Context '異常系: コマンド不在確認' {
        It '存在しないコマンドが見つからないことを検出' -Tag 'Negative' {
            # Arrange
            $commandName = 'NonExistentCommand12345'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeFalse
        }
        
        It 'タイポされたコマンド名が見つからないことを検出' -Tag 'Negative' {
            # Arrange
            $commandName = 'Get-ChldItem'  # Get-ChildItem のタイポ
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeFalse
        }
        
        It '存在しないモジュールのコマンドが見つからないことを検出' -Tag 'Negative' {
            # Arrange
            $commandName = 'NonExistentModule\NonExistentCommand'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeFalse
        }
    }
    
    Context 'パラメータの検証' {
        It 'ComName パラメータが指定されない場合、デフォルト値が使用される' -Tag 'Positive' {
            # Act & Assert
            # デフォルト値でコマンドが実行される
            # （結果は nkf32 が存在するかどうかに依存）
            { Test-Command } | Should -Not -Throw
        }
        
        It 'コマンド名が大文字小文字を区別しない' -Tag 'Positive' {
            # Arrange
            $commandName = 'get-childitem'  # 小文字
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeTrue
        }
        
        It 'コマンド名の前後の空白が削除される' -Tag 'Positive' {
            # Arrange
            $commandName = '  Get-ChildItem  '
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeTrue
        }
    }
    
    Context 'エラーハンドリング' {
        It 'コマンド名が null の場合、エラーが発生' -Tag 'Negative' {
            # Arrange
            $commandName = $null
            
            # Act & Assert
            { Test-Command -ComName $commandName } | Should -Throw
        }
        
        It 'コマンド名が空文字列の場合、エラーが発生' -Tag 'Negative' {
            # Arrange
            $commandName = ''
            
            # Act & Assert
            { Test-Command -ComName $commandName } | Should -Throw
        }
        
        It 'コマンド名が空白のみの場合、エラーが発生' -Tag 'Negative' {
            # Arrange
            $commandName = '   '
            
            # Act & Assert
            { Test-Command -ComName $commandName } | Should -Throw
        }
    }
    
    Context 'パフォーマンス' {
        It '複数のコマンドを高速に検査できる' -Tag 'Positive', 'Performance' {
            # Arrange
            $commands = @(
                'Get-ChildItem',
                'Write-Host',
                'Test-Path',
                'New-Item',
                'Remove-Item'
            )
            
            # Act
            $startTime = Get-Date
            foreach ($cmd in $commands) {
                [void] (Test-Command -ComName $cmd)
            }
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            # Assert
            $duration | Should -BeLessThan 2  # 2秒以内に完了
        }
    }
    
    Context 'スクリプト特有のコマンド' {
        It 'dll ファイルベースのコマンドを検出' -Tag 'Positive' {
            # Arrange
            # Add-Type は .NET クラスをロードするコマンド
            $commandName = 'Add-Type'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeTrue
        }
    }
    
    Context 'モジュール修飾コマンド名' {
        It 'モジュール修飾された既存コマンドが存在することを検出' -Tag 'Positive' {
            # Arrange
            $commandName = 'Microsoft.PowerShell.Management\Get-ChildItem'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeTrue
        }
        
        It 'モジュール修飾された存在しないコマンドが見つからないことを検出' -Tag 'Negative' {
            # Arrange
            $commandName = 'NonExistentModule\NonExistentCommand'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeFalse
        }
    }
    
    Context 'ワイルドカード指定時の警告' {
        It 'ワイルドカードを含むコマンド名で警告が発生' -Tag 'Positive' {
            # Arrange
            $commandName = 'Get-*'
            
            # Act
            $result = Test-Command -ComName $commandName -WarningVariable warnings -WarningAction SilentlyContinue
            
            # Assert
            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match 'ワイルドカード'
        }
        
        It 'ワイルドカードなしのコマンド名で警告が発生しない' -Tag 'Positive' {
            # Arrange
            $commandName = 'Get-ChildItem'
            
            # Act
            $result = Test-Command -ComName $commandName -WarningVariable warnings -WarningAction SilentlyContinue
            
            # Assert
            $warnings | Should -BeNullOrEmpty
        }
    }
    
    Context 'Verbose 出力' {
        It 'Verbose モードで詳細情報が出力される' -Tag 'Positive' {
            # Arrange
            $commandName = 'Get-ChildItem'
            
            # Act
            $verboseOutput = (Test-Command -ComName $commandName -Verbose 4>&1) | Out-String
            
            # Assert
            # Verbose 出力に型情報やパス情報などが含まれる
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Should -Match '(型|Type|パス|Path|検出|Cmdlet)'
        }
        
        It 'Verbose モードで存在しないコマンドの詳細が出力される' -Tag 'Negative' {
            # Arrange
            $commandName = 'NonExistentCommand98765'
            
            # Act
            $verboseOutput = (Test-Command -ComName $commandName -Verbose 4>&1) | Out-String
            
            # Assert
            # Verbose 出力にコマンドが見つからない旨が含まれる
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Should -Match '(見つかりませんでした|見つからない|Not found|存在しない)'
        }
    }
    
    Context '外部実行可能ファイル検出' {
        It 'PATH 上の notepad.exe が検出される（存在する場合）' -Tag 'Positive' {
            # Arrange
            $commandName = 'notepad'
            $externalCommand = Get-Command $commandName -ErrorAction SilentlyContinue
            
            # Act & Assert
            if ($null -ne $externalCommand) {
                $result = Test-Command -ComName $commandName
                $result | Should -BeTrue
            } else {
                Set-ItResult -Skipped -Because "notepad が環境に存在しません"
            }
        }
        
        It 'PATH 上の cmd.exe が検出される（存在する場合）' -Tag 'Positive' {
            # Arrange
            $commandName = 'cmd'
            $externalCommand = Get-Command $commandName -ErrorAction SilentlyContinue
            
            # Act & Assert
            if ($null -ne $externalCommand) {
                $result = Test-Command -ComName $commandName
                $result | Should -BeTrue
            } else {
                Set-ItResult -Skipped -Because "cmd が環境に存在しません"
            }
        }
        
        It 'PATH 上に存在しない外部コマンドが検出されない' -Tag 'Negative' {
            # Arrange
            $commandName = 'NonExistentExternalCommand54321.exe'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeFalse
        }
    }
    
    Context 'エッジケース: コマンド名' {
        It '非常に長いコマンド名でもエラーが発生しない' -Tag 'Positive' {
            # Arrange
            $commandName = 'Get-' + ('A' * 1000)
            
            # Act & Assert
            { Test-Command -ComName $commandName } | Should -Not -Throw
        }
        
        It '非常に長いコマンド名は存在しないと判定される' -Tag 'Negative' {
            # Arrange
            $commandName = 'Get-' + ('A' * 1000)
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeFalse
        }
        
        It 'Unicode を含むコマンド名が存在しないことを検出' -Tag 'Negative' {
            # Arrange
            $commandName = 'テスト-コマンド'
            
            # Act
            $result = Test-Command -ComName $commandName
            
            # Assert
            $result | Should -BeFalse
        }
        
        It 'Unicode を含むコマンド名でもエラーが発生しない' -Tag 'Positive' {
            # Arrange
            $commandName = 'テスト-コマンド'
            
            # Act & Assert
            { Test-Command -ComName $commandName } | Should -Not -Throw
        }
    }
}
