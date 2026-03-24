Describe 'InstMain' -Tag 'Integration', 'Script' {
	BeforeAll {
		$script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "InstMainTest_$(New-Guid)"
		New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null

		$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
		$projectRoot = Join-Path $repoRoot '必要なモジュールの導入'
		$scriptDir = Join-Path $projectRoot 'Script'
		$yamlDir = Join-Path $projectRoot 'YAML'
		$script:CommonDir = Join-Path $repoRoot 'Common'
		$script:ScriptDir = $scriptDir
		$script:InstMainPath = Join-Path $scriptDir 'InstMain.ps1'
		$script:LogDir = Join-Path $projectRoot 'LOG'
		$script:YamlDir = $yamlDir

		. (Join-Path $script:CommonDir 'Write-CommonLog.ps1')
		$wcFunc = Get-Item -Path 'Function:Write-CommonLog' -ErrorAction SilentlyContinue
		if ($null -ne $wcFunc) {
			Set-Item -Path 'Function:script:Write-CommonLog' -Value $wcFunc.ScriptBlock
		}

		$script:CreatedLogFiles = [System.Collections.Generic.List[string]]::new()
		$script:LogMessages = [System.Collections.Generic.List[string]]::new()
		$script:QuietValues = [System.Collections.Generic.List[bool]]::new()

		function script:New-MockYaml {
			param(
				[string]$PowerShellVersion = ($PSVersionTable.PSVersion).ToString(),
				[switch]$ListStyle,
				[switch]$Broken
			)

			if ($Broken) {
				return @{ PowerShell = @{ Version = '???' } }
			}

			if ($ListStyle) {
				return @{
					PowerShell = @{ Version = $PowerShellVersion }
					ModuleList = @(
						@{ Name = 'powershell-yaml'; RequiredVersion = '0.4.7' }
						@{ Name = 'SqlServer'; RequiredVersion = '22.1.1' }
						@{ Name = 'ImportExcel'; RequiredVersion = '7.8.5' }
					)
				}
			}

			return [ordered]@{
				Project = 'InstallModule'
				Version = '1.0.0'
				PowerShell = [ordered]@{
					Version = $PowerShellVersion
				}
				Module = [ordered]@{
					'powershell-yaml' = @{ Name = 'powershell-yaml'; Version = '0.4.7' }
					'SqlServer' = @{ Name = 'SqlServer'; Version = '22.1.1' }
					'ImportExcel' = @{ Name = 'ImportExcel'; Version = '7.8.5' }
				}
			}
		}

		function script:Initialize-InstMainTestEnvironment {
			param(
				[Parameter(Mandatory)]
				[hashtable]$MockYaml
			)

			. (Join-Path $script:CommonDir 'NoDoubleActivation.ps1')
			. (Join-Path $script:CommonDir 'Write-CommonLog.ps1')
			. (Join-Path $script:ScriptDir 'Check-EnvModule.ps1')
			. (Join-Path $script:ScriptDir 'Check-YamlModule.ps1')

			# Dot-source を関数内で実行するとスコープが閉じるため、必要な関数を script: に昇格する
			foreach ($functionName in @('Test-NoDoubleActivation', 'Test-EnvModule', 'Test-YamlModule')) {
				$functionItem = Get-Item -Path ("Function:$functionName") -ErrorAction SilentlyContinue
				if ($null -ne $functionItem) {
					Set-Item -Path ("Function:script:$functionName") -Value $functionItem.ScriptBlock
				}
			}

			Mock Test-YamlModule { $true }
			Mock Test-NoDoubleActivation { $true }
			Mock ConvertFrom-Yaml { $MockYaml }
			Mock Install-Module {}
			Mock Write-Error {}
			Mock Invoke-Item {}
		}

		function script:Enable-WriteCommonLogCapture {
			$script:LogMessages = [System.Collections.Generic.List[string]]::new()
			$script:QuietValues = [System.Collections.Generic.List[bool]]::new()

			Mock Write-CommonLog {
				param($Message, $LogPath, $Level, $Quiet)
				if (-not [string]::IsNullOrWhiteSpace($Message)) {
					[void]$script:LogMessages.Add($Message)
				}
				[void]$script:QuietValues.Add([bool]$Quiet)
			}
		}

	}

	AfterAll {
		if ($script:CreatedLogFiles -and $script:CreatedLogFiles.Count -gt 0) {
			$createdLogFiles = $script:CreatedLogFiles.ToArray() | Where-Object { Test-Path $_ }
			if ($createdLogFiles.Count -gt 0) {
				Remove-Item -Path $createdLogFiles -Force
			}
		}

		if (Test-Path $script:TestRoot) {
			Remove-Item -Path $script:TestRoot -Recurse -Force
		}
	}

	Context '正常系: すべてのモジュールが既にインストール済み' {
		It 'ログファイルが生成され、基本ヘッダが出力されること' {
			# Arrange: テスト環境の準備
			$existingLogFiles = @(Get-ChildItem -Path $script:LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue)
			$existingLogPaths = @($existingLogFiles.FullName)
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml

			Mock Test-EnvModule { $true }
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml' -ShowInConsole

			# Assert: ログ内容の検証
			$logFile = Get-ChildItem -Path $script:LogDir -Filter '*.log' -File |
				Sort-Object LastWriteTime -Descending |
				Select-Object -First 1

			$logFile | Should -Not -BeNullOrEmpty
			Test-Path $logFile.FullName | Should -Be $true
			$logFile.FullName | Should -Not -BeIn $existingLogPaths

			if ($script:CreatedLogFiles -notcontains $logFile.FullName) {
				[void]$script:CreatedLogFiles.Add($logFile.FullName)
			}

			$logContent = Get-Content -Path $logFile.FullName
			$joinedLogContent = $logContent -join [Environment]::NewLine

			$joinedLogContent | Should -Match 'HOST: '
			$joinedLogContent | Should -Match 'USER: '
			$joinedLogContent | Should -Match 'Running PowerShell Version: '
			$joinedLogContent | Should -Match '\[\[\[START\]\]\]'
			$joinedLogContent | Should -Match '\[\[\[END\]\]\]'
			$joinedLogContent | Should -Match 'InstallModule'
			$joinedLogContent | Should -Match 'Version: 1\.0\.0'
		}

		It '各モジュールについて EXIST ログが出力されること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml

			Mock Test-EnvModule {
				param(
					[string]$ModuleName,
					[string]$ModuleVersion
				)
				$currentLog = Get-ChildItem -Path $script:LogDir -Filter '*.log' -File |
					Sort-Object LastWriteTime -Descending |
					Select-Object -First 1
				if ($null -ne $currentLog) {
					Add-Content -Path $currentLog.FullName -Value "[INFO] - [EXIST] $ModuleName Version: $ModuleVersion" -Encoding UTF8
				}
				$true
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml' -ShowInConsole

			# Assert: ログ内容の検証
			$logFile = Get-ChildItem -Path $script:LogDir -Filter '*.log' -File |
				Sort-Object LastWriteTime -Descending |
				Select-Object -First 1

			$logFile | Should -Not -BeNullOrEmpty

			[string]$joinedLogContent = (Get-Content -Path $logFile.FullName) -join [Environment]::NewLine
			$joinedLogContent | Should -Match '\[EXIST\].*powershell-yaml'
			$joinedLogContent | Should -Match '\[EXIST\].*SqlServer'
			$joinedLogContent | Should -Match '\[EXIST\].*ImportExcel'
		}

		It '各モジュールについて EXIST ログが Write-CommonLog 経由で出力されること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule {
				param(
					[string]$ModuleName,
					[string]$ModuleVersion
				)
				Write-CommonLog -Message "[EXIST] $ModuleName Version: $ModuleVersion" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
				$true
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml' -ShowInConsole

			# Assert: ログ内容の検証
			$script:LogMessages | Should -Not -BeNullOrEmpty
			$allMessages = $script:LogMessages -join [Environment]::NewLine
			$allMessages | Should -Match '\[EXIST\].*powershell-yaml'
			$allMessages | Should -Match '\[EXIST\].*SqlServer'
			$allMessages | Should -Match '\[EXIST\].*ImportExcel'
		}
	}

	Context '正常系: 一部モジュールが未インストールで INSTALL される' {
		It '未インストールのモジュールについて INSTALL ログが出力されること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule {
				param(
					[string]$ModuleName,
					[string]$ModuleVersion
				)

				$installedModule = Get-Module -ListAvailable -Name $ModuleName

				if ($null -eq $installedModule) {
					Write-CommonLog -Message "[NOTHING] $ModuleName" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
					Write-CommonLog -Message "[INSTALL] $ModuleName Version: $ModuleVersion をインストール中..." -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
					Install-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -Scope CurrentUser -ErrorAction Stop
					Write-CommonLog -Message "[INSTALL] $ModuleName Version: $ModuleVersion をインストールしました" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
					return $true
				}

				Write-CommonLog -Message "[EXIST] $ModuleName Version: $ModuleVersion" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
				return $true
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return $null }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: ログ内容の検証
			$script:LogMessages | Should -Not -BeNullOrEmpty
			$allMessages = $script:LogMessages -join [Environment]::NewLine
			$allMessages | Should -Match '\[INSTALL\].*SqlServer'
		}

		It 'Install-Module が必要な回数だけ呼び出されること (Mock 前提)' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Mock Test-EnvModule {
				param(
					[string]$ModuleName,
					[string]$ModuleVersion
				)

				$installedModule = Get-Module -ListAvailable -Name $ModuleName

				if ($null -eq $installedModule) {
					Write-CommonLog -Message "[NOTHING] $ModuleName" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
					Write-CommonLog -Message "[INSTALL] $ModuleName Version: $ModuleVersion をインストール中..." -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
					Install-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -Scope CurrentUser -ErrorAction Stop
					Write-CommonLog -Message "[INSTALL] $ModuleName Version: $ModuleVersion をインストールしました" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
					return $true
				}

				Write-CommonLog -Message "[EXIST] $ModuleName Version: $ModuleVersion" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
				return $true
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return $null }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			Mock Write-CommonLog {}

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: 呼び出し回数の検証
			Assert-MockCalled Install-Module -Times 1
			Assert-MockCalled Test-EnvModule -Times 3
		}
	}

	Context 'PowerShell バージョン不一致 (ユーザーが「はい」で続行)' {
		It 'バージョン不一致の警告ダイアログが表示されること (Mock 前提)' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml -PowerShellVersion '0.0.1'
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml

			$script:PopupCallCount = 0
			Mock Test-EnvModule {
				$script:CanExecuteProcess = $false
				$true
			}
			Mock Write-CommonLog {}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					$script:PopupCallCount++
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: ダイアログ表示の検証
			Assert-MockCalled New-Object -Times 1 -ParameterFilter { $ComObject -eq 'WScript.Shell' }
		}

		It 'ユーザーが はい を選択した場合に処理が継続すること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml -PowerShellVersion '0.0.1'
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule {
				param(
					[string]$ModuleName,
					[string]$ModuleVersion
				)
				Write-CommonLog -Message "[EXIST] $ModuleName Version: $ModuleVersion" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
				$true
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			Mock Write-CommonLog {
				param($Message, $LogPath, $Level, $Quiet)
				if ($Message -match '\[EXIST\]') {
					[void]$script:LogMessages.Add($Message)
				}
				[void]$script:QuietValues.Add([bool]$Quiet)
			}
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: 継続動作の検証
			$script:LogMessages | Should -Match '\[EXIST\]'
		}
	}

	Context 'PowerShell バージョン不一致 (ユーザーが「いいえ」で中止)' {
		It 'ユーザーが いいえ を選択した場合に処理が中断されること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml -PowerShellVersion '0.0.1'
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule { $true }
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 7
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: 中断動作の検証
			$script:LogMessages | Should -BeNullOrEmpty
			Assert-MockCalled Write-CommonLog -Times 0
		}

		It 'モジュールのインストール処理が実行されないこと' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml -PowerShellVersion '0.0.1'
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			# Mock 各種
			Mock Test-EnvModule { $true }     # 呼ばれないことを assert する
			Mock Install-Module {}            # 呼ばれないことを assert する

			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer'       { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel'     { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }

			# Popup → No（7）
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member ScriptMethod Popup {
					param($Message, $Timeout, $Title, $Type)
					return 7
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: 中断動作の検証
			# → モジュールループに入っていないので LogMessages は空のはず
			$script:LogMessages | Should -BeNullOrEmpty

			# Test-EnvModule は一度も呼ばれない
			Assert-MockCalled Test-EnvModule -Times 0

			# Install-Module も呼ばれない
			Assert-MockCalled Install-Module -Times 0

			# Write-CommonLog も呼ばれない（EXIST/INSTALL）
			Assert-MockCalled Write-CommonLog -Times 0 -ParameterFilter { $Message -match '\[(EXIST|INSTALL)\]' }
		}
	}

	Context '二重起動検出 (Test-NoDoubleActivation が false を返す場合)' {
		It '二重起動検出時に begin ブロックで処理が終了すること' {
			# Arrange: テスト環境の準備
			$script:WarningMessages = [System.Collections.Generic.List[string]]::new()

			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-NoDoubleActivation { $false }
			Mock Test-EnvModule { $true }
			Mock Write-Warning {
				param($Message)
				[void]$script:WarningMessages.Add($Message)
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member ScriptMethod Popup {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: begin ブロック終了の検証
			($script:WarningMessages -join [Environment]::NewLine) | Should -Match '既に起動中'
			Assert-MockCalled Write-Warning -Times 1 -ParameterFilter { $Message -eq '既に起動中のため処理を終了します' }
			Assert-MockCalled Test-YamlModule -Times 0
			Assert-MockCalled Test-EnvModule -Times 0
			Assert-MockCalled Install-Module -Times 0
		}

		It 'process / end ブロックの処理がスキップされること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml -ListStyle
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-NoDoubleActivation { $false }
			Mock Test-EnvModule { $true }

			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer'       { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel'     { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }

			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member ScriptMethod Popup {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: スキップの検証
			($script:LogMessages -join [Environment]::NewLine) | Should -Not -Match '\[EXIST\]'
			($script:LogMessages -join [Environment]::NewLine) | Should -Not -Match '\[INSTALL\]'
			Assert-MockCalled Test-EnvModule -Times 0
			Assert-MockCalled Install-Module -Times 0
		}
	}

	Context 'YAML 読み込みエラー (Env.yaml が壊れている、または存在しない)' {
		It 'Env.yaml 読み込みエラー時にエラーダイアログが表示されること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml -Broken
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml

			Mock Test-EnvModule { $true }
			Mock ConvertFrom-Yaml { throw 'YAML parse error (mock)' }
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			Mock Write-CommonLog {}

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: エラー通知の検証
			Assert-MockCalled New-Object -Times 1 -ParameterFilter { $ComObject -eq 'WScript.Shell' }
		}

		It 'YAML 読み込みエラー発生後にモジュール処理が実行されないこと' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml -Broken
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule { $true }
			Mock ConvertFrom-Yaml { throw 'YAML parse error (mock)' }
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: 非実行の検証
			$script:LogMessages | Should -BeNullOrEmpty
			Assert-MockCalled Test-EnvModule -Times 0
			Assert-MockCalled Install-Module -Times 0
		}
	}

	Context '共通スクリプト読み込みエラー (Write-CommonLog.ps1 や Check-EnvModule.ps1 などが読み込めない)' {
		It '共通スクリプトのドットソースに失敗した場合にエラーダイアログが表示されること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			$writeCommonLogPath = Join-Path $script:CommonDir 'Write-CommonLog.ps1'
			$backupPath = "$writeCommonLogPath.bak"

			Rename-Item -Path $writeCommonLogPath -NewName $backupPath -Force

			try {
				. (Join-Path $script:CommonDir 'NoDoubleActivation.ps1')
				. (Join-Path $script:ScriptDir 'Check-EnvModule.ps1')
				. (Join-Path $script:ScriptDir 'Check-YamlModule.ps1')

				Mock Test-YamlModule { $true }
				Mock Test-NoDoubleActivation { $true }
				Mock Test-EnvModule { $true }
				Mock ConvertFrom-Yaml { throw 'YAML should not be read in this scenario' }
				Mock Install-Module {}
				Mock Invoke-Item {}
				Mock Write-Error {}
				Mock Get-Module {
					switch ($Name) {
						'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
						'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
						'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
						default { return $null }
					}
				} -ParameterFilter { $ListAvailable }
				Mock New-Object {
					$wshShell = [pscustomobject]@{}
					$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
						param($Message, $Timeout, $Title, $Type)
						return 6
					} -Force
					return $wshShell
				} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
				Mock Write-CommonLog {
					param($Message, $LogPath, $Level, $Quiet)
					if ($Message -match '\[EXIST\]') {
						[void]$script:LogMessages.Add($Message)
					}
					[void]$script:QuietValues.Add([bool]$Quiet)
				}

				# Act: InstMain.ps1 の実行
				. $script:InstMainPath -envFileName 'Env.yaml'

				# Assert: エラー通知の検証
				Assert-MockCalled New-Object -Times 1 -ParameterFilter { $ComObject -eq 'WScript.Shell' }
				Assert-MockCalled Test-YamlModule -Times 0
				Assert-MockCalled Test-EnvModule -Times 0

			} finally {
				if (Test-Path $backupPath) {
					Rename-Item -Path $backupPath -NewName $writeCommonLogPath -Force
				}
			}
		}

		It '共通スクリプト読み込みエラー発生後に処理が継続しないこと' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			$writeCommonLogPath = Join-Path $script:CommonDir 'Write-CommonLog.ps1'
			$backupPath = "$writeCommonLogPath.bak"

			Rename-Item -Path $writeCommonLogPath -NewName $backupPath -Force

			try {
				. (Join-Path $script:CommonDir 'NoDoubleActivation.ps1')
				. (Join-Path $script:ScriptDir 'Check-EnvModule.ps1')
				. (Join-Path $script:ScriptDir 'Check-YamlModule.ps1')

				Mock Test-YamlModule { $true }
				Mock Test-NoDoubleActivation { $true }
				Mock Test-EnvModule { $true }
				Mock ConvertFrom-Yaml { throw 'YAML should not be read in this scenario' }
				Mock Install-Module {}
				Mock Invoke-Item {}
				Mock Write-Error {}
				Mock Get-Module {
					switch ($Name) {
						'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
						'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
						'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
						default { return $null }
					}
				} -ParameterFilter { $ListAvailable }
				Mock New-Object {
					$wshShell = [pscustomobject]@{}
					$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
						param($Message, $Timeout, $Title, $Type)
						return 6
					} -Force
					return $wshShell
				} -ParameterFilter { $ComObject -eq 'WScript.Shell' }

				# Act
				. $script:InstMainPath -envFileName 'Env.yaml'

				# Assert: モジュール処理は一切行われない
				Assert-MockCalled Test-YamlModule -Times 0
				Assert-MockCalled Test-EnvModule -Times 0
				Assert-MockCalled Install-Module -Times 0

			} finally {
				if (Test-Path $backupPath) {
					Rename-Item -Path $backupPath -NewName $writeCommonLogPath -Force
				}
			}
		}
	}

	Context '-envFileName パラメーターによる YAML 切り替え' {
		It '-envFileName で別の YAML を指定した場合に、その内容がログに反映されること' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule {
				param(
					[string]$ModuleName,
					[string]$ModuleVersion
				)
				Write-CommonLog -Message "[EXIST] $ModuleName Version: $ModuleVersion" -LogPath 'mock.log' -Level 'INFO' -Quiet:$false
				$true
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Test.yaml'

			# Assert: 反映内容の検証
			$script:LogMessages | Should -Not -BeNullOrEmpty
			$allMessages = $script:LogMessages -join [Environment]::NewLine
			$allMessages | Should -Match 'InstallModule'
			$allMessages | Should -Match 'Version: 1\.0\.0'
			$allMessages | Should -Match 'powershell-yaml'
			$allMessages | Should -Match 'SqlServer'
			$allMessages | Should -Match 'ImportExcel'
		}

		It 'YAML に定義されたモジュール構成に応じて Test-EnvModule の呼び出し内容が変わること' {
			# Arrange: テスト環境の準備
			$script:CalledModules = @()
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Mock Test-EnvModule {
				param(
					[string]$ModuleName,
					[string]$ModuleVersion
				)
				$script:CalledModules += ('{0}:{1}' -f $ModuleName, $ModuleVersion)
				$true
			}
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			Mock Write-CommonLog {}

			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Test.yaml'

			# Assert: 呼び出し内容の検証
			$script:CalledModules | Should -Not -BeNullOrEmpty
			$script:CalledModules | Should -Contain 'powershell-yaml:0.4.7'
			$script:CalledModules | Should -Contain 'SqlServer:22.1.1'
			$script:CalledModules | Should -Contain 'ImportExcel:7.8.5'
			$script:CalledModules.Count | Should -Be 3
		}
	}

	Context '-ShowInConsole スイッチの動作' {
		It '-ShowInConsole 指定時に Write-CommonLog の Quiet パラメーターが false になること (Mock 前提)' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule { $true }
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml' -ShowInConsole

			# Assert: パラメーター値の検証
			$script:QuietValues | Should -Not -BeNullOrEmpty
			foreach ($quietValue in $script:QuietValues) {
				$quietValue | Should -Be $false
			}
		}

		It 'デフォルト実行時に Quiet パラメーターが true になること (Mock 前提)' {
			# Arrange: テスト環境の準備
			$mockYaml = New-MockYaml
			Initialize-InstMainTestEnvironment -MockYaml $mockYaml
			Enable-WriteCommonLogCapture

			Mock Test-EnvModule { $true }
			Mock Get-Module {
				switch ($Name) {
					'powershell-yaml' { return [pscustomobject]@{ Version = [version]'0.4.7' } }
					'SqlServer' { return [pscustomobject]@{ Version = [version]'22.1.1' } }
					'ImportExcel' { return [pscustomobject]@{ Version = [version]'7.8.5' } }
					default { return $null }
				}
			} -ParameterFilter { $ListAvailable }
			Mock New-Object {
				$wshShell = [pscustomobject]@{}
				$wshShell | Add-Member -MemberType ScriptMethod -Name Popup -Value {
					param($Message, $Timeout, $Title, $Type)
					return 6
				} -Force
				return $wshShell
			} -ParameterFilter { $ComObject -eq 'WScript.Shell' }
			# Act: InstMain.ps1 の実行
			. $script:InstMainPath -envFileName 'Env.yaml'

			# Assert: パラメーター値の検証
			$script:QuietValues | Should -Not -BeNullOrEmpty
			foreach ($quietValue in $script:QuietValues) {
				$quietValue | Should -Be $true
			}
		}
	}
}



