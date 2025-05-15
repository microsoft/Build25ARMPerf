<#
.SYNOPSIS
    Analyzes binaries to determine how much code is native to the current processor architecture.

.DESCRIPTION
    This script analyzes Windows executables and DLLs to determine what percentage of code is native to the
    current processor architecture (ARM64 or AMD64). It uses dumpbin.exe and link.exe from Visual Studio
    to examine the binaries and outputs a table with details including native code percentage, file information,
    and digital signature data.

    Limitations: Only works for static dependencies. Dynamic dependencies (loaded at runtime) are not analyzed.
    May have trouble finding .dlls in certain directories, although SearchPaths can be specified to help with this.

.PARAMETER Path
    Required. The path to the executable or DLL to analyze.

.PARAMETER Full
    Optional. If specified, recursively analyzes all dependent DLLs.

.PARAMETER Depth
    Optional. Specifies the maximum recursion depth for dependency analysis.
    Default is 1, meaning only the direct dependencies of the main executable are analyzed.
    Set to 0 to analyze only the main executable without dependencies.
    Set to a higher number to analyze deeper dependency chains.

.EXAMPLE
    .\Analyze-BinaryArchitecture.ps1 "C:\Program Files\Example\example.exe"
    Analyzes only the specified executable.

.EXAMPLE
    .\Analyze-BinaryArchitecture.ps1 "C:\Program Files\Example\example.exe" -Full
    Analyzes the executable and all its direct dependencies (depth 1).

.EXAMPLE
    .\Analyze-BinaryArchitecture.ps1 "C:\Program Files\Example\example.exe" -Full -Depth 2
    Analyzes the executable, its direct dependencies, and dependencies of those dependencies.

.NOTES
    Requires Visual Studio with developer command prompt tools installed.
    Must be run on Windows 11 with ARM64 or AMD64 architecture.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path,
    
    [Parameter(Mandatory=$false)]
    [switch]$Full,
    
    [Parameter(Mandatory=$false)]
    [int]$Depth = 1,
    
    [Parameter(Mandatory=$false)]
    [string[]]$SearchPaths = @()
)

#region Functions

function Test-DumpbinAvailable {
    $dumpbin = Get-Command "dumpbin.exe" -ErrorAction SilentlyContinue
    $link = Get-Command "link.exe" -ErrorAction SilentlyContinue
    
    if (-not $dumpbin -or -not $link) {
        Write-Host "Error: dumpbin.exe and/or link.exe not found in PATH." -ForegroundColor Red
        Write-Host "Please install Visual Studio and run this script from a Visual Studio Developer Command Prompt." -ForegroundColor Yellow
        exit 1
    }
    
    # Display paths for debugging
    Write-Verbose "Using dumpbin.exe from: $($dumpbin.Source)"
    Write-Verbose "Using link.exe from: $($link.Source)"
    
    return $true
}

function Get-BinaryType {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: File not found: $FilePath" -ForegroundColor Red
        return $null
    }
    
    try {
        $output = & dumpbin.exe /headers $FilePath 2>&1
        
        Write-Debug "Analyzing binary type for: $FilePath"
        
        # Debug: Output the full dumpbin.exe output with line numbers for debugging
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug')) {
            Write-Host "===== DUMPBIN.EXE OUTPUT START =====" -ForegroundColor Magenta
            $lineNum = 1
            foreach ($line in $output) {
                Write-Host "[$lineNum]: $line"
                $lineNum++
            }
            Write-Host "===== DUMPBIN.EXE OUTPUT END =====" -ForegroundColor Magenta
        }
        
        $machineType = ""
        $binaryType = ""
        
        # Special check for ARM64X binaries
        $isArm64x = $false
        foreach ($line in $output) {
            if ($line -match "ARM64X") {
                $isArm64x = $true
                Write-Debug "Found ARM64X indicator in headers"
                break
            }
        }
        
        foreach ($line in $output) {
            if ($line -match "\s+(\w+)\s+machine\s+\((.*?)\)") {
                $machineType = $matches[1]
                $archDesc = $matches[2]
                
                Write-Debug "Found machine type: $machineType ($archDesc)"
                
                # If we found ARM64X anywhere in the headers, use that
                if ($isArm64x) {
                    $binaryType = "ARM64X"
                } 
                # Otherwise use the machine type to determine binary type
                elseif ($machineType -eq "8664") {
                    $binaryType = "x64"
                }
                elseif ($machineType -eq "14C") {
                    $binaryType = "x86"
                }
                elseif ($machineType -eq "AA64") {
                    $binaryType = "ARM64"
                }
                elseif ($machineType -eq "1C4") {
                    $binaryType = "ARM"
                }
                else {
                    $binaryType = "Unknown"
                }
                
                Write-Debug "Determined binary type: $binaryType"
                break
            }
        }
        
        return $binaryType
    }
    catch {
        Write-Host "Error analyzing binary type for $FilePath`: $_" -ForegroundColor Red
        return "Error"
    }
}

function Get-CodeRanges {
    param (
        [string]$FilePath,
        [string]$BinaryType
    )
    
    if ($BinaryType -ne "ARM64X") {
        # For non-ARM64X binaries, we'll determine native code percentage based on architecture match
        $currentArch = $env:PROCESSOR_ARCHITECTURE
        
        # Simple mapping for standard binaries
        if ($currentArch -eq "ARM64" -and $BinaryType -eq "ARM64") {
            return @{
                NativePercentage = 100
                NativeCodeSize = (Get-Item $FilePath).Length
                NonNativeCodeSize = 0
            }
        }
        elseif ($currentArch -eq "AMD64" -and $BinaryType -eq "x64") {
            return @{
                NativePercentage = 100
                NativeCodeSize = (Get-Item $FilePath).Length
                NonNativeCodeSize = 0
            }
        }
        elseif ($BinaryType -eq "Error" -or $BinaryType -eq "Unknown") {
            return @{
                NativePercentage = 0
                NativeCodeSize = 0
                NonNativeCodeSize = 0
            }
        }
        else {
            # Non-native binary
            return @{
                NativePercentage = 0
                NativeCodeSize = 0
                NonNativeCodeSize = (Get-Item $FilePath).Length
            }
        }
    }
    
    try {
        Write-Debug "Analyzing code ranges for: $FilePath"
        
        $output = & link.exe /dump /loadconfig $FilePath 2>&1

        # Debug: Output the full link.exe output with line numbers for debugging
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug')) {
            Write-Host "===== LINK.EXE OUTPUT START =====" -ForegroundColor Magenta
            $lineNum = 1
            foreach ($line in $output) {
                Write-Host "[$lineNum]: $line"
                $lineNum++
            }
            Write-Host "===== LINK.EXE OUTPUT END =====" -ForegroundColor Magenta
        }
        
        $arm64Size = 0
        $arm64ecSize = 0
        $x64Size = 0
        $foundHybridTable = $false
        $foundAddressRange = $false
        
        foreach ($line in $output) {
            if ($line -cmatch "Hybrid Code Address Range Table") {
                $foundHybridTable = $true
                continue
            }
            if ($line -cmatch "Address Range") {
                $foundAddressRange = $true
                continue
            }
            
            if ($foundHybridTable -and $foundAddressRange) {
                # Write-Verbose "Link: $line"
                if ($line -match "arm64\s+(\w+)\s+-\s+(\w+)\s+\((\w+)\s+-\s+(\w+)\)") {
                    $start = [Convert]::ToInt64($matches[3], 16)
                    $end = [Convert]::ToInt64($matches[4], 16)
                    $arm64Size = $end - $start + 1
                    Write-Debug "Found ARM64 range: $($matches[3])-$($matches[4]), Size: $arm64Size bytes"
                }
                elseif ($line -match "arm64ec\s+(\w+)\s+-\s+(\w+)\s+\((\w+)\s+-\s+(\w+)\)") {
                    $start = [Convert]::ToInt64($matches[3], 16)
                    $end = [Convert]::ToInt64($matches[4], 16)
                    $arm64ecSize = $end - $start + 1
                    Write-Debug "Found ARM64EC range: $($matches[3])-$($matches[4]), Size: $arm64ecSize bytes"
                }
                elseif ($line -match "x64\s+(\w+)\s+-\s+(\w+)\s+\((\w+)\s+-\s+(\w+)\)") {
                    $start = [Convert]::ToInt64($matches[3], 16)
                    $end = [Convert]::ToInt64($matches[4], 16)
                    $x64Size = $end - $start + 1
                    Write-Debug "Found X64 range: $($matches[3])-$($matches[4]), Size: $x64Size bytes"
                }
                
                # If we find a blank line after the table, break out
                if ([string]::IsNullOrWhiteSpace($line)) {
                    break
                }
            }
        }
        
        $totalSize = $arm64Size + $arm64ecSize + $x64Size
        
        # Calculate native code percentage based on current architecture
        $currentArch = $env:PROCESSOR_ARCHITECTURE
        $nativeSize = 0
        
        if ($currentArch -eq "ARM64") {
            $nativeSize = $arm64Size + $arm64ecSize
        }
        elseif ($currentArch -eq "AMD64") {
            $nativeSize = $x64Size
        }
        
        # Print the values for debugging
        Write-Debug "ARM64 Size: $arm64Size bytes"
        Write-Debug "ARM64EC Size: $arm64ecSize bytes"
        Write-Debug "X64 Size: $x64Size bytes"
        Write-Debug "Total Size: $totalSize bytes"
        Write-Debug "Native Size: $nativeSize bytes"
        
        $nativePercentage = if ($totalSize -gt 0) { ($nativeSize / $totalSize) * 100 } else { 0 }
        
        return @{
            NativePercentage = [math]::Round($nativePercentage, 2)
            NativeCodeSize = $nativeSize
            NonNativeCodeSize = $totalSize - $nativeSize
        }
    }
    catch {
        Write-Host "Error analyzing code ranges for $FilePath`: $_" -ForegroundColor Red
        return @{
            NativePercentage = 0
            NativeCodeSize = 0
            NonNativeCodeSize = 0
        }
    }
}

function Get-Dependencies {
    param (
        [string]$FilePath,
        [int]$CurrentDepth = 0
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: File not found: $FilePath" -ForegroundColor Red
        return @()
    }
    
    try {
        Write-Host "Getting dependencies for: $FilePath    Depth:$CurrentDepth" -ForegroundColor Cyan
        
        $output = & dumpbin.exe /dependents $FilePath 2>&1
        $dependencies = @()
        $foundDependencies = $false
        
        # Debug: Output the full dumpbin.exe output with line numbers for debugging
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug')) {
            Write-Host "===== DUMPBIN DEPENDENCIES OUTPUT START =====" -ForegroundColor Magenta
            $lineNum = 1
            foreach ($line in $output) {
                Write-Host "[$lineNum]: $line"
                $lineNum++
            }
            Write-Host "===== DUMPBIN DEPENDENCIES OUTPUT END =====" -ForegroundColor Magenta
        }
        
        foreach ($line in $output) {
            # Look for the section header
            if ($line -match "Image has the following dependencies:") {
                $foundDependencies = $true
                continue
            }
            
            # Capture dependency entries - try to handle different output formats
            if ($foundDependencies) {
                if ($line -match "^\s+(\S+\.dll)") {
                    $dependencies += $matches[1]
                    Write-Debug "Found dependency: $($matches[1])"
                }
                
                # Look for end of section markers
                if ($line -match "Summary" -or $line -match "^$" -or $line -match "^\s*$") {
                    # If we've found dependencies and hit a summary or blank line, we're done
                    if ($dependencies.Count -gt 0) {
                        break
                    }
                }
            }
        }
        
        Write-Verbose "Found $($dependencies.Count) dependencies for $FilePath"
        return $dependencies
    }
    catch {
        Write-Host "Error getting dependencies for $FilePath`: $_" -ForegroundColor Red
        return @()
    }
}

function Get-FileVersionInfo {
    param (
        [string]$FilePath
    )
    
    try {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        $fileInfo = Get-Item $FilePath
        
        # Get digital signature information
        $signature = $null
        try {
            $signature = Get-AuthenticodeSignature $FilePath -ErrorAction SilentlyContinue
            $signer = if ($signature.Status -eq "Valid") { $signature.SignerCertificate.Subject.Split(',')[0].Trim() } else { "Unsigned" }
        }
        catch {
            $signer = "Error getting signature"
        }
        
        return @{
            Name = $fileInfo.Name
            FullPath = $fileInfo.FullName
            SizeInMB = [math]::Round($fileInfo.Length / 1MB, 2)
            FileDescription = $versionInfo.FileDescription
            ProductName = $versionInfo.ProductName
            FileVersion = $versionInfo.FileVersion
            Copyright = $versionInfo.LegalCopyright
            DigitalSignature = $signer
        }
    }
    catch {
        Write-Host "Error getting file version info for $FilePath`: $_" -ForegroundColor Red
        
        return @{
            Name = (Split-Path $FilePath -Leaf)
            FullPath = $FilePath
            SizeInMB = 0
            FileDescription = "Error"
            ProductName = "Error"
            FileVersion = "Error"
            Copyright = "Error"
            DigitalSignature = "Error"
        }
    }
}

function Get-BinaryInfo {
    param (
        [string]$FilePath
    )
    
    $resolvedPath = Resolve-Path $FilePath -ErrorAction SilentlyContinue
    
    if (-not $resolvedPath) {
        Write-Host "Error: Could not resolve path: $FilePath" -ForegroundColor Red
        return $null
    }
    
    $fullPath = $resolvedPath.Path
    
    Write-Debug "Processing: $fullPath"
    
    try {
        # Get binary type
        $binaryType = Get-BinaryType -FilePath $fullPath
        Write-Verbose "Determined binary type: $binaryType for $fullPath"
        
        # Get code ranges and calculate native percentage
        $codeInfo = Get-CodeRanges -FilePath $fullPath -BinaryType $binaryType
        Write-Verbose "Calculated native percentage: $($codeInfo.NativePercentage)% for $fullPath"
        
        # Get file version information
        $versionInfo = Get-FileVersionInfo -FilePath $fullPath
        Write-Debug "Retrieved file version info for $fullPath"
        
        # Combine all information
        $result = [PSCustomObject]@{
            Name = $versionInfo.Name
            FullPath = $versionInfo.FullPath
            BinaryType = $binaryType
            NativePercentage = $codeInfo.NativePercentage
            NativeCodeSizeInMB = [math]::Round($codeInfo.NativeCodeSize / 1MB, 2)
            NonNativeCodeSizeInMB = [math]::Round($codeInfo.NonNativeCodeSize / 1MB, 2)
            TotalSizeInMB = $versionInfo.SizeInMB
            FileDescription = $versionInfo.FileDescription
            ProductName = $versionInfo.ProductName
            FileVersion = $versionInfo.FileVersion
            Copyright = $versionInfo.Copyright
            DigitalSignature = $versionInfo.DigitalSignature
        }
        
        return $result
    }
    catch {
        Write-Host "Error processing binary info for $fullPath`: $_" -ForegroundColor Red
        
        # Return minimal information for failed binary analysis
        return [PSCustomObject]@{
            Name = (Split-Path $fullPath -Leaf)
            FullPath = $fullPath
            BinaryType = "Error"
            NativePercentage = 0
            NativeCodeSizeInMB = 0
            NonNativeCodeSizeInMB = 0
            TotalSizeInMB = (Get-Item $fullPath -ErrorAction SilentlyContinue).Length / 1MB
            FileDescription = "Error processing binary"
            ProductName = "Unknown"
            FileVersion = "Unknown"
            Copyright = "Unknown"
            DigitalSignature = "Unknown"
        }
    }
}

# Helper function to resolve dependency paths
$script:missingDependencies = @{}

function Resolve-DependencyPath {
    param (
        [string]$DependencyName,
        [string]$SourceFilePath,
        [string[]]$AdditionalSearchPaths = @()
    )
    
    # Skip the search if we already know this dependency can't be found
    if ($script:missingDependencies.ContainsKey($DependencyName) -or 
        $script:missingApiSetDependencies.ContainsKey($DependencyName)) {
        return $null
    }

    if (Test-IsApiSet -DllName $DependencyName) {
        Write-Debug "Skipping API Set dependency: $DependencyName"
        $script:missingApiSetDependencies[$DependencyName] = $true
        return $null
    }

    Write-Debug "Resolving dependency: $DependencyName from $SourceFilePath"
    
    # Check application directory first
    $appDir = Split-Path $SourceFilePath -Parent
    $possiblePath = Join-Path $appDir $DependencyName
    if (Test-Path $possiblePath) {
        Write-Debug "Found dependency in application directory: $possiblePath"
        return $possiblePath
    }
    
    # Check user-provided and auto-discovered additional search paths
    foreach ($searchDir in $AdditionalSearchPaths) {
        if ([string]::IsNullOrEmpty($searchDir)) { continue }
        
        $possiblePath = Join-Path $searchDir $DependencyName
        if (Test-Path $possiblePath) {
            Write-Verbose "Found dependency in additional search path: $possiblePath"
            return $possiblePath
        }
    }
    
    # Continue with standard system directories
    $systemDirs = @(
        # System directories
        "$env:windir\System32",
        "$env:windir\SysWOW64",
        "$env:windir\system",
        "$env:windir",
        # Common directories
        "$env:ProgramFiles\Common Files",
        "$env:ProgramFiles(x86)\Common Files",
        # ARM64-specific directories
        "$env:windir\SyChpe32",
        "$env:windir\SysArm32"
    )
    
    foreach ($dir in $systemDirs) {
        if ([string]::IsNullOrEmpty($dir)) { continue }
        
        $possiblePath = Join-Path $dir $DependencyName
        if (Test-Path $possiblePath) {
            Write-Debug "Found dependency in system directory: $possiblePath"
            return $possiblePath
        }
    }
    
    # Check PATH directories
    foreach ($dir in $env:PATH.Split(';')) {
        if ([string]::IsNullOrEmpty($dir)) { continue }
        
        $possiblePath = Join-Path $dir $DependencyName
        if (Test-Path $possiblePath) {
            Write-Debug "Found dependency in PATH: $possiblePath"
            return $possiblePath
        }
    }
    
    # If we get here, we couldn't find the dependency
    # Record it so we don't search for it again and report it
    $script:missingDependencies[$DependencyName] = $true
    Write-Warning "Warning: Could not locate dependency $DependencyName"

    return $null
}

$script:missingApiSetDependencies = @{}
function Test-IsApiSet {
    param (
        [string]$DllName
    )
    
    # API Set naming patterns
    return $DllName -match "^api-ms-win-" -or 
           $DllName -match "^ext-ms-win-" -or 
           $DllName -match "^Microsoft-Windows-"
}

function Get-SearchPaths {
    param (
        [string]$ExePath,
        [string[]]$AdditionalPaths = @()
    )
    
    $searchPaths = New-Object System.Collections.Generic.HashSet[string]
    
    # Add user-specified paths first (highest priority)
    foreach ($path in $AdditionalPaths) {
        if (Test-Path $path) {
            [void]$searchPaths.Add($path)
        }
    }
    
    # Add the executable's directory
    $exeDir = Split-Path -Path $ExePath -Parent
    [void]$searchPaths.Add($exeDir)
    
    # Scan all subfolders of the executable's directory
    Write-Host "Scanning subfolders of $exeDir for potential DLL locations..." -ForegroundColor Cyan
    $subfolders = Get-ChildItem -Path $exeDir -Directory -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    foreach ($subfolder in $subfolders) {
        [void]$searchPaths.Add($subfolder)
    }
    
    # Check if exe is in Program Files and look for matching ProgramData folder
    if ($exeDir -match "\\Program Files(?:\s\(x86\))?\\([^\\]+)\\([^\\]+)") {
        $company = $matches[1]
        $product = $matches[2]
        
        $programDataPath = Join-Path -Path $env:ProgramData -ChildPath "$company\$product"
        if (Test-Path $programDataPath) {
            Write-Host "Found matching ProgramData folder: $programDataPath" -ForegroundColor Cyan
            [void]$searchPaths.Add($programDataPath)
            
            # Add subfolders from ProgramData as well
            $programDataSubfolders = Get-ChildItem -Path $programDataPath -Directory -Recurse -ErrorAction SilentlyContinue | 
                                      Select-Object -ExpandProperty FullName
            foreach ($subfolder in $programDataSubfolders) {
                [void]$searchPaths.Add($subfolder)
            }
        }
    }
    
    # Return the unique set of paths
    return $searchPaths
}

#endregion

# Main script execution
$ErrorActionPreference = "Stop"

# Display script banner
Write-Host @"
=========================================================
Binary Architecture Analyzer v1.0
=========================================================
This script analyzes binaries to determine how much code 
is native to the current processor architecture.
"@ -ForegroundColor Cyan

# Validate input parameters
if (-not $Path) {
    Write-Host "Error: Path parameter is required." -ForegroundColor Red
    Write-Host "Usage: .\Analyze-BinaryArchitecture.ps1 <Path> [-Full]" -ForegroundColor Yellow
    exit 1
}

# Check OS version
$osInfo = Get-CimInstance Win32_OperatingSystem
$osVersion = [System.Version]$osInfo.Version
$isWindows10OrNewer = $osVersion.Major -ge 10

if (-not $isWindows10OrNewer) {
    Write-Host "Error: This script requires Windows 10 or Windows 11." -ForegroundColor Red
    exit 1
}

# Check if the system architecture is supported
$supportedArchitectures = @("ARM64", "AMD64")
if ($supportedArchitectures -notcontains $env:PROCESSOR_ARCHITECTURE) {
    Write-Host "Warning: Current architecture $env:PROCESSOR_ARCHITECTURE may not be fully supported. Script is optimized for $($supportedArchitectures -join ' or ')." -ForegroundColor Yellow
}

# Check if dumpbin is available
if (-not (Test-DumpbinAvailable)) {
    exit 1
}

# Resolve the input path
if (-not (Test-Path $Path)) {
    Write-Host "Error: File not found: $Path" -ForegroundColor Red
    exit 1
}

$resolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue

if (-not $resolvedPath) {
    Write-Host "Error: Could not resolve path: $Path" -ForegroundColor Red
    exit 1
}

$fullPath = $resolvedPath.Path

# Display script information
$currentArch = $env:PROCESSOR_ARCHITECTURE
Write-Host "Current Architecture: $currentArch" -ForegroundColor Cyan
Write-Host "Analysis Mode: $(if ($Full) {"Recursive with max depth $Depth"} else {"Single Binary"})" -ForegroundColor Cyan

# Display recursion depth information
if ($Full) {
    Write-Host "Note: Higher depth values will increase analysis time significantly." -ForegroundColor Yellow
    if ($Depth -gt 2) {
        Write-Host "Warning: Depth $Depth may result in very long analysis times." -ForegroundColor Red
        Write-Host "Consider starting with depth 1 or 2 for initial analysis." -ForegroundColor Yellow
        $confirmation = Read-Host "Continue with depth $Depth? (Y/N)"
        if ($confirmation -ne "Y" -and $confirmation -ne "y") {
            Write-Host "Analysis cancelled. Restart with a lower depth value." -ForegroundColor Red
            exit
        }
    }
}

# Initialize results collection
$results = @()
$processedFiles = @{}

# Discover additional search paths if in Full mode
$discoveredSearchPaths = @()
if ($Full) {
    Write-Verbose "Discovering additional search paths..."
    $discoveredSearchPaths = Get-SearchPaths -ExePath $fullPath -AdditionalPaths $SearchPaths
    Write-Verbose "Found $(($discoveredSearchPaths | Measure-Object).Count) potential search paths for DLL resolution"
    
    # Display the first few paths if verbose
    if ($VerbosePreference -eq 'Continue') {
        $pathCount = [Math]::Min(5, $discoveredSearchPaths.Count)
        Write-Verbose "First $pathCount search paths:"
        for ($i = 0; $i -lt $pathCount; $i++) {
            Write-Verbose "  - $($discoveredSearchPaths[$i])"
        }
        if ($discoveredSearchPaths.Count -gt $pathCount) {
            Write-Verbose "  - ... and $($discoveredSearchPaths.Count - $pathCount) more" 
        }
    }
}

# Get binary info for the main executable
$mainBinaryInfo = Get-BinaryInfo -FilePath $fullPath
# Add depth information to the main executable
$mainBinaryInfo | Add-Member -NotePropertyName "Depth" -NotePropertyValue 0 -Force
$results += $mainBinaryInfo
$processedFiles[$fullPath.ToLower()] = $true

# If -Full is specified, process dependencies recursively up to the specified depth
if ($Full -and $Depth -gt 0) {
    Write-Host "Analyzing dependencies" -ForegroundColor Cyan
    
    # Initialize counters for each depth level
    $depthInfo = @{}
    for ($i = 0; $i -le $Depth; $i++) {
        $depthInfo[$i] = @{
            Processed = 0
            Total = 0
            FilesToProcess = @()
        }
    }
    
    # First level is just the main file
    $depthInfo[0].Total = 1
    $depthInfo[0].Processed = 1
    
    # Get initial dependencies to set up the first depth level
    $initialDependencies = Get-Dependencies -FilePath $fullPath -CurrentDepth 1
    $depthInfo[1].Total = 0  # Will count actual resolvable dependencies
    
    # Set up first level of dependencies to process
    foreach ($dependency in $initialDependencies) {
        $dependencyPath = Resolve-DependencyPath -DependencyName $dependency -SourceFilePath $fullPath
        if ($dependencyPath -and -not $processedFiles.ContainsKey($dependencyPath.ToLower())) {
            $depthInfo[1].FilesToProcess += $dependencyPath
            $depthInfo[1].Total++
        }
    }
    
    # Process each depth level
    for ($currentDepth = 1; $currentDepth -le $Depth; $currentDepth++) {
        $currentDepthInfo = $depthInfo[$currentDepth]
        $nextDepth = $currentDepth + 1
        
        # Skip this depth if no files to process
        if ($currentDepthInfo.FilesToProcess.Count -eq 0) {
            continue
        }
        
        # Process all files at current depth
        foreach ($file in $currentDepthInfo.FilesToProcess) {
            # Skip if already processed
            if ($processedFiles.ContainsKey($file.ToLower())) {
                continue
            }
            
            # Update processed count
            $currentDepthInfo.Processed++
            
            # Update progress
            $statusMessage = "Processing file $($currentDepthInfo.Processed) of $($currentDepthInfo.Total) (Depth:$currentDepth)"
            $percentComplete = if ($currentDepthInfo.Total -gt 0) {
                [Math]::Min(($currentDepthInfo.Processed / $currentDepthInfo.Total) * 100, 100)
            } else {
                -1
            }
            Write-Progress -Activity "Analyzing dependencies" -Status $statusMessage -PercentComplete $percentComplete
            
            # Process the current file
            $binaryInfo = Get-BinaryInfo -FilePath $file
            if ($binaryInfo) {
                # Add depth information
                $binaryInfo | Add-Member -NotePropertyName "Depth" -NotePropertyValue $currentDepth -Force
                $results += $binaryInfo
                $processedFiles[$file.ToLower()] = $true
                
                # Get next level dependencies if not at max depth
                if ($currentDepth -lt $Depth) {
                    $dependencies = Get-Dependencies -FilePath $file -CurrentDepth $nextDepth
                    
                    # Initialize next depth level if needed
                    if (-not $depthInfo.ContainsKey($nextDepth)) {
                        $depthInfo[$nextDepth] = @{
                            Processed = 0
                            Total = 0
                            FilesToProcess = @()
                        }
                    }
                    
                    # Add dependencies to next level
                    foreach ($dependency in $dependencies) {
                        $dependencyPath = Resolve-DependencyPath -DependencyName $dependency -SourceFilePath $file
                        if ($dependencyPath -and -not $processedFiles.ContainsKey($dependencyPath.ToLower()) -and 
                            -not $depthInfo[$nextDepth].FilesToProcess.Contains($dependencyPath)) {
                            $depthInfo[$nextDepth].FilesToProcess += $dependencyPath
                            $depthInfo[$nextDepth].Total++
                        }
                    }
                }
            }
        }
        
        # Complete progress for this depth level
        Write-Progress -Activity "Analyzing dependencies" -Status "Completed depth level $currentDepth" -Completed
    }
    
    # Output summary of files processed at each depth level
    Write-Host "Dependency analysis complete:" -ForegroundColor Green
    for ($i = 0; $i -le $Depth; $i++) {
        if ($depthInfo.ContainsKey($i)) {
            Write-Host "  - Depth {$i}: $($depthInfo[$i].Processed) files" -ForegroundColor Cyan
        } else {
            Write-Host "  - Depth {$i}: 0 files" -ForegroundColor Cyan
        }
    }
}

# Sort results by FullPath
$results = $results | Sort-Object -Property FullPath

# Calculate statistics
if ($results.Count -gt 0) {
    # Create summary statistics
    $totalBinaries = $results.Count
    $nativeBinaries = @($results | Where-Object { $_.NativePercentage -eq 100 }).Count
    $hybridBinaries = @($results | Where-Object { $_.NativePercentage -gt 0 -and $_.NativePercentage -lt 100 }).Count
    $nonNativeBinaries = @($results | Where-Object { $_.NativePercentage -eq 0 }).Count
    
    $totalNativeCode = ($results | Measure-Object -Property NativeCodeSizeInMB -Sum).Sum
    $totalCode = ($results | Measure-Object -Property TotalSizeInMB -Sum).Sum
    $nonNativeCode = $totalCode - $totalNativeCode
    
    $overallNativePercentage = if ($totalCode -gt 0) { ($totalNativeCode / $totalCode) * 100 } else { 0 }
    
    # Output summary
    Write-Host "`n======== Binary Analysis Summary ========" -ForegroundColor Cyan
    Write-Host "Current Architecture: $currentArch" -ForegroundColor Cyan
    Write-Host "Path Analyzed: $fullPath" -ForegroundColor Cyan
    Write-Host "Analysis Mode: $(if ($Full) {"Recursive (Depth: $Depth)"} else {"Single Binary"})" -ForegroundColor Cyan
    Write-Host "Total Binaries: $totalBinaries" -ForegroundColor White
    Write-Host "  - 100% Native: $nativeBinaries" -ForegroundColor Green
    Write-Host "  - Hybrid (partial native): $hybridBinaries" -ForegroundColor Yellow
    Write-Host "  - 0% Native: $nonNativeBinaries" -ForegroundColor Red
    Write-Host "Total Size: $([math]::Round($totalCode, 2)) MB" -ForegroundColor White
    Write-Host "  - Native Code: $([math]::Round($totalNativeCode, 2)) MB ($([math]::Round($overallNativePercentage, 2))%)" -ForegroundColor Green
    Write-Host "  - Non-Native Code: $([math]::Round($nonNativeCode, 2)) MB ($([math]::Round(100 - $overallNativePercentage, 2))%)" -ForegroundColor Yellow
    Write-Host "======================================" -ForegroundColor Cyan
}

# Output results
if ($Full) {
    # Group by depth for better readability
    Write-Host "`nBinary Analysis Results (Grouped by Depth):" -ForegroundColor Cyan
    
    # Get unique depth values
    $depths = $results | Select-Object -ExpandProperty Depth -Unique | Sort-Object
    
    foreach ($depth in $depths) {
        Write-Host "`nDepth Level {$depth}:" -ForegroundColor Magenta
        $results | Where-Object { $_.Depth -eq $depth } | 
            Format-Table -Property Name, BinaryType, @{Label="Native%"; Expression={$_.NativePercentage}}, 
                @{Label="Size(MB)"; Expression={$_.TotalSizeInMB}}, 
                FileDescription, FileVersion, DigitalSignature -AutoSize
    }
} else {
    # Standard output for single binary analysis
    $results | Format-Table -Property Name, BinaryType, @{Label="Native%"; Expression={$_.NativePercentage}}, 
        @{Label="Size(MB)"; Expression={$_.TotalSizeInMB}}, 
        FileDescription, FileVersion, DigitalSignature -AutoSize
}

if ($VerbosePreference -eq 'Continue' -and $script:missingDependencies.Count -gt 0) {
    if ($script:missingDependencies.Count -gt 0) {
        Write-Host "`n====== Missing Dependencies Summary ======" -ForegroundColor Yellow
        Write-Host "The following $($script:missingDependencies.Count) dependencies could not be located:" -ForegroundColor Yellow
        
        foreach ($dep in $script:missingDependencies.Keys | Sort-Object) {
            Write-Host "  - $dep" -ForegroundColor Yellow
        }
        
        Write-Host "Note: Missing dependencies may impact the accuracy of the analysis." -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Yellow
    }
}

Write-Host "To view full details including paths, run: `$results | Format-List" -ForegroundColor Yellow
Write-Host "To export results to CSV, run: `$results | Export-Csv -Path 'BinaryAnalysis.csv' -NoTypeInformation" -ForegroundColor Yellow

# Export the results variable
#$results