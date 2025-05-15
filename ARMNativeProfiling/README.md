# ARM Native Profiling Guide

This guide provides comprehensive information about profiling ARM applications to identify performance-critical code paths and determine their native code composition.

## Required Tools
Windows Performance Recorder (WPR)   - Ships with Windows - [Documentation](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/)

Before getting started, you'll need to install:
- Windows Performance Analyzer (WPA) - Any WPA version should work for this purpose
  - [Download from Microsoft Store](https://www.microsoft.com/en-us/p/windows-performance-analyzer-preview/9n58qrw40dfw) or [ADK](https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewADK)

## Using Windows Performance Tools for ARM Code Analysis

Windows Performance Recorder (WPR) and Windows Performance Analyzer (WPA) are powerful tools that help you identify hot code paths in your application and determine whether they are running as native ARM64 code or being emulated.

### Setting Up Performance Recording

1. **Start Recording with WPR**
   ```powershell
   # Start recording with the GeneralProfile
   wpr -start GeneralProfile
   ```

2. **Run Your Scenario**
   - Launch your application
   - Execute the specific workflow you want to analyze
   - Ensure you perform the actions long enough to get meaningful data

3. **Stop Recording**
   ```powershell
   # Stop recording and save the ETL file
   wpr -stop MyProfile.etl
   ```

### Analyzing with Windows Performance Analyzer (WPA)

1. **Open the ETL File**
   - Launch Windows Performance Analyzer
   - Open your captured ETL file
   - Wait for the initial processing to complete
   - Symbols can be helpful but not required to see hot dlls and what is native

2. **Finding Hot Code Paths**
   Navigate to these key analysis tables:
   - **CPU Usage (Sampled)**: Shows where CPU time is being spent
     - You can filter to your app or process

3. **Identifying Native vs Emulated Code**
   
   Easy method
   - Download and apply WPR profile with preset tables & view


   Manually, In the CPU Sampling table:
   - Add the "Module" column in the 
   - Use the "Weight" or "Count" columns to identify the most impactful code paths

4. **Key Analysis Steps for hot Functions **

   Symbols are required to be loaded for your app for function level analysis

   1. Already sorted by "Weight" to find the hottest functions
   2. Examine the call stacks of high-weight items
   3. Look for patterns of emulated code in performance-critical paths
   4. Note which DLLs contribute most to emulated execution

### Optimization Priorities

Based on the WPA analysis:

1. **High-Impact Targets**
   - Functions with high CPU usage running under emulation
   - Frequently called emulated functions
   - Critical path operations running non-natively

2. **Quick Wins**
   - Identify emulated DLLs with native alternatives
   - Look for ARM64EC alternatives for x64 dependencies
   - Consider recompiling frequently used internal modules as native ARM64

## Best Practices

- Record multiple runs of your scenario for consistent results
- Focus on real-world usage patterns
- Pay special attention to startup performance
- Pay special attention to performance running under benchmarks
- Look for patterns in emulated code usage
- Consider both frequency and duration of function calls

## Additional Resources

### Essential Tools and Documentation
- [Windows Performance Recorder (WPR) Documentation](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/) - Official documentation for WPR, including setup and usage guides
- [Windows Performance Analyzer (WPA) Download](https://www.microsoft.com/en-us/p/windows-performance-analyzer-preview/9n58qrw40dfw) - Get the latest version from the Microsoft Store
- [Windows Performance Toolkit Documentation](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/)
- [ARM64EC Documentation](https://learn.microsoft.com/en-us/windows/arm/arm64ec)
- [Performance Analysis Tools](https://learn.microsoft.com/en-us/windows/win32/performance/performance-tools)

## Next Steps

After identifying hot code paths and their native/emulated status:
1. Prioritize native ARM64 conversion based on performance impact
2. Consider ARM64EC for challenging x64 dependencies
3. Evaluate third-party dependencies for ARM64 alternatives
4. Measure performance improvements after each optimization
