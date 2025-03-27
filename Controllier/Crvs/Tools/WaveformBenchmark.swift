import Foundation
import QuartzCore

/// Performance benchmarking framework for Crvs
public class WaveformBenchmark {
    // Reference to standard implementations
    private let ops = Crvs.Ops()
    
    // References to optimized implementations
    private let optimizedProcessor = OptimizedWaveformProcessor()
    private let accelerateOptimizer = Crvs.Ops()
    private let cachingOptimizer = Crvs.SmartWaveformProcessor()
    private let metalProcessor = Crvs.MetalWaveformProcessor()
    
    // Results storage
    private var results: [BenchmarkResult] = []
    
    /// Run all benchmarks
    public func runFullBenchmark() -> [BenchmarkResult] {
        results = []
        
        // Test parameters
        let sampleCounts = [100, 1_000, 10_000, 100_000, 1_000_000]
        let waveformTypes = ["sine", "triangle", "saw", "square", "easeInOut"]
        
        print("Starting benchmarks...")
        
        // Run comparison for different sample counts
        for count in sampleCounts {
            for type in waveformTypes {
                benchmarkWaveformGeneration(type: type, count: count)
            }
        }
        
        // Run specialized benchmarks
        benchmarkComplexOperationChains()
        benchmarkParameterModulation()
        benchmarkMultipleWaveforms()
        
        printSummary()
        
        return results
    }
    
    /// Benchmark a specific waveform generation across implementations
    private func benchmarkWaveformGeneration(type: String, count: Int) {
        print("Benchmarking \(type) waveform with \(count) samples")
        
        // Standard implementation (baseline)
        let standardOp = createWaveform(type: type)
        let standardTime = measureExecutionTime {
            _ = generateSamples(op: standardOp, count: count)
        }
        
        // Accelerate implementation
        let accelerateTime = measureExecutionTime {
            _ = optimizedProcessor.generateWaveform(
                type: type,
                params: [:],
                count: count,
                forceStrategy: .accelerate
            )
        }
        
        // Caching implementation
        let cachingTime = measureExecutionTime {
            _ = cachingOptimizer.generateSamples(
                type: type,
                params: [:],
                count: count
            )
        }
        
        // Metal implementation (if available)
        var metalTime: TimeInterval = 0
        if let metalProcessor = metalProcessor {
            metalTime = measureExecutionTime {
                _ = metalProcessor.generateWaveform(
                    type: type,
                    count: count,
                    params: [:]
                )
            }
        }
        
        // Hybrid implementation
        let hybridTime = measureExecutionTime {
            _ = optimizedProcessor.generateWaveform(
                type: type,
                params: [:],
                count: count
            )
        }
        
        // Save results
        let result = BenchmarkResult(
            testName: "\(type)_\(count)",
            waveformType: type,
            sampleCount: count,
            standardTime: standardTime,
            accelerateTime: accelerateTime,
            cachingTime: cachingTime,
            metalTime: metalTime,
            hybridTime: hybridTime
        )
        
        results.append(result)
        
        // Print summary
        printResult(result)
    }
    
    /// Benchmark complex operation chains
    private func benchmarkComplexOperationChains() {
        let count = 10_000
        
        print("Benchmarking complex operation chains with \(count) samples")
        
        // Create a complex operation chain
        let standardOps: [Crvs.FloatOp] = [
            ops.sine(),
            ops.easeIn(2.5),
            ops.phase(ops.c(0.25), ops.zero()),
            ops.bias(ops.c(0.1), ops.zero()),
        ]
        let standardChain = ops.chain(standardOps)
        
        // Standard implementation
        let standardTime = measureExecutionTime {
            _ = generateSamples(op: standardChain, count: count)
        }
        
        // Precomputed implementation
        let precomputedTime = measureExecutionTime {
            let precomputed = ops.precomputeChain(standardOps)
            _ = generateSamples(op: precomputed, count: count)
        }
        
        // Save results
        let result = BenchmarkResult(
            testName: "complex_chain_\(count)",
            waveformType: "complex_chain",
            sampleCount: count,
            standardTime: standardTime,
            accelerateTime: 0,
            cachingTime: precomputedTime,
            metalTime: 0,
            hybridTime: 0
        )
        
        results.append(result)
        printResult(result)
    }
    
    /// Benchmark parameter modulation
    private func benchmarkParameterModulation() {
        let count = 10_000
        let iterations = 100
        
        print("Benchmarking parameter modulation with \(count) samples × \(iterations) iterations")
        
        // Standard implementation
        let standardTime = measureExecutionTime {
            for i in 0..<iterations {
                let phase = Float(i) / Float(iterations)
                let op = ops.phase(ops.sine(), phase)
                _ = generateSamples(op: op, count: count)
            }
        }
        
        // Caching implementation
        let cachingTime = measureExecutionTime {
            for i in 0..<iterations {
                let phase = Float(i) / Float(iterations)
                _ = cachingOptimizer.generateSamples(
                    type: "sine",
                    params: ["phase": phase],
                    count: count
                )
            }
        }
        
        // Metal implementation (if available)
        var metalTime: TimeInterval = 0
        if let metalProcessor = metalProcessor {
            metalTime = measureExecutionTime {
                for i in 0..<iterations {
                    let phase = Float(i) / Float(iterations)
                    _ = metalProcessor.generateWaveform(
                        type: "sine",
                        count: count,
                        params: ["phase": phase]
                    )
                }
            }
        }
        
        // Save results
        let result = BenchmarkResult(
            testName: "parameter_modulation",
            waveformType: "modulation",
            sampleCount: count * iterations,
            standardTime: standardTime,
            accelerateTime: 0,
            cachingTime: cachingTime,
            metalTime: metalTime,
            hybridTime: 0
        )
        
        results.append(result)
        printResult(result)
    }
    
    /// Benchmark multiple simultaneous waveforms
    private func benchmarkMultipleWaveforms() {
        let count = 10_000
        let waveformCounts = [10, 50, 100]
        
        for numWaveforms in waveformCounts {
            print("Benchmarking \(numWaveforms) simultaneous waveforms with \(count) samples each")
            
            // Prepare waveform types and parameters
            var types = [String]()
            var params = [[String: Float]]()
            
            for i in 0..<numWaveforms {
                let typeIndex = i % 4
                let type: String
                
                switch typeIndex {
                case 0: type = "sine"
                case 1: type = "triangle"
                case 2: type = "saw"
                case 3: type = "square"
                default: type = "sine"
                }
                
                types.append(type)
                params.append([
                    "frequency": 1.0 + Float(i % 10) * 0.1,
                    "phase": Float(i % 20) * 0.05
                ])
            }
            
            // Standard implementation
            let standardTime = measureExecutionTime {
                var allSamples = [[Float]]()
                for i in 0..<numWaveforms {
                    let op = createWaveform(type: types[i])
                    allSamples.append(generateSamples(op: op, count: count))
                }
            }
            
            // Metal batch implementation (if available)
            var metalTime: TimeInterval = 0
            if let metalProcessor = metalProcessor {
                metalTime = measureExecutionTime {
                    _ = metalProcessor.generateMultipleWaveforms(
                        types: types,
                        count: count,
                        params: params
                    )
                }
            }
            
            // Save results
            let result = BenchmarkResult(
                testName: "multiple_waveforms_\(numWaveforms)",
                waveformType: "multiple",
                sampleCount: count * numWaveforms,
                standardTime: standardTime,
                accelerateTime: 0,
                cachingTime: 0,
                metalTime: metalTime,
                hybridTime: 0
            )
            
            results.append(result)
            printResult(result)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a waveform operation based on type
    private func createWaveform(type: String) -> Crvs.FloatOp {
        switch type {
        case "sine": return ops.sine()
        case "triangle": return ops.tri()
        case "saw": return ops.saw()
        case "square": return ops.square()
        case "easeInOut": return ops.easeInOut()
        default: return ops.sine()
        }
    }
    
    /// Generate samples using the standard approach
    private func generateSamples(op: Crvs.FloatOp, count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let pos = Float(i) / Float(count)
            samples[i] = op(pos)
        }
        return samples
    }
    
    /// Measure execution time of a code block
    private func measureExecutionTime(_ block: () -> Void) -> TimeInterval {
        let start = CACurrentMediaTime()
        block()
        let end = CACurrentMediaTime()
        return end - start
    }
    
    /// Print a benchmark result
    private func printResult(_ result: BenchmarkResult) {
        print("  \(result.testName):")
        print("    Standard: \(String(format: "%.5f", result.standardTime))s")
        
        if result.accelerateTime > 0 {
            let speedup = result.standardTime / result.accelerateTime
            print("    Accelerate: \(String(format: "%.5f", result.accelerateTime))s (\(String(format: "%.1f", speedup))x)")
        }
        
        if result.cachingTime > 0 {
            let speedup = result.standardTime / result.cachingTime
            print("    Caching: \(String(format: "%.5f", result.cachingTime))s (\(String(format: "%.1f", speedup))x)")
        }
        
        if result.metalTime > 0 {
            let speedup = result.standardTime / result.metalTime
            print("    Metal: \(String(format: "%.5f", result.metalTime))s (\(String(format: "%.1f", speedup))x)")
        }
        
        if result.hybridTime > 0 {
            let speedup = result.standardTime / result.hybridTime
            print("    Hybrid: \(String(format: "%.5f", result.hybridTime))s (\(String(format: "%.1f", speedup))x)")
        }
        
        print("")
    }
    
    /// Print a summary of all benchmark results
    private func printSummary() {
        print("\nBENCHMARK SUMMARY")
        print("=================")
        
        // Calculate average speedups
        var avgAccelerateSpeedup = 0.0
        var avgCachingSpeedup = 0.0
        var avgMetalSpeedup = 0.0
        var avgHybridSpeedup = 0.0
        var accelerateCount = 0
        var cachingCount = 0
        var metalCount = 0
        var hybridCount = 0
        
        for result in results {
            if result.accelerateTime > 0 {
                avgAccelerateSpeedup += result.standardTime / result.accelerateTime
                accelerateCount += 1
            }
            
            if result.cachingTime > 0 {
                avgCachingSpeedup += result.standardTime / result.cachingTime
                cachingCount += 1
            }
            
            if result.metalTime > 0 {
                avgMetalSpeedup += result.standardTime / result.metalTime
                metalCount += 1
            }
            
            if result.hybridTime > 0 {
                avgHybridSpeedup += result.standardTime / result.hybridTime
                hybridCount += 1
            }
        }
        
        if accelerateCount > 0 {
            avgAccelerateSpeedup /= Double(accelerateCount)
            print("Average Accelerate speedup: \(String(format: "%.1f", avgAccelerateSpeedup))x")
        }
        
        if cachingCount > 0 {
            avgCachingSpeedup /= Double(cachingCount)
            print("Average Caching speedup: \(String(format: "%.1f", avgCachingSpeedup))x")
        }
        
        if metalCount > 0 {
            avgMetalSpeedup /= Double(metalCount)
            print("Average Metal speedup: \(String(format: "%.1f", avgMetalSpeedup))x")
        }
        
        if hybridCount > 0 {
            avgHybridSpeedup /= Double(hybridCount)
            print("Average Hybrid speedup: \(String(format: "%.1f", avgHybridSpeedup))x")
        }
        
        // Find best approach by sample count
        print("\nRecommended approach by sample count:")
        
        let sampleCounts = [100, 1_000, 10_000, 100_000, 1_000_000]
        for count in sampleCounts {
            let countResults = results.filter { $0.sampleCount == count && $0.waveformType != "complex_chain" && $0.waveformType != "modulation" && $0.waveformType != "multiple" }
            
            if countResults.isEmpty {
                continue
            }
            
            var bestApproach = "Standard"
            var bestSpeedup = 1.0
            
            let avgAccelerate = countResults.compactMap { $0.accelerateTime > 0 ? $0.standardTime / $0.accelerateTime : nil }.reduce(0.0, +) / Double(countResults.count)
            let avgCaching = countResults.compactMap { $0.cachingTime > 0 ? $0.standardTime / $0.cachingTime : nil }.reduce(0.0, +) / Double(countResults.count)
            let avgMetal = countResults.compactMap { $0.metalTime > 0 ? $0.standardTime / $0.metalTime : nil }.reduce(0.0, +) / Double(countResults.count)
            let avgHybrid = countResults.compactMap { $0.hybridTime > 0 ? $0.standardTime / $0.hybridTime : nil }.reduce(0.0, +) / Double(countResults.count)
            
            if avgAccelerate > bestSpeedup {
                bestApproach = "Accelerate"
                bestSpeedup = avgAccelerate
            }
            
            if avgCaching > bestSpeedup {
                bestApproach = "Caching"
                bestSpeedup = avgCaching
            }
            
            if avgMetal > bestSpeedup {
                bestApproach = "Metal"
                bestSpeedup = avgMetal
            }
            
            if avgHybrid > bestSpeedup {
                bestApproach = "Hybrid"
                bestSpeedup = avgHybrid
            }
            
            print("  \(count) samples: \(bestApproach) (\(String(format: "%.1f", bestSpeedup))x speedup)")
        }
    }
    
    // MARK: - Result Structure
    
    /// Structure to hold benchmark results
    public struct BenchmarkResult {
        let testName: String
        let waveformType: String
        let sampleCount: Int
        let standardTime: TimeInterval
        let accelerateTime: TimeInterval
        let cachingTime: TimeInterval
        let metalTime: TimeInterval
        let hybridTime: TimeInterval
    }
}
