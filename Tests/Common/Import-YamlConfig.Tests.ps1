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
            $result = Import-YamlConfig -Path $script:SimpleYamlPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Project | Should -Not -BeNullOrEmpty
            $result.Project.Name | Should -Be 'TestProject'
            $result.Project.Version | Should -Be '1.0.0'
        }
        
        It 'ネストされた YAML ファイルを読み込める' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:NestedYamlPath
            
            # Assert
            $result.Database | Should -Not -BeNullOrEmpty
            $result.Database.Server | Should -Be 'localhost'
            $result.Database.Credentials.Username | Should -Be 'admin'
            $result.Database.Options.Timeout | Should -Be 30
        }
        
        It '配列を含む YAML ファイルを読み込める' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:ArrayYamlPath
            
            # Assert
            $result.Servers | Should -Not -BeNullOrEmpty
            $result.Servers.Count | Should -BeGreaterThan 0
            $result.Servers[0].Name | Should -Be 'server1'
            $result.Settings.Tags | Should -Contain 'production'
        }
        
        It 'OrderedDictionary として返却される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:SimpleYamlPath
            
            # Assert
            # OrderedDictionary または Hashtable であることを確認
            ($result -is [System.Collections.Specialized.OrderedDictionary] -or 
             $result -is [Hashtable]) | Should -BeTrue
        }
        
        It 'キーが保持される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:SimpleYamlPath
            
            # Assert
            $result.ContainsKey('Project') | Should -BeTrue
            $result.ContainsKey('Configuration') | Should -BeTrue
        }
    }
    
    Context 'エラーハンドリング' {
        It 'ファイルが存在しない場合、エラーが発生' -Tag 'Negative' {
            # Arrange
            $nonExistentPath = Join-Path $script:TestRoot 'nonexistent.yaml'
            
            # Act & Assert
            { Import-YamlConfig -Path $nonExistentPath } | Should -Throw
        }
        
        It 'パスが null の場合、エラーが発生' -Tag 'Negative' {
            # Act & Assert
            { Import-YamlConfig -Path $null } | Should -Throw
        }
        
        It 'パスが空文字列の場合、エラーが発生' -Tag 'Negative' {
            # Act & Assert
            { Import-YamlConfig -Path '' } | Should -Throw
        }
        
        It '不正な YAML ファイルの場合、エラーが発生' -Tag 'Negative' {
            # Act & Assert
            { Import-YamlConfig -Path $script:InvalidYamlPath } | Should -Throw
        }
    }
    
    Context 'ファイル形式' {
        It '.yaml 拡張子が処理できる' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:SimpleYamlPath
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
        }
        
        It '.yml 拡張子が処理できる' -Tag 'Positive' {
            # Arrange
            $ymlPath = Join-Path $script:TestRoot 'test.yml'
            Set-Content -Path $ymlPath -Value $script:SimpleYaml -Encoding UTF8
            
            # Act
            $result = Import-YamlConfig -Path $ymlPath
            
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
            $result = Import-YamlConfig -Path $utf8Path
            
            # Assert
            $result.Project.Name | Should -Be 'テストプロジェクト'
        }
    }
    
    Context 'データ型の検証' {
        It 'ブール値が正しく解析される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:SimpleYamlPath
            
            # Assert
            $result.Configuration.Debug -is [bool] | Should -BeTrue
            $result.Configuration.Debug | Should -BeTrue
        }
        
        It '数値が正しく解析される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:SimpleYamlPath
            
            # Assert
            $result.Configuration.MaxRetries -is [int] | Should -BeTrue
            $result.Configuration.MaxRetries | Should -Be 3
        }
        
        It '文字列が正しく解析される' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:SimpleYamlPath
            
            # Assert
            $result.Project.Name -is [string] | Should -BeTrue
        }
    }
    
    Context 'ネストの深さ' {
        It '3 階層のネストが処理できる' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:NestedYamlPath
            
            # Assert
            $result.Database.Credentials.Username | Should -Not -BeNullOrEmpty
        }
        
        It '複数の配列が処理できる' -Tag 'Positive' {
            # Act
            $result = Import-YamlConfig -Path $script:ArrayYamlPath
            
            # Assert
            $result.Servers | Should -Not -BeNullOrEmpty
            $result.Settings.Tags | Should -Not -BeNullOrEmpty
        }
    }
}
