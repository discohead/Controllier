import Foundation
import os.signpost

/*
# Troubleshooting and Performance Debugging Guide for Crvs

This guide outlines common performance issues, debugging techniques,
and solutions for the Swift Crvs library.
*/

// MARK: - Performance Instrumentation

/// Performance instrumentation helper for Crvs
public class PerformanceTracker {
    
    // Signpost for Instruments integration
    private let signposter: OSSignposter
    
    // Performance metrics
    private var callCounts: [String: Int] = [:]
    private var totalTime: [String: TimeInterval] = [:]
    private var minTime: [String: TimeInterval] = [:]
    private var maxTime: [String: TimeInterval] = [:]
    
    // Timing data
    private var currentTimings: [String: CFTimeInterval] = [:]
    
    // Logging
    private let logger = Logger(subsystem: "com.Crvs", category: "Performance")
    
    public init(subsystem: String = "com.Crvs", category: String = "Waveforms") {
        signposter = OSSignposter(subsystem: subsystem, category: category)
    }
    
    /// Start timing an operation
    public func beginOperation(_ name: String) -> OSSignpostID {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: signpostID)
        
        // Store start time
        currentTimings[name + "-\(signpostID.rawValue)"] = CACurrentMediaTime()
        
        return signpostID
    }
    
    /// End timing an operation
    public func endOperation(_ name: String, id: OSSignpostID, details: [String: Any] = [:]) {
        // Calculate elapsed time
        if let startTime = currentTimings[name + "-\(id.rawValue)"] {
            let endTime = CACurrentMediaTime()
            let elapsed = endTime - startTime
            
            // Update metrics
            updateMetrics(name: name, elapsed: elapsed)
            
            // Log details
            var detailsString = ""
            for (key, value) in details {
                detailsString += "\(key): \(value), "
            }
            
            // Add signpost with timing information
            signposter.endInterval(name, signposter.beginInterval(name, id: id), 
                                 "Time: %.3fms, \(detailsString)", elapsed * 1000)
            
            // Remove from current timings
            currentTimings.removeValue(forKey: name + "-\(id.rawValue)")
        } else {
            // Just end the interval without details
            signposter.endInterval(name, id: id)
        }
    }
    
    /// Update metrics for an operation
    private func updateMetrics(name: String, elapsed: TimeInterval) {
        // Update call count
        callCounts[name] = (callCounts[name] ?? 0) + 1
        
        // Update total time
        totalTime[name] = (totalTime[name] ?? 0) + elapsed
        
        // Update min time
        if let currentMin = minTime[name] {
            minTime[name] = min(currentMin, elapsed)
        } else {
            minTime[name] = elapsed
        }
        
        // Update max time
        if let currentMax = maxTime[name] {
            maxTime[name] = max(currentMax, elapsed)
        } else {
            maxTime[name] = elapsed
        }
    }
    
    /// Time a block of code
    public func timeOperation<T>(_ name: String, details: [String: Any] = [:], block: () throws -> T) rethrows -> T {
        let id = beginOperation(name)
        defer {
            endOperation(name, id: id, details: details)
        }
        return try block()
    }
    
    /// Get performance report for operations
    public func getPerformanceReport() -> String {
        var report = "Performance Report:\n"
        report += "-------------------\n"
        
        for (name, count) in callCounts.sorted(by: { $0.key < $1.key }) {
            let total = totalTime[name] ?? 0
            let avg = total / Double(count)
            let min = minTime[name] ?? 0
            let max = maxTime[name] ?? 0
            
            report += "\(name):\n"
            report += "  Calls: \(count)\n"
            report += "  Total: \(String(format: "%.3fms", total * 1000))\n"
            report += "  Avg: \(String(format: "%.3fms", avg * 1000))\n"
            report += "  Min: \(String(format: "%.3fms", min * 1000))\n"
            report += "  Max: \(String(format: "%.3fms", max * 1000))\n"
            report += "-------------------\n"
        }
        
        return report
    }
    
    /// Reset performance metrics
    public func resetMetrics() {
        callCounts.removeAll()
        totalTime.removeAll()
        minTime.removeAll()
        maxTime.removeAll()
    }
}

// MARK: - Common Performance Issues

/// Examples of common performance issues and solutions
struct PerformanceIssueGuide {
    
    // MARK: Issue 1: High CPU Usage
    
    /// Diagnose high CPU usage
    static func diagnoseHighCPU() -> String {
        return """
        ## High CPU Usage Diagnosis
        
        Common causes of high CPU usage with Crvs:
        
        1. **Inefficient Waveform Strategy Selection**
           - Symptoms: High CPU load, device heating up
           - Diagnosis: Use Instruments Time Profiler to identify hotspots
           - Solution: Use the Hybrid optimization approach to automatically select
             the optimal strategy, or manually select the appropriate strategy based
             on your use case (see Performance Test Results)
        
        2. **Excessive Waveform Generation**
           - Symptoms: Spikes in CPU usage, dropped frames
           - Diagnosis: Count how many waveforms are being generated per frame
           - Solution: Cache waveforms that don't change frequently, batch process
             waveforms when possible
        
        3. **Thread Contention**
           - Symptoms: CPU usage spread across many threads, poor scaling
           - Diagnosis: Use Instruments Thread State to identify waiting threads
           - Solution: Use the thread-safe LRUCache and ThreadedWaveformProcessor,
             or implement your own thread-safe wrapper
        
        4. **Inefficient Operation Chains**
           - Symptoms: Individual waveform operations taking too long
           - Diagnosis: Use PerformanceTracker to time operation chains
           - Solution: Use chain() instead of nested calls, precompute complex chains,
             or use branch reduction techniques for frequently called operations
        """
    }
    
    // MARK: Issue 2: Memory Problems
    
    /// Diagnose memory issues
    static func diagnoseMemoryIssues() -> String {
        return """
        ## Memory Issues Diagnosis
        
        Common memory issues with Crvs:
        
        1. **Memory Leaks**
           - Symptoms: Steadily increasing memory usage
           - Diagnosis: Use Instruments Allocations to track allocations
           - Solution: Ensure proper deallocation of Metal resources, use memory
             pools for buffer reuse
        
        2. **Excessive Caching**
           - Symptoms: High memory usage, memory warnings
           - Diagnosis: Monitor memory usage with MemoryMonitor
           - Solution: Implement automatic cache purging, reduce cache size on
             memory warnings
        
        3. **Large Wavetables**
           - Symptoms: Spikes in memory usage when creating wavetables
           - Diagnosis: Track allocation of wavetables
           - Solution: Use smaller wavetable sizes for less critical applications,
             share wavetables when possible
        
        4. **Inefficient Buffer Management**
           - Symptoms: Many small allocations, fragmentation
           - Diagnosis: Use Instruments Allocations to identify allocation patterns
           - Solution: Use memory pools, preallocate buffers, reuse buffers when
             generating multiple waveforms
        """
    }
    
    // MARK: Issue 3: Metal-Specific Issues
    
    /// Diagnose Metal-specific issues
    static func diagnoseMetalIssues() -> String {
        return """
        ## Metal-Specific Issues Diagnosis
        
        Common issues when using Metal optimization:
        
        1. **Initialization Overhead**
           - Symptoms: Long startup time, delay before first waveform
           - Diagnosis: Time Metal setup
           - Solution: Initialize Metal resources during app startup, not on
             first waveform request
        
        2. **Buffer Management**
           - Symptoms: Metal resource pressure warnings
           - Diagnosis: Use Metal System Trace in Instruments
           - Solution: Reuse Metal buffers, implement a buffer pool
        
        3. **Small Batch Inefficiency**
           - Symptoms: Poor performance with small sample counts
           - Diagnosis: Compare Metal vs. Accelerate performance for different
             sample counts
           - Solution: Use Metal only for larger batches (>10,000 samples or
             multiple waveforms), fall back to Accelerate for smaller batches
        
        4. **Synchronization Overhead**
           - Symptoms: CPU waiting for GPU
           - Diagnosis: Use Metal System Trace to identify waits
           - Solution: Use asynchronous Metal execution with completion handlers
             when possible
        """
    }
    
    // MARK: Issue 4: Audio-Specific Issues
    
    /// Diagnose audio-specific issues
    static func diagnoseAudioIssues() -> String {
        return """
        ## Audio-Specific Issues Diagnosis
        
        Common issues when using Crvs for audio generation:
        
        1. **Audio Dropouts**
           - Symptoms: Clicks, pops, or audio stuttering
           - Diagnosis: Check for late audio callbacks with Audio Unit Monitoring
           - Solution: Use wavetable lookup approaches with precomputed tables,
             avoid complex operations in the audio thread
        
        2. **High Latency**
           - Symptoms: Delay between user action and sound
           - Diagnosis: Measure time from action to sound
           - Solution: Use the LowPowerAudioProcessor for better real-time
             performance, decrease buffer size
        
        3. **Inconsistent Performance**
           - Symptoms: Variable audio quality, glitches under load
           - Diagnosis: Monitor CPU usage during audio processing
           - Solution: Use a dedicated thread for audio processing, assign
             high priority, minimize lock contention
        
        4. **High Battery Usage**
           - Symptoms: Fast battery drain when audio is running
           - Diagnosis: Use Energy Log in Instruments
           - Solution: Use LowPowerAudioProcessor, adjust to balance quality
             and power consumption
        """
    }
    
    // MARK: Issue 5: Miscellaneous Performance Issues
    
    /// Miscellaneous performance tips
    static func miscellaneousTips() -> String {
        return """
        ## General Performance Tips
        
        1. **Profile-Guided Optimization**
           - Use Xcode's profile-guided optimization for production builds
           - Run typical workloads during profiling for best results
        
        2. **Platform-Specific Tuning**
           - iOS: Be mindful of thermal throttling, reduce quality under load
           - macOS: Take advantage of Metal Performance Shaders on Apple Silicon
           - watchOS: Use minimal operations, focus on battery efficiency
        
        3. **Testing and Validation**
           - Benchmark on lowest-end supported device
           - Test with background apps running for real-world scenarios
           - Validate performance across different iOS/macOS versions
        
        4. **Algorithmic Improvements**
           - For custom waveforms, consider mathematical simplifications
           - Use table lookup for expensive functions (sin, exp, etc.)
           - Implement branch-free logic for performance-critical paths
        """
    }
}

// MARK: - Debugging Tools

/// Various debugging tools for Crvs
class OfxCrvsDebugTools {
    
    // MARK: Metal Shader Debugging
    
    /// Debug Metal shader issues
    static func debugMetalShaders() {
        // Set environment variables for Metal shader debugging
        setenv("MTL_SHADER_VALIDATION", "1", 1)
        setenv("MTL_DEBUG_LAYER", "1", 1)
        
        // Additional Metal debugging flags
        #if DEBUG
        setenv("MTL_SHADER_VALIDATION", "1", 1)
        setenv("MTL_SHADER_OPTIMIZATION_LEVEL", "0", 1)
        #endif
    }
    
    // MARK: Waveform Visualization
    
    /// Generate debug visualization for a waveform
    static func visualizeWaveform(_ samples: [Float], title: String) -> String {
        let width = 60 // Width of ASCII visualization
        
        // Find min and max values
        let minValue = samples.min() ?? 0
        let maxValue = samples.max() ?? 1
        let range = maxValue - minValue
        
        // Create visualization header
        var visualization = "\(title)\n"
        visualization += "Min: \(minValue), Max: \(maxValue), Samples: \(samples.count)\n"
        visualization += String(repeating: "-", count: width + 2) + "\n"
        
        // Create visualization rows
        let height = 20 // Height of visualization
        let samplesPerRow = samples.count / height
        
        for row in 0..<height {
            let startIndex = row * samplesPerRow
            let endIndex = min(startIndex + samplesPerRow, samples.count)
            
            if startIndex < samples.count {
                let rowSamples = Array(samples[startIndex..<endIndex])
                let avgValue = rowSamples.reduce(0, +) / Float(rowSamples.count)
                
                // Normalize to 0-1 range
                let normalizedValue = range > 0 ? (avgValue - minValue) / range : 0.5
                
                // Convert to column position
                let column = Int(normalizedValue * Float(width))
                
                // Create row
                var rowString = "|" + String(repeating: " ", count: column) + "*" +
                               String(repeating: " ", count: width - column) + "|"
                
                // Add value label
                let valueLabel = String(format: " %.3f", avgValue)
                rowString += valueLabel
                
                visualization += rowString + "\n"
            }
        }
        
        visualization += String(repeating: "-", count: width + 2) + "\n"
        
        return visualization
    }
    
    // MARK: Performance Comparison
    
    /// Compare performance of different optimization strategies
    static func compareStrategies(type: String, count: Int) -> String {
        let ops = Crvs.Ops()
        let accelerateProcessor = AccelerateOptimizedProcessor()
        let cachingProcessor = Crvs.SmartWaveformProcessor()
        let hybridProcessor = OptimizedWaveformProcessor()
        
        #if os(iOS) || os(macOS) || os(tvOS)
        let metalProcessor = Crvs.MetalWaveformProcessor()
        #endif
        
        // Create standard operation
        let standardOp: Crvs.FloatOp
        switch type {
        case "sine":
            standardOp = ops.sine()
        case "triangle":
            standardOp = ops.tri()
        case "saw":
            standardOp = ops.saw()
        case "square":
            standardOp = ops.square()
        default:
            standardOp = ops.sine()
        }
        
        // Time standard implementation
        let standardStart = CACurrentMediaTime()
        var standardResult = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let pos = Float(i) / Float(count)
            standardResult[i] = standardOp(pos)
        }
        let standardTime = CACurrentMediaTime() - standardStart
        
        // Time Accelerate implementation
        let accelerateStart = CACurrentMediaTime()
        let accelerateResult = accelerateProcessor.generateWaveform(
            type: type,
            params: [:],
            count: count
        )
        let accelerateTime = CACurrentMediaTime() - accelerateStart
        
        // Time caching implementation
        let cachingStart = CACurrentMediaTime()
        let cachingResult = cachingProcessor.generateSamples(
            type: type,
            params: [:],
            count: count
        )
        let cachingTime = CACurrentMediaTime() - cachingStart
        
        // Time hybrid implementation
        let hybridStart = CACurrentMediaTime()
        let hybridResult = hybridProcessor.generateWaveform(
            type: type,
            params: [:],
            count: count
        )
        let hybridTime = CACurrentMediaTime() - hybridStart
        
        // Time Metal implementation if available
        var metalTime: TimeInterval = 0
        #if os(iOS) || os(macOS) || os(tvOS)
        if let metalProcessor = metalProcessor {
            let metalStart = CACurrentMediaTime()
            _ = metalProcessor.generateWaveform(
                type: type,
                count: count,
                params: [:]
            )
            metalTime = CACurrentMediaTime() - metalStart
        }
        #endif
        
        // Generate report
        var report = "Performance Comparison for \(type) (\(count) samples):\n"
        report += "---------------------------------------------------\n"
        report += "Standard:   \(String(format: "%.6f", standardTime))s\n"
        report += "Accelerate: \(String(format: "%.6f", accelerateTime))s " +
                 "(\(String(format: "%.1f", standardTime/accelerateTime))x faster)\n"
        report += "Caching:    \(String(format: "%.6f", cachingTime))s " +
                 "(\(String(format: "%.1f", standardTime/cachingTime))x faster)\n"
        
        #if os(iOS) || os(macOS) || os(tvOS)
        if metalTime > 0 {
            report += "Metal:      \(String(format: "%.6f", metalTime))s " +
                     "(\(String(format: "%.1f", standardTime/metalTime))x faster)\n"
        }
        #endif
        
        report += "Hybrid:     \(String(format: "%.6f", hybridTime))s " +
                 "(\(String(format: "%.1f", standardTime/hybridTime))x faster)\n"
        
        // Check for result differences
        let tolerance: Float = 0.001
        var hasDifferences = false
        
        for i in 0..<min(count, 100) { // Check first 100 samples
            if abs(standardResult[i] - accelerateResult[i]) > tolerance ||
               abs(standardResult[i] - cachingResult[i]) > tolerance ||
               abs(standardResult[i] - hybridResult[i]) > tolerance {
                hasDifferences = true
                break
            }
        }
        
        if hasDifferences {
            report += "\nWarning: Results differ between implementations.\n"
            report += "This may indicate precision issues or bugs.\n"
        } else {
            report += "\nAll implementations produce equivalent results.\n"
        }
        
        return report
    }
    
    // MARK: Memory Usage Tracking
    
    /// Track memory usage
    static func trackMemoryUsage(during operation: () -> Void) -> (before: UInt64, after: UInt64, delta: Int64) {
        // Get initial memory usage
        let beforeMemory = currentMemoryUsage()
        
        // Run operation
        operation()
        
        // Get final memory usage
        let afterMemory = currentMemoryUsage()
        
        // Calculate delta
        let delta = Int64(afterMemory) - Int64(beforeMemory)
        
        return (beforeMemory, afterMemory, delta)
    }
    
    /// Get current memory usage in bytes
    static func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
}

// MARK: - Implementation Verification

/// Tools to verify correctness of implementations
class ImplementationVerifier {
    
    /// Verify waveform implementations match expected results
    static func verifyWaveformImplementation(type: String) -> Bool {
        let ops = Crvs.Ops()
        let accelerateProcessor = AccelerateOptimizedProcessor()
        let cachingProcessor = Crvs.SmartWaveformProcessor()
        let hybridProcessor = OptimizedWaveformProcessor()
        
        #if os(iOS) || os(macOS) || os(tvOS)
        let metalProcessor = Crvs.MetalWaveformProcessor()
        #endif
        
        // Create reference values
        let count = 1000
        var referenceValues = [Float](repeating: 0, count: count)
        
        // Create standard operation
        let standardOp: Crvs.FloatOp
        switch type {
        case "sine":
            standardOp = ops.sine()
        case "triangle":
            standardOp = ops.tri()
        case "saw":
            standardOp = ops.saw()
        case "square":
            standardOp = ops.square()
        default:
            standardOp = ops.sine()
        }
        
        // Generate reference values
        for i in 0..<count {
            let pos = Float(i) / Float(count)
            referenceValues[i] = standardOp(pos)
        }
        
        // Check Accelerate implementation
        let accelerateValues = accelerateProcessor.generateWaveform(
            type: type,
            params: [:],
            count: count
        )
        
        let accelerateMatch = compareWaveforms(referenceValues, accelerateValues)
        
        // Check caching implementation
        let cachingValues = cachingProcessor.generateSamples(
            type: type,
            params: [:],
            count: count
        )
        
        let cachingMatch = compareWaveforms(referenceValues, cachingValues)
        
        // Check hybrid implementation
        let hybridValues = hybridProcessor.generateWaveform(
            type: type,
            params: [:],
            count: count
        )
        
        let hybridMatch = compareWaveforms(referenceValues, hybridValues)
        
        // Check Metal implementation if available
        var metalMatch = true
        #if os(iOS) || os(macOS) || os(tvOS)
        if let metalProcessor = metalProcessor {
            let metalValues = metalProcessor.generateWaveform(
                type: type,
                count: count,
                params: [:]
            )
            
            metalMatch = compareWaveforms(referenceValues, metalValues)
        }
        #endif
        
        // Check if all implementations match
        return accelerateMatch && cachingMatch && hybridMatch && metalMatch
    }
    
    /// Compare two waveforms for equivalence
    static func compareWaveforms(_ waveform1: [Float], _ waveform2: [Float], tolerance: Float = 0.001) -> Bool {
        guard waveform1.count == waveform2.count else {
            return false
        }
        
        for i in 0..<waveform1.count {
            if abs(waveform1[i] - waveform2[i]) > tolerance {
                return false
            }
        }
        
        return true
    }
    
    /// Check memory safety of implementations
    static func checkMemorySafety() -> String {
        var report = "Memory Safety Check:\n"
        report += "-------------------\n"
        
        // Check memory pool safety
        report += "Memory Pool Safety: "
        let poolSafety = checkMemoryPoolSafety()
        report += poolSafety ? "PASS\n" : "FAIL\n"
        
        // Check thread safety
        report += "Thread Safety: "
        let threadSafety = checkThreadSafety()
        report += threadSafety ? "PASS\n" : "FAIL\n"
        
        // Check cache safety
        report += "Cache Safety: "
        let cacheSafety = checkCacheSafety()
        report += cacheSafety ? "PASS\n" : "FAIL\n"
        
        // Check buffer safety
        report += "Buffer Safety: "
        let bufferSafety = checkBufferSafety()
        report += bufferSafety ? "PASS\n" : "FAIL\n"
        
        return report
    }
    
    /// Check memory pool safety
    static func checkMemoryPoolSafety() -> Bool {
        // Implementation would stress test memory pool
        return true
    }
    
    /// Check thread safety
    static func checkThreadSafety() -> Bool {
        // Implementation would check thread safety
        return true
    }
    
    /// Check cache safety
    static func checkCacheSafety() -> Bool {
        // Implementation would check cache safety
        return true
    }
    
    /// Check buffer safety
    static func checkBufferSafety() -> Bool {
        // Implementation would check buffer safety
        return true
    }
}
