# ARMNativeAppScan

A PowerShell script for analyzing Windows executables and their dependencies to determine how much of the code is native to the current processor architecture (ARM64 or AMD64).

## Overview

`Analyze-BinaryArchitecture.ps1` is a powerful tool that helps developers understand the composition of their applications in terms of native versus non-native code. This is particularly useful for applications running on Windows on ARM, where understanding the mix of native ARM64 code versus emulated x64/x86 code is crucial for performance optimization.

## Features

- **Static Binary Analysis**: Examines executables without running them
- **Recursive Dependency Scanning**: Analyzes all dependent DLLs up to a specified depth
- **Detailed Code Composition**: Shows percentage and size of native vs non-native code
- **Comprehensive Reporting**: Provides detailed reports with file information, versions, and architecture details
- **Support for ARM64EC**: Properly identifies and analyzes ARM64EC binaries

## Prerequisites

- Windows 10 or Windows 11 (ARM64 or AMD64)
- Visual Studio with developer command prompt tools installed
- PowerShell 5.1 or later

## Usage

```powershell
# Basic analysis of a single executable
.\Analyze-BinaryArchitecture.ps1 -Path "C:\Program Files\Example\example.exe"

# Full recursive analysis of executable and dependencies
.\Analyze-BinaryArchitecture.ps1 -Path "C:\Program Files\Example\example.exe" -Full

# Analysis with custom recursion depth
.\Analyze-BinaryArchitecture.ps1 -Path "C:\Program Files\Example\example.exe" -Full -Depth 2

# Analysis with additional search paths for dependencies
.\Analyze-BinaryArchitecture.ps1 -Path "C:\Program Files\Example\example.exe" -Full -SearchPaths @("C:\CustomDLLs", "D:\SharedLibs")
```

## Parameters

- **Path** (Required): Path to the executable or DLL to analyze
- **Full** (Optional): If specified, recursively analyzes all dependent DLLs
- **Depth** (Optional): Maximum recursion depth for dependency analysis (Default: 1)
- **SearchPaths** (Optional): Additional paths to search for dependencies

## Output

The script provides:
1. Summary statistics including:
   - Total number of binaries analyzed
   - Count of fully native, hybrid, and non-native binaries
   - Total code size and native/non-native code distribution
2. Detailed information for each binary:
   - File name and path
   - Binary type (Native ARM64, x64, ARM64EC, etc.)
   - Native code percentage
   - File size and version information
   - Digital signature status

## Example Output

```
======== Binary Analysis Summary ========
Current Architecture: ARM64
Path Analyzed: C:\Program Files\Example\example.exe
Analysis Mode: Recursive (Depth: 1)
Total Binaries: 15
  - 100% Native: 8
  - Hybrid (partial native): 3
  - 0% Native: 4
Total Size: 25.5 MB
  - Native Code: 18.3 MB (71.76%)
  - Non-Native Code: 7.2 MB (28.24%)
======================================
```

## Limitations

- Only analyzes static dependencies (dynamically loaded DLLs are not detected)
- Requires Visual Studio developer tools
- May require elevated privileges to access system directories
- Performance may degrade with high recursion depths