import Foundation
import Accelerate
import Metal

/// High-performance waveform processor combining all optimization strategies
public class OptimizedWaveformProcessor {
    // Core operation instances
    private let ops = Crvs.Ops()
    private let tables = Crvs.WaveformTables(tableSize: 8192)
    private let cache = Crvs.LRUCache<String, [Float]>(capacity: 100)
    private let metalProcessor: Crvs.MetalWaveformProcessor?
    
    // Performance monitoring
    private var totalGenerationTime: TimeInterval = 0
    private var callCount: Int = 0
    
    public init() {
        // Try to initialize Metal processor, but continue without it if unavailable
        metalProcessor = Crvs.MetalWaveformProcessor()
    }
    
    /// Generate waveform samples using the optimal strategy for the given parameters
    public func generateWaveform(type: String, 
                               params: [String: Float], 
                               count: Int,
                               forceStrategy: OptimizationStrategy? = nil) -> [Float] {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            totalGenerationTime += endTime - startTime
            callCount += 1
        }
        
        // Determine optimal strategy if not forced
        let strategy = forceStrategy ?? determineOptimalStrategy(type: type, params: params, count: count)
        
        // Generate samples using the selected strategy
        let samples: [Float]
        
        switch strategy {
        case .cache:
            samples = generateWithCaching(type: type, params: params, count: count)
        case .accelerate:
            samples = generateWithAccelerate(type: type, params: params, count: count)
        case .metal:
            if let metalResult = generateWithMetal(type: type, params: params, count: count) {
                samples = metalResult
            } else {
                // Fall back to Accelerate if Metal fails
                samples = generateWithAccelerate(type: type, params: params, count: count)
            }
        }
        
        // Apply any global processing with Accelerate
        return applyGlobalProcessing(samples: samples, params: params)
    }
    
    /// Determine the best strategy based on waveform type, parameters, and sample count
    private func determineOptimalStrategy(type: String, params: [String: Float], count: Int) -> OptimizationStrategy {
        // Cache lookup key
        let cacheKey = createCacheKey(type: type, params: params, count: count)
        
        // Check if it's in cache first
        if cache.get(cacheKey) != nil {
            return .cache
        }
        
        // For large sample counts, prefer Metal when available
        if count > 10000 && metalProcessor != nil {
            return .metal
        }
        
        // For medium counts, use Accelerate
        if count > 1000 {
            return .accelerate
        }
        
        // For small counts or complex parameters, use caching
        return .cache
    }
    
    // MARK: - Strategy Implementations
    
    /// Generate waveform using caching strategy
    private func generateWithCaching(type: String, params: [String: Float], count: Int) -> [Float] {
        let cacheKey = createCacheKey(type: type, params: params, count: count)
        
        // Check cache first
        if let cachedResult = cache.get(cacheKey) {
            return cachedResult
        }
        
        var samples = [Float](repeating: 0, count: count)
        
        // Use lookup tables for basic waveforms
        switch type {
        case "sine":
            let frequency = params["frequency"] ?? 1.0
            let phase = params["phase"] ?? 0.0
            
            for i in 0..<count {
                let pos = Float(i) / Float(count)
                let adjustedPhase = (pos * frequency) + phase
                samples[i] = tables.lookupSine(adjustedPhase)
            }
            
        case "triangle":
            let frequency = params["frequency"] ?? 1.0
            let phase = params["phase"] ?? 0.0
            let symmetry = params["symmetry"] ?? 0.5
            
            // For non-standard symmetry, generate custom
            if abs(symmetry - 0.5) > 0.001 {
                let triangleOp = ops.tri(symmetry)
                
                for i in 0..<count {
                    let pos = Float(i) / Float(count)
                    let adjustedPos = fmod((pos * frequency) + phase, 1.0)
                    samples[i] = triangleOp(adjustedPos)
                }
            } else {
                // Use standard lookup for default symmetry
                for i in 0..<count {
                    let pos = Float(i) / Float(count)
                    let adjustedPhase = (pos * frequency) + phase
                    samples[i] = tables.lookupTriangle(adjustedPhase)
                }
            }
            
        default:
            // For other waveforms, generate using core ops
            let operation = createOperation(type: type, params: params)
            
            for i in 0..<count {
                let pos = Float(i) / Float(count)
                samples[i] = operation(pos)
            }
        }
        
        // Cache the result
        cache.set(cacheKey, samples)
        
        return samples
    }
    
    /// Generate waveform using Accelerate optimizations
    private func generateWithAccelerate(type: String, params: [String: Float], count: Int) -> [Float] {
        // Create position array (0 to 1)
        var positions = [Float](repeating: 0, count: count)
        var start: Float = 0.0
        var step = 1.0 / Float(count - 1)
        vDSP_vramp(&start, &step, &positions, 1, vDSP_Length(count))
        
        // Apply frequency and phase adjustment
        let frequency = params["frequency"] ?? 1.0
        let phase = params["phase"] ?? 0.0
        
        if frequency != 1.0 {
            var frequencyVal = frequency
            vDSP_vsmul(positions, 1, &frequencyVal, &positions, 1, vDSP_Length(count))
        }
        
        if phase != 0.0 {
            var phaseVal = phase
            vDSP_vsadd(positions, 1, &phaseVal, &positions, 1, vDSP_Length(count))
        }
        
        // Handle different waveform types with optimized implementations
        var result = [Float](repeating: 0, count: count)
        
        switch type {
        case "sine":
            // Scale positions to 0...2π
            var scaleFactor = 2.0 * Float.pi
            vDSP_vsmul(positions, 1, &scaleFactor, &positions, 1, vDSP_Length(count))
            
            // Apply sine function using vForce
            vForce.sin(positions, result: &result)
            
            // Map from -1...1 to 0...1
            var half: Float = 0.5
            vDSP_vsmsa(result, 1, &half, &half, &result, 1, vDSP_Length(count))
            
        case "triangle":
            let symmetry = params["symmetry"] ?? 0.5
            
            // For standard triangle, use fmod to wrap positions
            for i in 0..<count {
                let pos = fmod(positions[i], 1.0)
                result[i] = pos < symmetry ? 
                    (pos / symmetry) : 
                    (1.0 - ((pos - symmetry) / (1.0 - symmetry)))
            }
            
        case "saw":
            // Ensure positions are in 0...1 range
            for i in 0..<count {
                positions[i] = fmod(positions[i], 1.0)
            }
            
            // Invert positions: 1 - pos
            // Replace vDSP_vrsub with vDSP_vsmsa to compute: result = 1 - positions
            var one: Float = 1.0
            var negOne: Float = -1.0
            vDSP_vsmsa(positions, 1, &negOne, &one, &result, 1, vDSP_Length(count))

            
        case "square":
            let width = params["width"] ?? 0.5
            
            // Apply threshold test
            for i in 0..<count {
                result[i] = fmod(positions[i], 1.0) < width ? 0.0 : 1.0
            }
            
        default:
            // For other waveforms, use standard approach
            let operation = createOperation(type: type, params: params)
            
            for i in 0..<count {
                result[i] = operation(fmod(positions[i], 1.0))
            }
        }
        
        return result
    }
    
    /// Generate waveform using Metal GPU acceleration
    private func generateWithMetal(type: String, params: [String: Float], count: Int) -> [Float]? {
        guard let metalProcessor = metalProcessor else {
            return nil
        }
        
        // Try to generate using Metal
        return metalProcessor.generateWaveform(type: type, count: count, params: params)
    }
    
    // MARK: - Helper Methods
    
    /// Create the appropriate operation based on waveform type and parameters
    private func createOperation(type: String, params: [String: Float]) -> Crvs.FloatOp {
        switch type {
        case "sine":
            let feedback = params["feedback"] ?? 0.0
            return ops.sine(feedback)
            
        case "triangle":
            let symmetry = params["symmetry"] ?? 0.5
            return ops.tri(symmetry)
            
        case "saw":
            return ops.saw()
            
        case "square":
            let width = params["width"] ?? 0.5
            return ops.pulse(width)
            
        case "easeIn":
            let exponent = params["exponent"] ?? 2.0
            return ops.easeIn(exponent)
            
        case "easeOut":
            let exponent = params["exponent"] ?? 2.0
            return ops.easeOut(exponent)
            
        case "easeInOut":
            let exponent = params["exponent"] ?? 2.0
            return ops.easeInOut(exponent)
            
        case "morph":
            guard let morphParam = params["morph"] else {
                return ops.sine()
            }
            
            return ops.morph(ops.sine(), ops.tri(), ops.c(morphParam))
            
        default:
            return ops.sine()
        }
    }
    
    /// Apply global processing to samples (gain, offset, etc.)
    private func applyGlobalProcessing(samples: [Float], params: [String: Float]) -> [Float] {
        var result = samples
        let count = vDSP_Length(samples.count)
        
        // Apply gain if specified
        if let gain = params["gain"], gain != 1.0 {
            var gainVal = gain
            vDSP_vsmul(result, 1, &gainVal, &result, 1, count)
        }
        
        // Apply offset if specified
        if let offset = params["offset"], offset != 0.0 {
            var offsetVal = offset
            vDSP_vsadd(result, 1, &offsetVal, &result, 1, count)
        }
        
        // Apply clipping if specified
        if let clipMin = params["clipMin"], let clipMax = params["clipMax"] {
            for i in 0..<samples.count {
                result[i] = min(max(result[i], clipMin), clipMax)
            }
        }
        
        return result
    }
    
    /// Create a cache key for the given parameters
    private func createCacheKey(type: String, params: [String: Float], count: Int) -> String {
        var key = "\(type)_\(count)"
        
        for (paramName, paramValue) in params.sorted(by: { $0.key < $1.key }) {
            key += "_\(paramName)_\(String(format: "%.4f", paramValue))"
        }
        
        return key
    }
    
    // MARK: - Performance Reporting
    
    /// Get performance statistics
//    public func getPerformanceStats() -> (totalTime: TimeInterval, averageTime: TimeInterval, callCount: Int) {
//        let avgTime = callCount > 0 ? totalTime / TimeInterval(callCount) : 0
//        return (totalTime: totalGenerationTime, averageTime: avgTime, callCount: callCount)
//    }
    
    /// Reset performance statistics
//    public func resetPerformanceStats() {
//        totalGenerationTime = 0
//        callCount = 0
//    }
    
    // MARK: - Enum Types
    
    /// Optimization strategies
    public enum OptimizationStrategy {
        case cache     // Use lookup tables and caching
        case accelerate // Use Accelerate framework
        case metal     // Use Metal GPU acceleration
    }
}
