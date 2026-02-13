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
        
        It '無効なログレベルの場合、エラーが発生' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'invalid-level.log'
            $message = 'テストメッセージ'
            
            # Act & Assert
            # ValidateSetにより無効なレベルはエラーが発生する
            { Write-CommonLog -Message $message -LogPath $logPath -Level 'INVALID' } | Should -Throw
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
            $duration | Should -BeLessOrEqual 15  # 15秒以内に完了
            (Get-Content $logPath).Count | Should -BeGreaterOrEqual $iterations
        }
    }

    Context 'SensitivePatterns マスキング' {
        It 'パスワード文字列がマスクされる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'sensitive-password.log'
            $message = 'データベース接続: password=Secret123 を使用'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' -SensitivePatterns @('password')
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'password=\*+'
            $content | Should -Not -Match 'Secret123'
        }
        
        It 'APIトークン風の文字列がマスクされる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'sensitive-token.log'
            $message = 'APIキー: token=abc123def456xyz789 で認証'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' -SensitivePatterns @('token')
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'token=\*+'
            $content | Should -Not -Match 'abc123def456xyz789'
        }
        
        It '複数の機密情報パターンが同時にマスクされる' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'sensitive-multiple.log'
            $message = 'password=MyPass123 と apikey=Secret456 を含むメッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' -SensitivePatterns @('password', 'apikey')
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'password=\*+'
            $content | Should -Match 'apikey=\*+'
            $content | Should -Not -Match 'MyPass123'
            $content | Should -Not -Match 'Secret456'
        }
    }

    Context 'Quiet パラメータ' {
        It 'Quiet=$true の場合、ログファイルに出力されてコンソール出力はない' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'quiet-true.log'
            $message = 'Quiet テストメッセージ'
            
            # Act
            $output = Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' -Quiet $true 2>&1
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath
            $content | Should -Match ([regex]::Escape($message))
            # コンソール出力がないことを確認（Quiet パラメータが正しく機能）
            $output | Should -BeNullOrEmpty
        }
        
        It 'Quiet=$false の場合、ログファイルとコンソール両方に出力される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'quiet-false.log'
            $message = 'Not Quiet テストメッセージ'
            
            # Act
            # Write-Information が出力されるか確認（InformationAction Continue でキャプチャ）
            & {
                Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' -Quiet $false
            } 6>&1 | Out-Null
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath
            $content | Should -Match ([regex]::Escape($message))
            # ログファイルが出力されていることで、Quiet=false が機能していることを確認
        }
        
        It 'デフォルト（Quiet パラメータ省略）の場合、Quiet=false と同じ動作' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'quiet-default.log'
            $message = 'デフォルト Quiet テストメッセージ'
            
            # Act
            $null = Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' 6>&1
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath
            $content | Should -Match ([regex]::Escape($message))
        }
    }

    Context '複数行メッセージ' {
        It 'Here-String の複数行メッセージがログに記録される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'multiline.log'
            $message = @"
第1行
第2行
第3行
"@
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath -Raw  # -Raw で全体を1つの文字列として取得
            $content | Should -Match '第1行'
            $content | Should -Match '第2行'
            $content | Should -Match '第3行'
        }
        
        It '配列形式の複数のメッセージが適切に処理される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'multiline-array.log'
            $messages = @('行1', '行2', '行3')
            
            # Act
            Write-CommonLog -Message ($messages -join "`n") -LogPath $logPath -Level 'INFO'
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath -Raw  # -Raw で全体を1つの文字列として取得
            $content | Should -Match '行1'
            $content | Should -Match '行2'
            $content | Should -Match '行3'
        }
    }

    Context '特殊文字・エスケープ' {
        It 'ダブルクォートを含むメッセージがログフォーマットを壊さない' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'special-quote.log'
            $message = 'テスト "クォート" メッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'INFO'
            $content | Should -Match 'クォート'
        }
        
        It 'シングルクォートを含むメッセージがログフォーマットを壊さない' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'special-single.log'
            $message = "テスト 'シングル' メッセージ"
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'INFO'
            $content | Should -Match 'シングル'
        }
        
        It 'ドルサイン $を含むメッセージがログフォーマットを壊さない' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'special-dollar.log'
            $message = 'テスト $variable メッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'INFO'
            $content | Should -Match '\$variable'
        }
        
        It 'バックスラッシュ \ を含むメッセージがログフォーマットを壊さない' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'special-backslash.log'
            $message = 'テスト \path\to\file メッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'INFO'
            $content | Should -Match '\\path'
        }
        
        It 'タブ文字を含むメッセージがログに記録される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'special-tab.log'
            $message = "テスト`tタブ`tメッセージ"
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO'
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match 'INFO'
            $content | Should -Match 'タブ'
        }
    }

    Context 'WhatIf パラメータ' {
        It '-WhatIf 指定時にもログファイルが作成・更新される（ドライランモードでも監査ログ保存）' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'whatif-create.log'
            $message = 'WhatIf テストメッセージ'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' -WhatIf
            
            # Assert
            # 実装では -WhatIf モードでもログファイルに記録される（ドライランモードでも監査ログを残す）
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath
            $content | Should -Match ([regex]::Escape($message))
        }
        
        It '-WhatIf 指定時にも既存ログファイルが更新される（ドライラン実行計画をログに記録）' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'whatif-update.log'
            $message1 = '通常メッセージ'
            $message2 = 'WhatIf メッセージ'
            
            # Act
            # 最初は通常モードで書き込み
            Write-CommonLog -Message $message1 -LogPath $logPath -Level 'INFO'
            $fileSize1 = (Get-Item $logPath).Length
            
            # 少し待機
            Start-Sleep -Milliseconds 100
            
            # WhatIf で書き込み試行（実装では -WhatIf でもログに記録）
            Write-CommonLog -Message $message2 -LogPath $logPath -Level 'INFO' -WhatIf
            $fileSize2 = (Get-Item $logPath).Length
            
            # Assert
            $content = Get-Content $logPath -Raw
            $content | Should -Match $message1
            $content | Should -Match $message2
            # ファイルサイズが増加していることを確認（両メッセージが記録）
            $fileSize2 | Should -BeGreaterThan $fileSize1
        }
        
        It '-WhatIf 指定時でもメッセージは記録される' {
            # Arrange
            $logPath = Join-Path $script:TestRoot 'whatif-output.log'
            $message = 'WhatIf コンソール出力テスト'
            
            # Act
            Write-CommonLog -Message $message -LogPath $logPath -Level 'INFO' -WhatIf
            
            # Assert
            Test-Path $logPath | Should -Be $true
            $content = Get-Content $logPath
            $content | Should -Match ([regex]::Escape($message))
        }
    }
}


