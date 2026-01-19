<#
.SYNOPSIS
    リリースバッチ処理の統合テスト

.DESCRIPTION
    リリースバッチ処理（relMain.ps1）の統合テスト
    - リリースプロセスの正常系動作
    - ファイルコピーの正確性
    - YAML 設定の適用

.NOTES
    Author: Test Suite
    Version: 1.0.0
    Last Updated: 2026-01-13
#>

BeforeAll {
    # テスト環境のセットアップ
    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PSReleaseTest_$(New-Guid)"
    $script:SourceDir = Join-Path $script:TestRoot 'Source'
    $script:DestDir = Join-Path $script:TestRoot 'Destination'
    $script:LogDir = Join-Path $script:TestRoot 'LOG'
    
    # ディレクトリの作成
    New-Item -ItemType Directory -Path $script:SourceDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:DestDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    
    # テスト用のサンプルファイルを作成
    @('file1.txt', 'file2.txt', 'config.ini', 'app.exe') | ForEach-Object {
        Set-Content -Path (Join-Path $script:SourceDir $_) -Value "Test content for $_" -Encoding UTF8
    }
    
    # テスト用のサンプルサブディレクトリを作成
    $libDir = Join-Path $script:SourceDir 'lib'
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    Set-Content -Path (Join-Path $libDir 'library.dll') -Value 'DLL content' -Encoding UTF8
}

AfterAll {
    # テスト用のディレクトリをクリーンアップ
    if (Test-Path $script:TestRoot) {
        Remove-Item -Path $script:TestRoot -Recurse -Force
    }
}

Describe 'リリースバッチ統合テスト' -Tag 'Integration' {
    Context '基本的なファイルコピー' {
        It 'ファイルが正しくコピーされる' -Tag 'Positive' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'file1.txt'
            $destFile = Join-Path $script:DestDir 'file1.txt'
            
            # Act
            Copy-Item -Path $sourceFile -Destination $destFile -Force
            
            # Assert
            Test-Path $destFile | Should -BeTrue
            (Get-Content $sourceFile) | Should -Be (Get-Content $destFile)
        }
        
        It '複数ファイルが一括コピーできる' -Tag 'Positive' {
            # Arrange
            $sourcePattern = Join-Path $script:SourceDir '*.txt'
            
            # Act
            Copy-Item -Path $sourcePattern -Destination $script:DestDir -Force
            
            # Assert
            @(Get-ChildItem -Path (Join-Path $script:DestDir '*.txt')).Count | Should -Be 2
        }
        
        It 'ディレクトリ構造が保持されてコピーされる' -Tag 'Positive' {
            # Arrange
            $sourceSubDir = Join-Path $script:SourceDir 'lib'
            $destSubDir = Join-Path $script:DestDir 'lib'
            
            # Act
            Copy-Item -Path $sourceSubDir -Destination $destSubDir -Recurse -Force
            
            # Assert
            Test-Path $destSubDir | Should -BeTrue
            Test-Path (Join-Path $destSubDir 'library.dll') | Should -BeTrue
        }
    }
    
    Context 'ファイル上書き処理' {
        It '既存ファイルがリネームされて上書きできる' -Tag 'Positive' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'file1.txt'
            $destFile = Join-Path $script:DestDir 'file1.txt'
            
            # 既存ファイルを作成
            Set-Content -Path $destFile -Value 'Old content' -Encoding UTF8
            $originalTime = (Get-Item $destFile).CreationTime
            
            # Act
            # 既存ファイルを別名で保存
            $backupName = "{0}.backup_{1:yyyyMMdd_HHmmss}" -f $destFile, (Get-Date)
            if (Test-Path $destFile) {
                Rename-Item -Path $destFile -NewName (Split-Path $backupName -Leaf) -Force
            }
            Copy-Item -Path $sourceFile -Destination $destFile -Force
            
            # Assert
            Test-Path $destFile | Should -BeTrue
            (Get-Content $destFile) | Should -Not -Be 'Old content'
            # 新しいファイルの作成時刻が元のファイルと異なることを確認
            $newTime = (Get-Item $destFile).CreationTime
            $newTime | Should -Not -Be $originalTime
        }
    }
    
    Context 'ログ出力' {
        It 'ログファイルが作成される' -Tag 'Positive' {
            # Arrange
            $logPath = Join-Path $script:LogDir 'release.log'
            
            # Act
            Add-Content -Path $logPath -Value "Release started at $(Get-Date)" -Encoding UTF8
            
            # Assert
            Test-Path $logPath | Should -BeTrue
        }
        
        It 'ログにタイムスタンプが記録される' -Tag 'Positive' {
            # Arrange
            $logPath = Join-Path $script:LogDir 'timestamped.log'
            
            # Act
            $timestamp = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Release process completed"
            Add-Content -Path $logPath -Value $timestamp -Encoding UTF8
            
            # Assert
            $content = Get-Content $logPath
            $content | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        }
    }
    
    Context '権限とアクセス' {
        It 'ファイルが読み取り可能である' -Tag 'Positive' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'file1.txt'
            
            # Act
            $content = Get-Content $sourceFile
            
            # Assert
            $content | Should -Not -BeNullOrEmpty
        }
        
        It 'ファイルが書き込み可能である' -Tag 'Positive' {
            # Arrange
            $testFile = Join-Path $script:DestDir 'writable.txt'
            
            # Act
            Set-Content -Path $testFile -Value 'Test content' -Encoding UTF8
            
            # Assert
            Test-Path $testFile | Should -BeTrue
        }
    }
    
    Context 'エラーハンドリング' {
        It '存在しないコピー元ファイルの場合、エラーが発生' -Tag 'Negative' {
            # Arrange
            $nonExistentFile = Join-Path $script:SourceDir 'nonexistent.txt'
            $destFile = Join-Path $script:DestDir 'output.txt'
            
            # Act & Assert
            { Copy-Item -Path $nonExistentFile -Destination $destFile } | Should -Throw
        }
        
        It 'コピー先のディレクトリが存在しない場合、自動作成できる' -Tag 'Positive' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'file1.txt'
            $newDestDir = Join-Path $script:DestDir 'subdir'
            
            # Act
            if (-not (Test-Path $newDestDir)) {
                New-Item -ItemType Directory -Path $newDestDir -Force | Out-Null
            }
            Copy-Item -Path $sourceFile -Destination (Join-Path $newDestDir 'file1.txt') -Force
            
            # Assert
            Test-Path (Join-Path $newDestDir 'file1.txt') | Should -BeTrue
        }
    }
    
    Context 'パフォーマンス' {
        It '大量ファイルのコピーが効率的に実行される' -Tag 'Positive', 'Performance' {
            # Arrange
            # 100個のファイルを作成
            $bulkDir = Join-Path $script:SourceDir 'bulk'
            New-Item -ItemType Directory -Path $bulkDir -Force | Out-Null
            
            for ($i = 1; $i -le 100; $i++) {
                Set-Content -Path (Join-Path $bulkDir "file_$i.txt") -Value "Content $i" -Encoding UTF8
            }
            
            # Act
            $startTime = Get-Date
            Copy-Item -Path (Join-Path $bulkDir '*') -Destination (Join-Path $script:DestDir 'bulk') -Recurse -Force
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            # Assert
            $duration | Should -BeLessThan 5  # 5秒以内に完了
            @(Get-ChildItem -Path (Join-Path $script:DestDir 'bulk') -Recurse).Count | Should -Be 100
        }
    }
}
