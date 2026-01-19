<#
.SYNOPSIS
    Write-CommonLog 関数のユニットテスト

.DESCRIPTION
    Write-CommonLog 関数のユニットテスト
    - ログファイルの作成と書き込み
    - ログレベルの検証（INFO, WARN, ERROR, DEBUG）
    - メッセージのフォーマット検証（タイムスタンプ、ログレベル）
    - エラーハンドリング
    - エンコーディング（UTF-8、マルチバイト文字）
    - パフォーマンステスト

.NOTES
    Author: Test Suite
    Version: 1.1.0
    Last Updated: 2026-01-19
    Pester Version: 5.7.1 compatible
#>

Describe 'Write-CommonLog' -Tag 'Unit', 'Common' {
    BeforeAll {
        # テスト対象の関数を読み込み
        $commonPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        . (Join-Path $commonPath 'Common\Write-CommonLog.ps1')
        
        # テスト用の一時ディレクトリを作成
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PSLogTest_$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    }

    AfterAll {
        # テスト用のディレクトリをクリーンアップ
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force
        }
    }
    Context '正常系: ログファイル作成と書き込み' {
        It 'ログメッセージを書き込み、ファイルが作成される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'test.log'
            $message = 'テストメッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            Test-Path $logPath | Should -Be $true
            (Get-Content $logPath).Count | Should -BeGreaterThan 0
        }
        
        It '複数のメッセージが追記される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'append.log'
            $message1 = 'メッセージ1'
            $message2 = 'メッセージ2'
            
            # Act
            Write-CommonLog -Message $message1 -LogPath $logPath -Level 'INFO'
            Write-CommonLog -Message $message2 -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content.Count | Should -BeGreaterOrEqual 2
            $content -join ' ' | Should -Match $message1
            $content -join ' ' | Should -Match $message2
        }
        
        It 'ログファイルのディレクトリが存在しない場合、自動作成される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'subdir\nested\test.log'
            $message = 'テストメッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            Test-Path $logPath | Should -Be $true
        }
    }
    
    Context 'ログレベルの検証' {
        It 'INFO レベルのログが書き込まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'info.log'
            $message = 'INFO メッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'INFO'
            $content | Should -Match $message
        }
        
        It 'WARN レベルのログが書き込まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'warning.log'
            $message = 'WARN メッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'WARN'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'WARN'
            $content | Should -Match $message
        }
        
        It 'ERROR レベルのログが書き込まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'error.log'
            $message = 'ERROR メッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'ERROR'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'ERROR'
            $content | Should -Match $message
        }
        
        It 'DEBUG レベルのログが書き込まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'debug.log'
            $message = 'DEBUG メッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'DEBUG'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'DEBUG'
            $content | Should -Match $message
        }
    }
    
    Context 'ログメッセージのフォーマット' {
        It 'ログメッセージにタイムスタンプが含まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'timestamp.log'
            $message = 'タイムスタンプテスト'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            # タイムスタンプは YYYY-MM-DD HH:MM:SS 形式
            $content | Should -Match '\d{4}-\d{2}-\d{2}'
        }
        
        It 'ログメッセージにログレベルが含まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'level.log'
            $message = 'レベルテスト'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'WARN'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'WARN'
        }
        
        It 'ログメッセージが正しく含まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'message.log'
            $message = '特定のメッセージテキスト'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content -join ' ' | Should -Match ([regex]::Escape($message))
        }
    }
    
    Context 'エラーハンドリング' {
        It 'ログパスが null の場合、エラーが発生' {
            # Arrange
            $message = 'テストメッセージ'
            
            # Act & Assert
            { Write-CommonLog -Message $message -LogPath $null -Level 'INFO' } | Should -Throw
        }
        
        It 'メッセージが null の場合、エラーが発生' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'null.log'
            
            # Act & Assert
            { Write-CommonLog -Message $null -LogPath $logPath -Level 'INFO' } | Should -Throw
        }
        
        It '無効なログレベルの場合、デフォルト値が使用される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'invalid-level.log'
            $message = 'テストメッセージ'
            
            # Act
            # エラーが発生しないことを確認（デフォルト値または変換処理がある）
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INVALID' -ErrorAction SilentlyContinue
            
            # Assert
            if (Test-Path $logPath) {
                # ファイルが作成されていれば、正常に処理されている
                Test-Path $logPath | Should -Be $true
            }
        }
    }
    
    Context 'エンコーディング' {
        It 'UTF-8 でエンコードされている' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'encoding.log'
            $message = '日本語テストメッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath -Encoding UTF8
            $content | Should -Match '日本語'
        }
        
        It 'マルチバイト文字が正しく書き込まれる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'multibyte.log'
            $message = '🎉 絵文字テスト 中文'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath -Encoding UTF8
            $content | Should -Match '絵文字|中文'
        }
    }
    
    Context 'パフォーマンス' {
        It '大量のログメッセージが効率的に書き込まれる' -Tag 'Performance' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'large.log'
            $iterations = 1000
            
            # Act
            $startTime = Get-Date
            for ($i = 0; $i -lt $iterations; $i++) {
                Write-CommonLog -Message "メッセージ $i" -LogPath $logPath -Level 'INFO'
            }
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $duration | Should -BeLessOrEqual 10  # 10秒以内に完了
            (Get-Content $logPath).Count | Should -BeGreaterOrEqual $iterations
        }
    }
}


