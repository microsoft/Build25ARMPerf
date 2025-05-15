# ARM Client Application Compilation Guide

## Windows 11 ARM Requirements

Windows 11 on ARM requires ARMv8.2 architecture or newer processors. This requirement aligns with the [supported Qualcomm processors](https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-qualcomm-processors) for Windows 11, which include:

- Snapdragon 8cx Gen 2, Gen 3
- Snapdragon 8c
- Snapdragon 7c, 7c Gen 2, 7c+ Gen 3
- Microsoft SQ1, SQ2, SQ3

**Important Note**: Windows 10 on ARM support ends October 14, 2025. New applications should target Windows 11 and ARMv8.2+.

## Compiler Optimization

### Architecture Target

When compiling with Visual Studio MSVC for Windows on ARM, use the following compiler flags for optimal performance:

```cpp
/arch:armv8.2    // Target ARMv8.2 architecture
/feature:rcpc    // Enable RCPC (Release Consistent Processor Consistent) feature
```

The [`/arch:armv8.x`](https://learn.microsoft.com/en-us/cpp/build/reference/arch-arm64?view=msvc-170) compiler option allows you to specify the ARM architecture version, with support ranging from `armv8.0` through `armv9.4`. For Windows 11 applications, use `armv8.2`.

### Feature Optimizations

The [`/feature`](https://learn.microsoft.com/en-us/cpp/build/reference/feature-arm64?view=msvc-170) compiler option enables specific ARM architecture features:

| Feature | Description | Available From | Recommended |
|---------|-------------|----------------|-------------|
| `rcpc` | Load-Acquire RCpc instructions | ARMv8.2 | Yes |
| `rcpc2` | Load-Acquire RCpc instructions v2 | ARMv8.2 | Yes |

## Best Practices

1. **Target Architecture**
   - Always compile with minimum `/arch:armv8.2` for Windows 11
   - Enable appropriate features using the `/feature` flag
   - Consider higher architecture targets if targeting specific devices

2. **Compatibility**
   - Test on multiple ARM devices when possible
   - Verify performance on different Snapdragon processors
   - Consider the impact of architecture-specific optimizations

3. **Future Proofing**
   - Plan for Windows 10 ARM end-of-support in 2025
   - Consider supporting newer ARM features as they become available
   - Keep up with Visual Studio compiler updates for new optimizations

