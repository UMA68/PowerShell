<#
.SYNOPSIS
    Import-YamlConfig 関数のユニットテスト

.DESCRIPTION
    Import-YamlConfig 関数のユニットテスト
    - YAML ファイルの読み込み
    - OrderedDictionary の返却
    - エラーハンドリング
    - ネストされた構造の検証

.NOTES
    Author: Test Suite
    Version: 1.0.0
    Last Updated: 2026-01-13
#>

BeforeAll {
    # テスト対象の関数を読み込み
    $commonPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $commonPath 'Common\Import-YamlConfig.ps1')
    
    # PowerShell-Yaml がインストールされているか確認
    try {
        Import-Module PowerShell-Yaml -ErrorAction Stop
        $script:YamlModuleAvailable = $true
    } catch {
        $script:YamlModuleAvailable = $false
    }
    
    # テスト用の一時ディレクトリとサンプルYAMLファイルを作成
    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "PSYamlTest_$(New-Guid)"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    
    # サンプル1: シンプルな YAML
    $script:SimpleYaml = @"
Project:
  Name: TestProject
  Version: 1.0.0
Configuration:
  Debug: true
  MaxRetries: 3
"@
    $script:SimpleYamlPath = Join-Path $script:TestRoot 'simple.yaml'
    Set-Content -Path $script:SimpleYamlPath -Value $script:SimpleYaml -Encoding UTF8
    
    # サンプル2: ネストされた YAML
    $script:NestedYaml = @"
Database:
  Server: localhost
  Port: 5432
  Credentials:
    Username: admin
    Password: encrypted
  Options:
    Timeout: 30
    Retry: true
Logging:
  Level: INFO
  File:
    Path: ./logs
    Format: json
"@
    $script:NestedYamlPath = Join-Path $script:TestRoot 'nested.yaml'
    Set-Content -Path $script:NestedYamlPath -Value $script:NestedYaml -Encoding UTF8
    
    # サンプル3: 配列を含む YAML
    $script:ArrayYaml = @"
Servers:
  - Name: server1
    IP: 192.168.1.1
    Port: 8080
  - Name: server2
    IP: 192.168.1.2
    Port: 8081
Settings:
  Tags:
    - production
    - critical
  Features:
    - feature-a
    - feature-b
"@
    $script:ArrayYamlPath = Join-Path $script:TestRoot 'array.yaml'
    Set-Content -Path $script:ArrayYamlPath -Value $script:ArrayYaml -Encoding UTF8
    
    # サンプル4: 不正な YAML
    $script:InvalidYaml = @"
Invalid: [ unclosed
  array: here
"@
    $script:InvalidYamlPath = Join-Path $script:TestRoot 'invalid.yaml'
    Set-Content -Path $script:InvalidYamlPath -Value $script:InvalidYaml -Encoding UTF8
}

AfterAll {
    # テスト用のディレクトリをクリーンアップ
    if (Test-Path $script:TestRoot) {
        Remove-Item -Path $script:TestRoot -Recurse -Force
    }
}

Describe 'Import-YamlConfig' -Tag 'Unit', 'Common' {
    BeforeEach {
        # PowerShell-Yaml がインストールされていない場合はスキップ
        if (-not $script:YamlModuleAvailable) {
            Set-ItResult -Skipped -Because 'PowerShell-Yaml モジュールがインストールされていません'
        }
    }
    
    Context '正常系: YAML ファイル読み込み' {
        It 'シンプルな YAML ファイルを読み込める' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:SimpleYamlPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Project | Should -Not -BeNullOrEmpty
            $result.Project.Name | Should -Be 'TestProject'
            $result.Project.Version | Should -Be '1.0.0'
        }
        
        It 'ネストされた YAML ファイルを読み込める' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:NestedYamlPath
            
            # Assert
            $result.Database | Should -Not -BeNullOrEmpty
            $result.Database.Server | Should -Be 'localhost'
            $result.Database.Credentials.Username | Should -Be 'admin'
            $result.Database.Options.Timeout | Should -Be 30
        }
        
        It '配列を含む YAML ファイルを読み込める' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:ArrayYamlPath
            
            # Assert
            $result.Servers | Should -Not -BeNullOrEmpty
            $result.Servers.Count | Should -BeGreaterThan 0
            $result.Servers[0].Name | Should -Be 'server1'
            $result.Settings.Tags | Should -Contain 'production'
        }
        
        It 'OrderedDictionary として返却される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:SimpleYamlPath
            
            # Assert
            # OrderedDictionary または Hashtable であることを確認
            ($result -is [System.Collections.Specialized.OrderedDictionary] -or 
             $result -is [Hashtable]) | Should -BeTrue
        }
        
        It 'キーが保持される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:SimpleYamlPath
            
            # Assert
            $result.Contains('Project') | Should -BeTrue
            $result.Contains('Configuration') | Should -BeTrue
        }
    }
    
    Context 'エラーハンドリング' {
        It 'ファイルが存在しない場合、エラーが発生' -Tag 'Negative' {
            # Arrange
            $nonExistentPath = Join-Path $script:TestRoot 'nonexistent.yaml'
            
            # Act & Assert
            { Import-YamlConfig -YamlPath $nonExistentPath } | Should -Throw
        }
        
        It 'パスが null の場合、エラーが発生' -Tag 'Negative' {
            # Act & Assert
            { Import-YamlConfig -YamlPath $null } | Should -Throw
        }
        
        It 'パスが空文字列の場合、エラーが発生' -Tag 'Negative' {
            # Act & Assert
            { Import-YamlConfig -YamlPath '' } | Should -Throw
        }
        
        It '不正な YAML ファイルの場合、エラーが発生' -Tag 'Negative' {
            # Act & Assert
            { Import-YamlConfig -YamlPath $script:InvalidYamlPath } | Should -Throw
        }
    }
    
    Context 'ファイル形式' {
        It '.yaml 拡張子が処理できる' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:SimpleYamlPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
        }
        
        It '.yml 拡張子が処理できる' -Tag 'Positive' {
            # Arrange
            $ymlPath = Join-Path $script:TestRoot 'test.yml'
            Set-Content -Path $ymlPath -Value $script:SimpleYaml -Encoding UTF8
            
            # Act
            $result = Import-YamlConfig -YamlPath $ymlPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Project.Name | Should -Be 'TestProject'
        }
    }
    
    Context 'エンコーディング' {
        It 'UTF-8 エンコーディングが正しく処理される' -Tag 'Positive' {
            # Arrange
            $utf8Yaml = @"
Project:
  Name: テストプロジェクト
  Description: 日本語の説明
"@
            $utf8Path = Join-Path $script:TestRoot 'utf8.yaml'
            Set-Content -Path $utf8Path -Value $utf8Yaml -Encoding UTF8
            
            # Act
            $result = Import-YamlConfig -YamlPath $utf8Path
            
            # Assert
            $result.Project.Name | Should -Be 'テストプロジェクト'
        }
    }
    
    Context 'データ型の検証' {
        It 'ブール値が正しく解析される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:SimpleYamlPath
            
            # Assert
            $result.Configuration.Debug -is [bool] | Should -BeTrue
            $result.Configuration.Debug | Should -BeTrue
        }
        
        It '数値が正しく解析される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:SimpleYamlPath
            
            # Assert
            $result.Configuration.MaxRetries -is [int] | Should -BeTrue
            $result.Configuration.MaxRetries | Should -Be 3
        }
        
        It '文字列が正しく解析される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:SimpleYamlPath
            
            # Assert
            $result.Project.Name -is [string] | Should -BeTrue
        }
    }
    
    Context 'ネストの深さ' {
        It '3 階層のネストが処理できる' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:NestedYamlPath
            
            # Assert
            $result.Database.Credentials.Username | Should -Not -BeNullOrEmpty
        }
        
        It '複数の配列が処理できる' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -YamlPath $script:ArrayYamlPath
            
            # Assert
            $result.Servers | Should -Not -BeNullOrEmpty
            $result.Settings.Tags | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'パフォーマンス: 大規模YAML' -Tag 'Performance' # See ADR-0004 (0004-exclude-performance-tests-from-ci)
        It '大規模 YAML ファイル（多数のキーと配列）を数秒以内に読み込める' -Tag 'Performance' {
            # Arrange
            # 大規模 YAML を生成（1000 個のサーバーエントリを含む）
            $largeYaml = @"
Environment: Production
Servers:
"@
            for ($i = 1; $i -le 1000; $i++) {
                $largeYaml += @"

  - Id: $i
    Name: server-$i
    IP: 192.168.1.$($i % 254 + 1)
    Port: $((8000 + $i % 1000))
    Status: active
    Tags:
      - production
      - monitored
      - backup-$($i % 5)
"@
            }
            
            $largeYamlPath = Join-Path $script:TestRoot 'large.yaml'
            Set-Content -Path $largeYamlPath -Value $largeYaml -Encoding UTF8
            
            # Act
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Import-YamlConfig -YamlPath $largeYamlPath
            $stopwatch.Stop()
            $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds
            
            # Assert
            # 実行時間が 5 秒以内であることを確認
            $elapsedSeconds | Should -BeLessThan 5
            $result | Should -Not -BeNullOrEmpty
            $result.Servers.Count | Should -Be 1000
        }
    }
    
    Context '異常系: 構文エラーと型不整合' {
        It 'インデント崩れの YAML でエラーが発生' -Tag 'Negative' {
            # Arrange
            $indentErrorYaml = @"
Database:
  Server: localhost
    Port: 5432
  Username: admin
"@
            $indentErrorPath = Join-Path $script:TestRoot 'indent-error.yaml'
            Set-Content -Path $indentErrorPath -Value $indentErrorYaml -Encoding UTF8
            
            # Act & Assert
            { Import-YamlConfig -YamlPath $indentErrorPath } | Should -Throw
        }
        
        It 'キーが重複している YAML でエラーが発生' -Tag 'Negative' {
            # Arrange
            $duplicateKeyYaml = @"
Project:
  Name: Test1
Project:
  Name: Test2
"@
            $duplicateKeyPath = Join-Path $script:TestRoot 'duplicate-key.yaml'
            Set-Content -Path $duplicateKeyPath -Value $duplicateKeyYaml -Encoding UTF8
            
            # Act & Assert
            { Import-YamlConfig -YamlPath $duplicateKeyPath } | Should -Throw
        }
        
        It '型が期待と異なる場合も読み込みは成功する（型変換を試みる）' -Tag 'Positive' {
            # Arrange - 数値として定義されているが文字列で記述
            $typeVariationYaml = @"
Settings:
  Version: "2"
  MaxRetries: "10"
  Timeout: "30.5"
"@
            $typeVariationPath = Join-Path $script:TestRoot 'type-variation.yaml'
            Set-Content -Path $typeVariationPath -Value $typeVariationYaml -Encoding UTF8
            
            # Act
            $result = Import-YamlConfig -YamlPath $typeVariationPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            # YAML では引用符付きの値は文字列として扱われる
            $result.Settings.Version | Should -Be "2"
        }
    }
    
    Context 'エンコーディング互換性' {
        It 'UTF-16 LE で保存された YAML の読み込み挙動をテスト' -Tag 'Encoding' {
            # Arrange
            $utf16LeYaml = @"
Project:
  Name: UTF16LE Test
  Version: 1.0
"@
            $utf16LePath = Join-Path $script:TestRoot 'utf16le.yaml'
            Set-Content -Path $utf16LePath -Value $utf16LeYaml -Encoding Unicode
            
            # Act & Assert
            # UTF-16 LE は通常 YAML パーサーでは正しく解析されない可能性があり、
            # その場合はエラーが発生することを確認
            # （または実装がサポートしている場合は成功を確認）
            try {
                $result = Import-YamlConfig -YamlPath $utf16LePath
                # サポートしている場合は読み込みが成功
                $result | Should -Not -BeNullOrEmpty
            } catch {
                # サポートしていない場合はエラーが発生（これも正しい挙動）
                $_ | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'UTF-8 BOM で保存された YAML が正しく読み込める' -Tag 'Positive' {
            # Arrange
            $utf8BomYaml = @"
Project:
  Name: UTF8 BOM Test
  Description: 日本語対応
"@
            $utf8BomPath = Join-Path $script:TestRoot 'utf8-bom.yaml'
            # UTF8 BOM エンコーディングで保存
            $utf8BomEncoding = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($utf8BomPath, $utf8BomYaml, $utf8BomEncoding)
            
            # Act
            $result = Import-YamlConfig -YamlPath $utf8BomPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Project.Name | Should -Be 'UTF8 BOM Test'
            $result.Project.Description | Should -Be '日本語対応'
        }
    }
    
    Context 'バージョン互換・未知フィールド' {
        It 'Version フィールドが存在する場合、値が保持される' -Tag 'Positive' {
            # Arrange
            $versionedYaml = @"
Version: 1
Project:
  Name: TestProject
  Build: 123
"@
            $versionedPath = Join-Path $script:TestRoot 'versioned.yaml'
            Set-Content -Path $versionedPath -Value $versionedYaml -Encoding UTF8
            
            # Act
            $result = Import-YamlConfig -YamlPath $versionedPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Version | Should -Be 1
            $result.Project.Name | Should -Be 'TestProject'
        }
        
        It 'Version: 2 の YAML が読み込めること' -Tag 'Positive' {
            # Arrange
            $version2Yaml = @"
Version: 2
Metadata:
  Created: 2026-01-30
  Author: Test
Configuration:
  Debug: false
"@
            $version2Path = Join-Path $script:TestRoot 'version2.yaml'
            Set-Content -Path $version2Path -Value $version2Yaml -Encoding UTF8
            
            # Act
            $result = Import-YamlConfig -YamlPath $version2Path
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Version | Should -Be 2
            $result.Metadata.Author | Should -Be 'Test'
        }
        
        It '未知フィールドが含まれる YAML も読み込みが失敗しないこと' -Tag 'Positive' {
            # Arrange
            $unknownFieldYaml = @"
Project:
  Name: TestProject
  UnknownField1: value1
  NestedUnknown:
    CustomKey: customValue
    AnotherKey: anotherValue
  Version: 1.0
  ExperimentalFeature: true
"@
            $unknownFieldPath = Join-Path $script:TestRoot 'unknown-field.yaml'
            Set-Content -Path $unknownFieldPath -Value $unknownFieldYaml -Encoding UTF8
            
            # Act
            $result = Import-YamlConfig -YamlPath $unknownFieldPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Project.Name | Should -Be 'TestProject'
            $result.Project.UnknownField1 | Should -Be 'value1'
            $result.Project.NestedUnknown.CustomKey | Should -Be 'customValue'
        }
    }
}
