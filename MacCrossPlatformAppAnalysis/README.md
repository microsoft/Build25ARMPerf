# macOS Cross-Platform Application Analysis

This guide explains how to analyze your application's performance across both macOS and Windows platforms using Windows Performance Analyzer (WPA). 

By using the Microsoft Performance Tools for Apple, you can capture traces on macOS and analyze them alongside Windows traces in WPA, enabling direct performance comparisons across platforms.

## Overview

The [Microsoft Performance Tools for Apple](https://github.com/microsoft/Microsoft-Performance-Tools-Apple) project enables developers to:
- Analyze Apple Instruments traces using the same tools as Windows traces
- Compare performance metrics across platforms consistently
- Use familiar WPA analysis techniques for macOS applications
- Understand performance characteristics in cross-platform scenarios

## Key Benefits

- **Unified Analysis**: Use the same tool (WPA) to analyze traces from both platforms
- **Consistent Methodology**: Apply identical analysis techniques across Windows and macOS
- **Cross-Platform Insights**: Directly compare performance metrics between platforms
- **Familiar Tools**: Leverage existing knowledge of WPA for macOS analysis

## Available Analysis Features

The tools support analysis of:
- Time Profile data
- CPU Counters
- Instruction and cycle-level metrics
- Thread sampling
- Performance counter data

## Getting Started

For detailed instructions on capturing traces, converting them for WPA, and performing analysis, please visit the [Microsoft Performance Tools for Apple repository](https://github.com/microsoft/Microsoft-Performance-Tools-Apple).

## Additional Resources

- [Microsoft Performance Tools for Apple](https://github.com/microsoft/Microsoft-Performance-Tools-Apple) - Main repository with detailed documentation
- [Windows Performance Analyzer (Preview)](https://www.microsoft.com/en-us/p/windows-performance-analyzer-preview/9n58qrw40dfw) - Required for analysis

## Microsoft Performance Tools for Apple

The [Microsoft Performance Tools for Apple](https://github.com/microsoft/Microsoft-Performance-Tools-Apple) project enables you to analyze Apple Instruments traces using the Windows Performance Analyzer. This allows for consistent analysis tools and methodologies across both platforms.

## Capturing Traces on macOS

### Using Instruments

1. **Install Prerequisites**
   - Install Xcode on your Mac device
   - Access Instruments via: Xcode -> Open Developer Tool -> Instruments

2. **Capture a Trace**
   - Open Instruments -> File -> New
   - Choose your profiling template
   - Start recording your scenario

3. **Configure Symbols (Optional)**
   - Open Instruments -> Settings
   - Add relevant paths to your local symbol files
   - Note: Symbol decoding must be done on Mac during capture

### Using xctrace (Command Line)

For automated or CI/CD scenarios, use xctrace:

```bash
# Basic time profiler trace
xctrace record --all-processes --template 'Time Profiler' --time-limit 5s

# For more options
xctrace help [command]
```

## Converting Traces for WPA

1. Download the trace export script from the [Microsoft Performance Tools for Apple repository](https://github.com/microsoft/Microsoft-Performance-Tools-Apple)
2. Make the script executable:
   ```bash
   chmod +x trace-export.sh
   ```
3. Convert your trace:
   ```bash
   ./trace-export.sh --input <tracefile.trace>
   ```

## Analyzing in WPA

1. **Install Required Tools**
   - [Windows Performance Analyzer (Preview)](https://www.microsoft.com/en-us/p/windows-performance-analyzer-preview/9n58qrw40dfw) from the Microsoft Store
   - [Microsoft Performance Tools Apple Plugin](https://github.com/microsoft/Microsoft-Performance-Tools-Apple/releases)

2. **Install the Plugin**
   - Open WPA
   - Click "Install Plugin"
   - Browse to the downloaded .ptix file

3. **Open and Analyze Traces**
   - Copy the exported .xml trace from Mac to Windows
   - Open in WPA
   - Use the same analysis techniques as with Windows traces

## Cross-Platform Comparison

Benefits of using WPA for cross-platform analysis:
- Consistent analysis tools and methodologies
- Direct comparison of performance metrics
- Same visualization and reporting capabilities
- Ability to analyze native vs emulated code paths

### Supported Analysis Features

- Time Profile data
- CPU Counters
- Instruction and cycle-level analysis
- Thread sampling
- Performance counter data

## Example: CPU Counter Analysis

To capture detailed CPU metrics on Mac:

1. In Instruments, create a new blank session
2. Add CPU Counters and Time Profile instruments
3. Configure Event-Based Sampling (e.g., 1M instructions)
4. Attach Cycle Delta measurements
5. Use Deferred recording in Record Settings

You can find a template for this configuration at:
`TraceTemplate/CPUCounterWithTimeProfile.tracetemplate`

## Best Practices

- Capture traces under similar workloads on both platforms
- Use consistent sampling rates when possible
- Consider platform-specific optimizations
- Look for patterns in performance differences
- Document and track cross-platform performance metrics

## Additional Resources

- [Microsoft Performance Tools for Apple Repository](https://github.com/microsoft/Microsoft-Performance-Tools-Apple)
- [Windows Performance Analyzer (Preview)](https://www.microsoft.com/en-us/p/windows-performance-analyzer-preview/9n58qrw40dfw)
- [xctrace Documentation](https://help.apple.com/instruments/mac/current/#/dev37f9f7fb1)
- [Instruments Documentation](https://help.apple.com/instruments/mac/current/) 