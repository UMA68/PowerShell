# .NET Uninstall Tool Manager (DotNetUninstallTool.ps1)

日本語: [Readme.md](./Readme.md)

This script manages installing and uninstalling the .NET Uninstall Tool (`dotnet-core-uninstall`) with an interactive menu and a YAML-driven configuration (v1.1.0). It supports a dry-run mode (`-WhatIf`) so you can preview actions safely. A log file is always created and automatically opened at the end.

---

## Table of Contents

- [.NET Uninstall Tool Manager (DotNetUninstallTool.ps1)](#net-uninstall-tool-manager-dotnetuninstalltoolps1)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [v1.1.0 Improvements](#v110-improvements)
  - [Prerequisites](#prerequisites)
  - [Folder Layout](#folder-layout)
  - [Quick Start](#quick-start)
  - [WhatIf Behavior](#whatif-behavior)
  - [Logging](#logging)
  - [YAML Config](#yaml-config)
  - [Flow](#flow)
  - [Exit Codes](#exit-codes)
  - [Error Handling](#error-handling)
    - [CanExecuteProcess Flag](#canexecuteprocess-flag)
    - [Get-ExceptionLogLevel Function](#get-exceptionloglevel-function)
    - [Helper Functions](#helper-functions)
  - [Troubleshooting](#troubleshooting)
  - [Manual Install (Reference)](#manual-install-reference)
  - [License / Links](#license--links)

---

## Features

- Centralized settings with YAML (MSI, timeouts, logs, exit codes, etc.)
- Administrator privilege check (can skip for debugging with `-SkipAdminCheck`)
- MSI presence check and unblocking
- Install/uninstall via `msiexec` with timeouts
- Auto-detect product code and install location from the registry
- Post-install/uninstall verification
- Log creation and auto-rotation; opens the log file at the end
- Double-run protection with a Mutex
- Dry-run (`-WhatIf`) support: logs the plan without making changes

---

## v1.1.0 Improvements

✅ **Enhanced Safety:**
- Removed all exit statements, unified to return statements (script invocation compatible)
- **CanExecuteProcess flag** for unified error flow control
- **Get-ExceptionLogLevel** function for automatic exception type classification (9 patterns)
- **Helper functions** (Open-LogIfNeeded, Stop-ProcessTree)
- **end block** reinforcement (guaranteed COM object release, automatic log opening)

See "Error Handling" section below for details.

---

## Prerequisites

- PowerShell 7.x or later (latest recommended)
- Module: `powershell-yaml`
  - If not installed (recommended from an elevated PowerShell):

    ```powershell
    Install-Module powershell-yaml -Scope CurrentUser -Force
    ```

- The common logger script exists at `Common/Write-CommonLog.ps1`
- This folder contains the YAML config: `YAML/DotNetUninstallTool.yaml`
- MSI file exists: `dotNetSdkUninstallTool/dotnet-core-uninstall.msi`

---

## Folder Layout

```text
dotNetSdkUninstallToolの入手/
├─ Readme.md                         ← Japanese documentation
├─ Readme.en.md                      ← This file
├─ Script/
│   └─ DotNetUninstallTool.ps1       ← The script to run (v1.1.0)
├─ YAML/
│   └─ DotNetUninstallTool.yaml      ← Config (ScriptVersion: 1.1.0)
├─ dotNetSdkUninstallTool/
│   └─ dotnet-core-uninstall.msi     ← MSI for installation
└─ LOG/                               ← Execution logs (auto-created/rotated)
```

---

## Quick Start

Preview safely (dry-run):

```powershell
pwsh -NoProfile -File ".\dotNetSdkUninstallToolの入手\Script\DotNetUninstallTool.ps1" -WhatIf -Verbose
```

Normal execution (will make changes; recommended from an elevated PowerShell):

```powershell
pwsh -NoProfile -File ".\dotNetSdkUninstallToolの入手\Script\DotNetUninstallTool.ps1" -Verbose
```

Skip the admin check for debugging only (not recommended for production):

```powershell
pwsh -NoProfile -File ".\dotNetSdkUninstallToolの入手\Script\DotNetUninstallTool.ps1" -SkipAdminCheck -Verbose
```

> When the menu appears, choose `1` (Install), `2` (Uninstall), or `Q` (Quit).

---

## WhatIf Behavior

- Operations guarded by `ShouldProcess` (Unblock-File / msiexec / folder deletion) are not executed.
- Instead, the script logs what would be executed as `[WhatIf]` lines.
- Log creation/appending and opening the log file at the end are always executed (not affected by `-WhatIf`).

---

## Logging

- Output folder: `dotNetSdkUninstallToolの入手/LOG/` (auto-created if missing)
- File name pattern: `DotNetUninstallTool_yyyyMMdd-HHmmss-fff.log`
- Rotation: Old logs are removed according to `YAML/LogCleanup.RetentionDays`
- The log file opens automatically at the end (even with `-WhatIf`)

---

## YAML Config

Target file: `YAML/DotNetUninstallTool.yaml`

Key sections (with examples):

- `Project`
  - `Name`: ".NET Uninstall Tool Management"
  - `ScriptVersion`: "1.1.0"
- `MSI`
  - `FileName`: "dotnet-core-uninstall.msi"
  - `ProductName`: "*Uninstall Tool*" (registry DisplayName search pattern)
- `Installation`
  - `DefaultPath`: `C:\\Program Files (x86)\\dotnet-core-uninstall`
  - `CommandName`: `dotnet-core-uninstall`
- `LOG`
  - `FILENAME`: `DotNetUninstallTool`
  - `EXTENSION`: `.log`
- `LogCleanup`
  - `Enabled`: `true`
  - `RetentionDays`: `30`
- `Timeout`
  - `InstallSeconds`: `300`
  - `UninstallSeconds`: `300`
  - `SleepAfterOperation`: `5`
- `PopupIcon`
  - `Error`: `0x10`
  - `Warning`: `0x30`
  - `Information`: `0x40`
- `ExitCode`
  - `Success`: `0`
  - `GeneralError`: `1`
  - `UserCancelled`: `2`
  - `InsufficientPrivileges`: `3`
  - `FileNotFound`: `4`
  - `InstallFailed`: `5`
  - `UninstallFailed`: `6`

---

## Flow

1. Read YAML → Initialize log → Check privileges → Acquire Mutex → Clean up old logs
2. Show menu (Install/Uninstall/Quit)
3. Install: Check MSI → Unblock → `msiexec /i` → Verify
4. Uninstall: Registry search → `msiexec /x` → Delete leftover folder → Verify
5. Clean up resources (Mutex, COM object) → Open log file automatically

---

## Exit Codes

- `0`: Success
- `1`: GeneralError
- `2`: UserCancelled
- `3`: InsufficientPrivileges
- `4`: FileNotFound
- `5`: InstallFailed
- `6`: UninstallFailed

---

## Error Handling

### CanExecuteProcess Flag

The script uses an internal `$script:CanExecuteProcess` flag for unified error handling:

- **Initialization** (begin block): Set to `$true`
- **On error**: Set to `false` + store exit code in `$script:ExitCode` + return
- **Cleanup** (end block): Check flag; if `false`, exit with stored code

This ensures resources are always cleaned up, even if an error occurs.

### Get-ExceptionLogLevel Function

Automatically determines the appropriate log level based on exception type:

| Exception Type | Log Level |
|---|---|
| FileNotFoundException, DirectoryNotFoundException | ERROR |
| UnauthorizedAccessException, ParsingException | ERROR |
| IOException, InvalidOperationException | ERROR |
| TimeoutException, OperationCanceledException | WARN |
| ArgumentException, ArgumentNullException | WARN |
| WebException, HttpRequestException | ERROR |
| Other | DEBUG |

### Helper Functions

- **Get-ExceptionLogLevel(Exception)** – Returns appropriate log level from exception type
- **Open-LogIfNeeded(LogPath)** – Opens log file (with existence check)
- **Stop-ProcessTree(ProcessId)** – Recursively kills process and children

---

## Troubleshooting

- `powershell-yaml` is missing
  - `Install-Module powershell-yaml -Scope CurrentUser -Force`
- Administrator privileges required
  - Run from an elevated PowerShell, or (for debugging only) use `-SkipAdminCheck`
- MSI not found
  - Check presence and path: `dotNetSdkUninstallTool/dotnet-core-uninstall.msi`
- Command not recognized after install
  - `dotnet-core-uninstall` may be recognized in a new session; restart PowerShell
- Log did not open
  - In case of errors, open `dotNetSdkUninstallToolの入手/LOG/` manually

---

## Manual Install (Reference)

You can install the MSI manually from the official releases:

- Releases: <https://github.com/dotnet/cli-lab/releases>
- Example: Download `dotnet-core-uninstall-1.x.x.msi` and run as Administrator
- Verify:

```powershell
dotnet-core-uninstall list
```

---

## License / Links

- Repository: <https://github.com/UMA68/PowerShell>
- License: See `LICENSE` in this repository
