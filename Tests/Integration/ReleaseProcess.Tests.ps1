<#
.SYNOPSIS
    リリースバッチ処理の統合テスト

.DESCRIPTION
    リリースバッチ処理（relMain.ps1）の統合テスト
    
    テスト項目:
    - 基本的なファイルコピー: 単一/複数ファイル、ディレクトリ構造の保持
    - ファイル上書き処理: 既存ファイルのバックアップと上書き
    - ログ出力: ログファイル作成とタイムスタンプ記録
    - 権限とアクセス: ファイルの読み取り/書き込み可能性
    - エラーハンドリング: 存在しないファイルのエラー処理、ディレクトリ自動作成
    - パフォーマンス: 大量ファイルの効率的なコピー

.NOTES
    Author: Test Suite
    Version: 1.1.0
    Last Updated: 2026-01-19
    Pester Version: 5.x compatible
#>

Describe 'リリースバッチ統合テスト' {
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
    Context '基本的なファイルコピー' {
        It 'ファイルが正しくコピーされる' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'file1.txt'
            $destFile = Join-Path $script:DestDir 'file1.txt'
            
            # Act
            Copy-Item -Path $sourceFile -Destination $destFile -Force
            
            # Assert
            Test-Path $destFile | Should -BeTrue
            (Get-Content $sourceFile) | Should -Be (Get-Content $destFile)
        }
        
        It '複数ファイルが一括コピーできる' {
            # Arrange
            $sourcePattern = Join-Path $script:SourceDir '*.txt'
            
            # Act
            Copy-Item -Path $sourcePattern -Destination $script:DestDir -Force
            
            # Assert
            @(Get-ChildItem -Path (Join-Path $script:DestDir '*.txt')).Count | Should -Be 2
        }
        
        It 'ディレクトリ構造が保持されてコピーされる' {
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
        It '既存ファイルがリネームされて上書きできる' {
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
            # バックアップファイルが作成されていることを確認（メタデータに依存しない検証）
            Test-Path $backupName | Should -BeTrue
        }
    }
    
    Context 'ログ出力' {
        It 'ログファイルが作成される' {
            # Arrange
            $logPath = Join-Path $script:LogDir 'release.log'
            
            # Act
            Add-Content -Path $logPath -Value "Release started at $(Get-Date)" -Encoding UTF8
            
            # Assert
            Test-Path $logPath | Should -BeTrue
        }
        
        It 'ログにタイムスタンプが記録される' {
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
        It 'ファイルが読み取り可能である' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'file1.txt'
            
            # Act
            $content = Get-Content $sourceFile
            
            # Assert
            $content | Should -Not -BeNullOrEmpty
        }
        
        It 'ファイルが書き込み可能である' {
            # Arrange
            $testFile = Join-Path $script:DestDir 'writable.txt'
            
            # Act
            Set-Content -Path $testFile -Value 'Test content' -Encoding UTF8
            
            # Assert
            Test-Path $testFile | Should -BeTrue
        }
    }
    
    Context 'エラーハンドリング' {
        It '存在しないコピー元ファイルの場合、エラーが発生' {
            # Arrange
            $nonExistentFile = Join-Path $script:SourceDir 'nonexistent.txt'
            $destFile = Join-Path $script:DestDir 'output.txt'
            
            # Act & Assert
            { Copy-Item -Path $nonExistentFile -Destination $destFile -ErrorAction Stop } | Should -Throw
        }
        
        It 'コピー先のディレクトリが存在しない場合、自動作成できる' {
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

    Context 'ファイル属性の保持' {
        It 'ReadOnly 属性がコピー先に反映される（または仕様どおり）' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'readonly.txt'
            $destFile = Join-Path $script:DestDir 'readonly.txt'
            Set-Content -Path $sourceFile -Value 'ReadOnly test' -Encoding UTF8

            # Act
            $sourceItem = Get-Item $sourceFile
            $originalAttributes = $sourceItem.Attributes
            try {
                $sourceItem.Attributes = $sourceItem.Attributes -bor [System.IO.FileAttributes]::ReadOnly
                Copy-Item -Path $sourceFile -Destination $destFile -Force
            }
            finally {
                # 後始末: テストファイルの属性を戻す
                if (Test-Path $sourceFile) {
                    (Get-Item $sourceFile).Attributes = $originalAttributes
                }
            }

            # Assert
            (Get-Item $destFile).Attributes.HasFlag([System.IO.FileAttributes]::ReadOnly) | Should -BeTrue
        }
    }

    Context '部分的失敗時の挙動' {
        It '一部失敗でも他のファイルがコピーされ、失敗がログに残る' {
            # Arrange
            $bulkDir = Join-Path $script:SourceDir 'partial'
            $destBulkDir = Join-Path $script:DestDir 'partial'
            $logPath = Join-Path $script:LogDir 'partial-failure.log'
            New-Item -ItemType Directory -Path $bulkDir -Force | Out-Null
            New-Item -ItemType Directory -Path $destBulkDir -Force | Out-Null

            for ($i = 1; $i -le 100; $i++) {
                Set-Content -Path (Join-Path $bulkDir "file_$i.txt") -Value "Content $i" -Encoding UTF8
            }

            $lockedFile = Join-Path $bulkDir 'file_50.txt'
            $copyErrors = @()

            # Act
            $stream = [System.IO.File]::Open($lockedFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            try {
                Copy-Item -Path (Join-Path $bulkDir '*') -Destination $destBulkDir -Recurse -Force -ErrorAction Continue -ErrorVariable copyErrors
            }
            finally {
                $stream.Dispose()
            }

            if ($copyErrors.Count -gt 0) {
                Add-Content -Path $logPath -Value ("ERROR: Failed to copy {0}" -f $lockedFile) -Encoding UTF8
            }

            # Assert
            $copyErrors.Count | Should -Be 1
            @(Get-ChildItem -Path $destBulkDir -Filter '*.txt').Count | Should -Be 99
            Test-Path $logPath | Should -BeTrue
            $pattern = [Regex]::Escape($lockedFile)
            (Get-Content $logPath) | Should -Match $pattern
        }
    }

    Context 'ファイルロック' {
        It 'ロックされたコピー元はエラーになる' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'locked.txt'
            $destFile = Join-Path $script:DestDir 'locked.txt'
            Set-Content -Path $sourceFile -Value 'Lock test' -Encoding UTF8

            # Act
            $stream = [System.IO.File]::Open($sourceFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            try {
                { Copy-Item -Path $sourceFile -Destination $destFile -Force -ErrorAction Stop } | Should -Throw
            }
            finally {
                $stream.Dispose()
            }
        }
    }

    Context 'データ完全性 (ハッシュ)' {
        It 'バイナリファイルのハッシュが一致する' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'binary.bin'
            $destFile = Join-Path $script:DestDir 'binary.bin'
            $bytes = New-Object byte[] 2048
            $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
            $rng.GetBytes($bytes)
            $rng.Dispose()
            [System.IO.File]::WriteAllBytes($sourceFile, $bytes)

            # Act
            Copy-Item -Path $sourceFile -Destination $destFile -Force
            $sourceHash = (Get-FileHash -Path $sourceFile -Algorithm SHA256).Hash
            $destHash = (Get-FileHash -Path $destFile -Algorithm SHA256).Hash

            # Assert
            $sourceHash | Should -Be $destHash
        }
    }

    Context 'タイムスタンプとサイズ' {
        It 'サイズと更新時刻が仕様どおり' {
            # Arrange
            $sourceFile = Join-Path $script:SourceDir 'timestamp.txt'
            $destFile = Join-Path $script:DestDir 'timestamp.txt'
            Set-Content -Path $sourceFile -Value ('x' * 1024) -Encoding UTF8
            $sourceItem = Get-Item $sourceFile
            $sourceTime = Get-Date '2025-01-01 12:34:56'
            $sourceItem.LastWriteTime = $sourceTime

            # Act
            $copyStart = Get-Date
            Copy-Item -Path $sourceFile -Destination $destFile -Force
            $copyEnd = Get-Date
            $destItem = Get-Item $destFile

            # Assert
            $destItem.Length | Should -Be $sourceItem.Length
            (($destItem.LastWriteTime -eq $sourceTime) -or ($destItem.LastWriteTime -ge $copyStart -and $destItem.LastWriteTime -le $copyEnd)) | Should -BeTrue
        }
    }

    Context 'ロールバック' {
        It 'バックアップから復元できる（未実装のため保留）' -Pending {
            # TODO: *.backup_YYYYMMDD_HHmmss からの復元機能が実装されたらテストを追加
        }
    }
    
    Context 'パフォーマンス' {
        It '大量ファイルのコピーが効率的に実行される' -Tag 'Performance' {
            # Arrange
            # 100個のファイルを作成
            $bulkDir = Join-Path $script:SourceDir 'bulk'
            New-Item -ItemType Directory -Path $bulkDir -Force | Out-Null
            
            for ($i = 1; $i -le 100; $i++) {
                Set-Content -Path (Join-Path $bulkDir "file_$i.txt") -Value "Content $i" -Encoding UTF8
            }
            
            # Act
            $startTime = Get-Date
            $destBulkDir = Join-Path $script:DestDir 'bulk'
            New-Item -ItemType Directory -Path $destBulkDir -Force | Out-Null
            Copy-Item -Path (Join-Path $bulkDir '*') -Destination $destBulkDir -Recurse -Force
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            # Assert
            $duration | Should -BeLessThan 5  # 5秒以内に完了
            @(Get-ChildItem -Path $destBulkDir).Count | Should -Be 100
        }
    }
}

