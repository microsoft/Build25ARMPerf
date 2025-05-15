# Build25ARMPerf Tools and Documentation

This repository contains tools and documentation for analyzing, profiling, and optimizing ARM64 applications on Windows and macOS platforms. It provides resources for developers to evaluate and improve the native code execution of their applications.

## Repository Structure

### [ARMNativeAppScan](./ARMNativeAppScan)
A PowerShell-based tool for analyzing Windows executables and their dependencies to determine the percentage of native ARM64 code versus emulated code. This static analysis tool helps developers understand how "native" their application truly is.

### [ARMNativeProfiling](./ARMNativeProfiling)
Documentation and guidance on how to profile ARM applications to identify performance-critical code paths and determine their native code composition. This helps developers focus optimization efforts on the most impactful areas of their application.

### [ARMClientAppCompilation](./ARMClientAppCompilation)
Documentation on compiling and optimizing client applications for ARM architectures. 

### [MacCrossPlatformAppAnalysis](./MacCrossPlatformAppAnalysis)
Resources for analyzing cross-platform applications on macOS. 

## Getting Started

Each directory contains its own README with detailed information about the tools and documentation available. Click the links above to explore each section.

## Prerequisites

- Windows 11 on ARM64 device
- Visual Studio with developer command prompt tools for binary analysis
- App for Windows with ideally that app having an ARM native version

## Contributing

Contributions are welcome.

## License

MIT