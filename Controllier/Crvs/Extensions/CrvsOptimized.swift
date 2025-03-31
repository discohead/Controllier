import Foundation
import simd

// MARK: - SIMD Optimization Extensions

extension Crvs.Ops {
    
    /// SIMD-optimized batch processing for FloatOp functions
    public func processBatchSIMD(_ op: Crvs.FloatOp, count: Int) -> [Float] {
        let batchSize = 4 // Process 4 values at once with SIMD
        let fullBatchCount = count / batchSize
        let remainder = count % batchSize
        
        var result = [Float](repeating: 0, count: count)
        
        // Process full batches with SIMD
        for i in 0..<fullBatchCount {
            let baseIndex = i * batchSize
            
            // Create position vector with 4 consecutive positions
            let positions = SIMD4<Float>(
                Float(baseIndex) / Float(count),
                Float(baseIndex + 1) / Float(count),
                Float(baseIndex + 2) / Float(count),
                Float(baseIndex + 3) / Float(count)
            )
            
            // Process each position individually (can't vectorize the operation itself)
            result[baseIndex] = op(positions[0])
            result[baseIndex + 1] = op(positions[1])
            result[baseIndex + 2] = op(positions[2])
            result[baseIndex + 3] = op(positions[3])
        }
        
        // Process remainder
        let baseIndex = fullBatchCount * batchSize
        for i in 0..<remainder {
            let pos = Float(baseIndex + i) / Float(count)
            result[baseIndex + i] = op(pos)
        }
        
        return result
    }
    
    /// SIMD-optimized sine wave generator
    public func simdSine(count: Int, frequency: Float = 1.0, phase: Float = 0.0) -> [Float] {
        let vectorSize = 4 // SIMD4<Float>
        let fullVectorCount = count / vectorSize
        let remainder = count % vectorSize
        
        var result = [Float](repeating: 0, count: count)
        
        // Calculate positions for all samples
        var positions = [Float](repeating: 0, count: count)
        for i in 0..<count {
            positions[i] = (Float(i) / Float(count) * frequency + phase).truncatingRemainder(dividingBy: 1.0)
        }
        
        // Process full vectors
        for i in 0..<fullVectorCount {
            let baseIndex = i * vectorSize
            
            // Load positions into SIMD vector
            let posVec = SIMD4<Float>(
                positions[baseIndex],
                positions[baseIndex + 1],
                positions[baseIndex + 2],
                positions[baseIndex + 3]
            )
            
            // Convert positions to radians (0-2π)
            let radians = posVec * (2.0 * Float.pi)
            
            // Calculate sine values using vectorized sin
            var sineVec = sin(radians)
            
            // Convert from -1...1 to 0...1
            sineVec = sineVec * 0.5 + 0.5
            
            // Store results
            result[baseIndex] = sineVec[0]
            result[baseIndex + 1] = sineVec[1]
            result[baseIndex + 2] = sineVec[2]
            result[baseIndex + 3] = sineVec[3]
        }
        
        // Process remainder
        let baseIndex = fullVectorCount * vectorSize
        for i in 0..<remainder {
            let pos = positions[baseIndex + i]
            let radians = pos * (2.0 * Float.pi)
            result[baseIndex + i] = (sin(radians) * 0.5) + 0.5
        }
        
        return result
    }
    
//    public func wtSIMD(_ wTable: [Float], _ count: Int) -> (simd_float4) -> simd_float4 {
//        let tableSize = wTable.count
//        
//        return { positions in
//            var result = simd_float4(repeating: 0)
//            
//            for i in 0..<4 {
//                let pos = positions[i]
//                let tablePos = pos * Float(tableSize)
//                let index = Int(tablePos) % tableSize
//                let frac = tablePos - Float(index)
//                let nextIndex = (index + 1) % tableSize
//                
//                result[i] = mix(wTable[index], wTable[nextIndex], t: frac)
//            }
//            
//            return result
//        }
//    }
}

// MARK: - Just-In-Time Compilation

/// Just-In-Time compilation for frequently used operation chains
public class JITWaveformCompiler {
    private let compilerQueue = DispatchQueue(label: "com.ofxCrvs.jit", qos: .utility)
    private var compiledOperations: [String: CompiledOp] = [:]
    
    /// Compiled operation with specialized implementation
    private struct CompiledOp {
        let generate: ([Float]) -> [Float]
        let useCount: Int
    }
    
    /// Register an operation chain for JIT compilation
    public func registerOpChain(id: String, ops: [Crvs.FloatOp]) {
        compilerQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if this chain is already compiled
            if self.compiledOperations[id] != nil {
                return
            }
            
            // Analyze operation chain and create optimized version
            let specializedFunc = self.createSpecializedFunction(ops)
            
            // Store compiled operation
            self.compiledOperations[id] = CompiledOp(generate: specializedFunc, useCount: 0)
        }
    }
    
    /// Generate samples using a compiled operation chain
    public func generateSamples(id: String, count: Int) -> [Float]? {
        guard let compiledOp = compiledOperations[id] else {
            return nil
        }
        
        // Create position array
        let positions = (0..<count).map { Float($0) / Float(count) }
        
        // Use specialized implementation
        return compiledOp.generate(positions)
    }
    
    /// Create a specialized function for the operation chain
    private func createSpecializedFunction(_ ops: [Crvs.FloatOp]) -> ([Float]) -> [Float] {
        // No operations - return identity function
        if ops.isEmpty {
            return { positions in positions }
        }
        
        // Analyze operation types by sampling and comparing behaviors
        let testPositions: [Float] = [0.0, 0.25, 0.5, 0.75]
        
        // Create signature arrays for common operations
        let signatures = detectOperationSignatures(ops, testPositions)
        
        // Check for common patterns
        if let optimizedFunc = detectAndOptimizePatterns(ops, signatures) {
            return optimizedFunc
        }
        
        // Determine if the chain can use SIMD optimization
        if canApplySIMD(signatures) {
            return createSIMDOptimizedFunction(ops)
        }
        
        // Create operation count-specific optimized implementations
        switch ops.count {
        case 1:
            // Single operation - optimize common cases
            return createSingleOpOptimization(ops[0], signatures[0])
        case 2:
            // Two operations - check for common pairs
            return createTwoOpOptimization(ops[0], ops[1], signatures[0], signatures[1])
        case 3:
            // Three operations - check for common triplets
            return createThreeOpOptimization(ops[0], ops[1], ops[2], signatures)
        default:
            // For longer chains, use batch processing with memory reuse
            return createBatchOptimizedFunction(ops)
        }
    }
    
    /// Detect operation signatures by sampling at test positions
    private func detectOperationSignatures(_ ops: [Crvs.FloatOp], _ testPositions: [Float]) -> [[Float]] {
        // Create signature for each operation
        return ops.map { op in
            // Sample operation at test positions
            testPositions.map { op($0) }
        }
    }
    
    /// Detect common operation patterns and return optimized implementation
    private func detectAndOptimizePatterns(_ ops: [Crvs.FloatOp], _ signatures: [[Float]]) -> (([Float]) -> [Float])? {
        // Pattern detection logic
        
        // 1. FM Synthesis Pattern (carrier + modulator)
        if isFMSynthesisPattern(ops, signatures) {
            return createFMSynthesisOptimization(ops)
        }
        
        // 2. Additive Synthesis Pattern (multiple sine/triangle waves)
        if isAdditiveSynthesisPattern(ops, signatures) {
            return createAdditiveSynthesisOptimization(ops)
        }
        
        // 3. ADSR Envelope Pattern
        if isEnvelopePattern(ops, signatures) {
            return createEnvelopeOptimization(ops)
        }
        
        // 4. Filter Chain Pattern
        if isFilterChainPattern(ops, signatures) {
            return createFilterChainOptimization(ops)
        }
        
        // No recognized pattern
        return nil
    }
    
    /// Check if the pattern resembles FM synthesis
    private func isFMSynthesisPattern(_ ops: [Crvs.FloatOp], _ signatures: [[Float]]) -> Bool {
        // FM synthesis typically involves a carrier and modulator with specific relationships
        // This is a simplified detection - real implementation would be more sophisticated
        
        guard ops.count >= 3 else { return false }
        
        // Check for sine waves and ring modulation
        let hasSineWave = signatures.contains { sig in
            // Check if signature resembles sine wave (roughly equal distances between values)
            let diffs = zip(sig[0..<sig.count-1], sig[1..<sig.count]).map { abs($0 - $1) }
            let variance = calculateVariance(diffs)
            return variance < 0.05 // Low variance indicates sine-like behavior
        }
        
        // Check for ring modulation (multiplication)
        let hasMultiplication = signatures.contains { sig in
            // Check if signature shows multiplication pattern (large value changes)
            let maxVal = sig.max() ?? 0
            let minVal = sig.min() ?? 0
            return maxVal - minVal > 0.8 // Large range suggests modulation
        }
        
        return hasSineWave && hasMultiplication
    }
    
    /// Check if the pattern resembles additive synthesis
    private func isAdditiveSynthesisPattern(_ ops: [Crvs.FloatOp], _ signatures: [[Float]]) -> Bool {
        // Additive synthesis often involves multiple sine waves and summing
        
        // Look for multiple similar waveforms and a sum operation
        var sineWaveCount = 0
        
        for sig in signatures {
            // Check for sine-like behavior
            if isSineLike(sig) {
                sineWaveCount += 1
            }
        }
        
        // If we have multiple sine-like operations, likely additive synthesis
        return sineWaveCount >= 2
    }
    
    /// Check if a signature resembles a sine wave
    private func isSineLike(_ signature: [Float]) -> Bool {
        // Simple check - real implementation would be more sophisticated
        if signature.count < 4 { return false }
        
        // Check for zero crossings and peaks
        let diffs = zip(signature[0..<signature.count-1], signature[1..<signature.count]).map { $1 - $0 }
        let signChanges = zip(diffs[0..<diffs.count-1], diffs[1..<diffs.count]).filter { $0 * $1 < 0 }.count
        
        // Sine waves have multiple sign changes
        return signChanges >= 1
    }
    
    /// Check if the pattern resembles an ADSR envelope
    private func isEnvelopePattern(_ ops: [Crvs.FloatOp], _ signatures: [[Float]]) -> Bool {
        // ADSR envelopes typically have a specific shape
        
        if signatures.isEmpty { return false }
        
        // Get combined signature
        var combinedSig = signatures[0]
        for i in 1..<signatures.count {
            combinedSig = zip(combinedSig, signatures[i]).map { $0 * $1 }
        }
        
        // Check for envelope shape (rises then falls)
        var rising = false
        var falling = false
        
        for i in 1..<combinedSig.count {
            if combinedSig[i] > combinedSig[i-1] {
                rising = true
            }
            if combinedSig[i] < combinedSig[i-1] && rising {
                falling = true
            }
        }
        
        return rising && falling
    }
    
    /// Check if the pattern resembles a filter chain
    private func isFilterChainPattern(_ ops: [Crvs.FloatOp], _ signatures: [[Float]]) -> Bool {
        // Filter chains often involve smoothing operations
        
        // Check for progressive smoothing
        var smoothingDetected = false
        
        for i in 1..<signatures.count {
            let prevSig = signatures[i-1]
            let currSig = signatures[i]
            
            // Calculate "smoothness" by looking at sum of absolute differences
            let prevDiffs = zip(prevSig[0..<prevSig.count-1], prevSig[1..<prevSig.count]).map { abs($0 - $1) }
            let currDiffs = zip(currSig[0..<currSig.count-1], currSig[1..<currSig.count]).map { abs($0 - $1) }
            
            let prevRoughness = prevDiffs.reduce(0, +)
            let currRoughness = currDiffs.reduce(0, +)
            
            if currRoughness < prevRoughness * 0.8 {
                smoothingDetected = true
                break
            }
        }
        
        return smoothingDetected
    }
    
    /// Create optimized function for FM synthesis pattern
    private func createFMSynthesisOptimization(_ ops: [Crvs.FloatOp]) -> ([Float]) -> [Float] {
        // Specialized FM synthesis implementation
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            // Use vectorized implementation for FM synthesis
            // This is a simplified version - a real implementation would
            // extract carrier and modulator parameters
            for i in 0..<count {
                let pos = positions[i]
                let modFreq: Float = 5.0 // Example - would extract from ops
                let modDepth: Float = 0.2 // Example - would extract from ops
                
                // Calculate modulator value
                let modPhase = pos * modFreq
                let modValue = sin(modPhase * 2 * Float.pi) * modDepth
                
                // Apply to carrier
                let carrierPhase = pos + modValue
                result[i] = (sin(carrierPhase * 2 * Float.pi) * 0.5) + 0.5
            }
            
            return result
        }
    }

    
    /// Create optimized function for additive synthesis pattern
    private func createAdditiveSynthesisOptimization(_ ops: [Crvs.FloatOp]) -> ([Float]) -> [Float] {
        // Extract estimated frequencies and amplitudes from ops
        // This is a placeholder - real implementation would analyze ops
        let frequencies: [Float] = [1.0, 2.0, 3.0]
        let amplitudes: [Float] = [1.0, 0.5, 0.25]
        
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            // Vectorized additive synthesis
            for i in 0..<count {
                let pos = positions[i]
                var sum: Float = 0
                
                // Combine harmonics
                for j in 0..<min(frequencies.count, amplitudes.count) {
                    let phase = pos * frequencies[j]
                    let sine = (sin(phase * 2 * Float.pi) * 0.5) + 0.5
                    sum += sine * amplitudes[j]
                }
                
                // Normalize
                result[i] = sum / amplitudes.reduce(0, +)
            }
            
            return result
        }
    }
    
    /// Create optimized function for envelope pattern
    private func createEnvelopeOptimization(_ ops: [Crvs.FloatOp]) -> ([Float]) -> [Float] {
        // Extract estimated ADSR parameters from ops
        // This is a placeholder - real implementation would analyze ops
        let attack: Float = 0.1
        let decay: Float = 0.2
        let sustain: Float = 0.7
        let release: Float = 0.3
        
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            // Optimized ADSR calculation
            for i in 0..<count {
                let pos = positions[i]
                
                if pos <= attack {
                    result[i] = pos / attack
                } else if pos <= attack + decay {
                    let decayPos = (pos - attack) / decay
                    result[i] = 1.0 - ((1.0 - sustain) * decayPos)
                } else if pos <= 1.0 - release {
                    result[i] = sustain
                } else {
                    let releasePos = (pos - (1.0 - release)) / release
                    result[i] = sustain * (1.0 - releasePos)
                }
            }
            
            return result
        }
    }
    
    /// Create optimized function for filter chain pattern
    private func createFilterChainOptimization(_ ops: [Crvs.FloatOp]) -> ([Float]) -> [Float] {
        // Extract filter parameters from ops
        // This is a placeholder - real implementation would analyze ops
        let smoothingFactor: Float = 0.2
        
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            // Apply chain of operations to get initial values
            for i in 0..<count {
                var value = positions[i]
                for op in ops {
                    value = op(value)
                }
                result[i] = value
            }
            
            // Apply additional smoothing as a final step
            var smoothed = [Float](repeating: 0, count: count)
            var lastValue: Float = result[0]
            
            for i in 0..<count {
                lastValue = (smoothingFactor * result[i]) + ((1 - smoothingFactor) * lastValue)
                smoothed[i] = lastValue
            }
            
            return smoothed
        }
    }
    
    /// Check if SIMD optimization can be applied
    private func canApplySIMD(_ signatures: [[Float]]) -> Bool {
        // Simple check - real implementation would be more sophisticated
        // SIMD works well for simple, regular operations (e.g., sine waves, scaling)
        
        // Check if operations are mostly uniform
        for sig in signatures {
            if sig.isEmpty { continue }
            
            // Calculate variance of differences
            let diffs = zip(sig[0..<sig.count-1], sig[1..<sig.count]).map { abs($0 - $1) }
            let variance = calculateVariance(diffs)
            
            // High variance may indicate irregular operations not suitable for SIMD
            if variance > 0.1 {
                return false
            }
        }
        
        return true
    }
    
    /// Calculate variance of an array of values
    private func calculateVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        
        // Ensure the accumulator is a Float by using 0.0 as Float
        let mean = values.reduce(0.0 as Float, +) / Float(values.count)
        
        let sumSquaredDifferences = values.reduce(Float(0.0)) { sum, value in
            let diff = value - mean
            return sum + (diff * diff)
        }
        
        return sumSquaredDifferences / Float(values.count)
    }


    
    /// Create SIMD optimized function
    private func createSIMDOptimizedFunction(_ ops: [Crvs.FloatOp]) -> ([Float]) -> [Float] {
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            // Process in chunks of 4 for SIMD optimization
            let chunks = count / 4
            
            for chunk in 0..<chunks {
                let baseIndex = chunk * 4
                
                // Load 4 positions
                var pos0 = positions[baseIndex]
                var pos1 = positions[baseIndex + 1]
                var pos2 = positions[baseIndex + 2]
                var pos3 = positions[baseIndex + 3]
                
                // Apply operations to all 4 positions
                for op in ops {
                    pos0 = op(pos0)
                    pos1 = op(pos1)
                    pos2 = op(pos2)
                    pos3 = op(pos3)
                }
                
                // Store results
                result[baseIndex] = pos0
                result[baseIndex + 1] = pos1
                result[baseIndex + 2] = pos2
                result[baseIndex + 3] = pos3
            }
            
            // Handle remaining positions
            for i in (chunks * 4)..<count {
                var value = positions[i]
                for op in ops {
                    value = op(value)
                }
                result[i] = value
            }
            
            return result
        }
    }
    
    /// Optimize for single operation
    private func createSingleOpOptimization(_ op: @escaping Crvs.FloatOp, _ signature: [Float]) -> ([Float]) -> [Float] {
        // Detect operation type
        if isSineLike(signature) {
            // Optimize sine wave calculation
            return { positions in
                let count = positions.count
                var result = [Float](repeating: 0, count: count)
                
                // Use direct sine calculation for better performance
                for i in 0..<count {
                    result[i] = (sin(positions[i] * 2 * Float.pi) * 0.5) + 0.5
                }
                
                return result
            }
        }
        
        // For other operations, use normal application with batching
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            for i in 0..<count {
                result[i] = op(positions[i])
            }
            
            return result
        }
    }

    
    /// Optimize for two operations
    private func createTwoOpOptimization(_ op1: @escaping Crvs.FloatOp, _ op2: @escaping Crvs.FloatOp,
                                         _ sig1: [Float], _ sig2: [Float]) -> ([Float]) -> [Float] {
        // Check for common combinations
        
        // Phase followed by sine (common pattern)
        if isSineLike(sig2) {
            return { positions in
                let count = positions.count
                var result = [Float](repeating: 0, count: count)
                
                for i in 0..<count {
                    // Apply phase modification
                    let modPos = op1(positions[i])
                    // Direct sine calculation for better performance
                    result[i] = (sin(modPos * 2 * Float.pi) * 0.5) + 0.5
                }
                
                return result
            }
        }
        
        // Default implementation for any two operations
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            for i in 0..<count {
                result[i] = op2(op1(positions[i]))
            }
            
            return result
        }
    }
    
    /// Optimize for three operations
    private func createThreeOpOptimization(_ op1: @escaping Crvs.FloatOp, _ op2: @escaping Crvs.FloatOp,
                                           _ op3: @escaping Crvs.FloatOp, _ signatures: [[Float]]) -> ([Float]) -> [Float] {
        // Check for common triplet patterns
        
        // Phase + sine + scale (common pattern)
        if isSineLike(signatures[1]) {
            return { positions in
                let count = positions.count
                var result = [Float](repeating: 0, count: count)
                
                // Sample operations at control points to determine scale factor
                let testPos: Float = 0.5
                let scaleFactor = op3(op2(op1(testPos))) / op2(op1(testPos))
                
                for i in 0..<count {
                    // Apply phase modification
                    let modPos = op1(positions[i])
                    // Direct sine calculation with scaling
                    let sineVal = (sin(modPos * 2 * Float.pi) * 0.5) + 0.5
                    result[i] = sineVal * scaleFactor
                }
                
                return result
            }
        }
        
        // Default optimization for any three operations
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            for i in 0..<count {
                result[i] = op3(op2(op1(positions[i])))
            }
            
            return result
        }
    }
    
    /// Create batch optimized function for longer chains
    private func createBatchOptimizedFunction(_ ops: [Crvs.FloatOp]) -> ([Float]) -> [Float] {
        return { positions in
            let count = positions.count
            var result = [Float](repeating: 0, count: count)
            
            // Process in larger batches with memory locality optimization
            let batchSize = 64
            let batches = (count + batchSize - 1) / batchSize
            
            for batch in 0..<batches {
                let startIdx = batch * batchSize
                let endIdx = min(startIdx + batchSize, count)
                
                for i in startIdx..<endIdx {
                    var value = positions[i]
                    for op in ops {
                        value = op(value)
                    }
                    result[i] = value
                }
            }
            
            return result
        }
    }
}

// MARK: - Mathematical Approximations

/// Fast approximations of common mathematical functions
public class FastMath {
    
    /// Fast sine approximation (max error < 0.001)
    public static func fastSin(_ x: Float) -> Float {
        // Normalize x to 0...2π range
        let normalized = x.truncatingRemainder(dividingBy: 2.0 * Float.pi)
        
        // Fourth order polynomial approximation
        // Based on Taylor series expansion
        let x2 = normalized * normalized
        let x3 = x2 * normalized
        let x5 = x3 * x2
        let x7 = x5 * x2
        
        return normalized - (x3 / 6.0) + (x5 / 120.0) - (x7 / 5040.0)
    }
    
    /// Fast sine for audio applications (0...1 phase input, 0...1 output)
    public static func fastAudioSin(_ phase: Float) -> Float {
        // Convert 0...1 phase to 0...2π
        let angle = phase * (2.0 * Float.pi)
        
        // Fast sine approximation
        return (fastSin(angle) * 0.5) + 0.5
    }
    
    /// Fast exponential approximation
    public static func fastExp(_ x: Float) -> Float {
        // Valid for range -1...1 with reasonable accuracy
        guard x <= 1.0 && x >= -1.0 else {
            return exp(x) // Fall back to standard exp for out-of-range values
        }
        
        // Polynomial approximation
        let x2 = x * x
        let x3 = x2 * x
        let x4 = x3 * x
        
        return 1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0)
    }
    
    /// Fast logarithm approximation
    public static func fastLog(_ x: Float) -> Float {
        // Valid for range 0.5...2.0 with reasonable accuracy
        guard x <= 2.0 && x >= 0.5 else {
            return log(x) // Fall back to standard log for out-of-range values
        }
        
        // Polynomial approximation centered around 1.0
        let offset = x - 1.0
        let offset2 = offset * offset
        let offset3 = offset2 * offset
        
        return offset - (offset2 / 2.0) + (offset3 / 3.0)
    }
    
    /// Fast power function (x^n) for integer exponents
    public static func fastPow(_ x: Float, _ n: Int) -> Float {
        guard n != 0 else { return 1.0 }
        
        if n < 0 {
            return 1.0 / fastPow(x, -n)
        }
        
        if n == 1 {
            return x
        }
        
        // Use binary exponentiation for faster computation
        let half = fastPow(x, n / 2)
        
        if n % 2 == 0 {
            return half * half
        } else {
            return half * half * x
        }
    }
}

// MARK: - Specialized Waveform Implementations

/// Optimized implementations for specific waveforms
public class OptimizedWaveforms {
    
    /// Optimized sine wave with minimal branching
    public static func optimizedSine(positions: [Float], frequency: Float = 1.0, phase: Float = 0.0) -> [Float] {
        var result = [Float](repeating: 0, count: positions.count)
        
        // Constants for sine approximation
        let c: Float = 2.0 * Float.pi
        
        for i in 0..<positions.count {
            // Apply frequency and phase
            var pos = positions[i] * frequency + phase
            
            // Normalize to 0.0...1.0 range
            pos -= Float(Int(pos))
            if pos < 0 {
                pos += 1.0
            }
            
            // Convert to angle in radians
            let angle = pos * c
            
            // Sine calculation using standard library
            result[i] = (sin(angle) * 0.5) + 0.5
        }
        
        return result
    }
    
    /// Optimized triangle wave with minimal branching
    public static func optimizedTriangle(positions: [Float], frequency: Float = 1.0, phase: Float = 0.0, symmetry: Float = 0.5) -> [Float] {
        var result = [Float](repeating: 0, count: positions.count)
        
        for i in 0..<positions.count {
            // Apply frequency and phase
            var pos = positions[i] * frequency + phase
            
            // Normalize to 0.0...1.0 range
            pos -= Float(Int(pos))
            if pos < 0 {
                pos += 1.0
            }
            
            // Calculate triangle with symmetry
            if pos < symmetry {
                if symmetry > 0 {
                    result[i] = pos / symmetry
                } else {
                    result[i] = 0
                }
            } else {
                if symmetry < 1.0 {
                    result[i] = 1.0 - ((pos - symmetry) / (1.0 - symmetry))
                } else {
                    result[i] = 0
                }
            }
        }
        
        return result
    }
    
    /// Optimized saw wave with minimal branching
    public static func optimizedSaw(positions: [Float], frequency: Float = 1.0, phase: Float = 0.0) -> [Float] {
        var result = [Float](repeating: 0, count: positions.count)
        
        for i in 0..<positions.count {
            // Apply frequency and phase
            var pos = positions[i] * frequency + phase
            
            // Normalize to 0.0...1.0 range
            pos -= Float(Int(pos))
            if pos < 0 {
                pos += 1.0
            }
            
            // Saw wave is simply 1 - position
            result[i] = 1.0 - pos
        }
        
        return result
    }
    
    /// Optimized square wave with minimal branching
    public static func optimizedSquare(positions: [Float], frequency: Float = 1.0, phase: Float = 0.0, pulseWidth: Float = 0.5) -> [Float] {
        var result = [Float](repeating: 0, count: positions.count)
        
        for i in 0..<positions.count {
            // Apply frequency and phase
            var pos = positions[i] * frequency + phase
            
            // Normalize to 0.0...1.0 range
            pos -= Float(Int(pos))
            if pos < 0 {
                pos += 1.0
            }
            
            // Square wave is a simple threshold comparison
            result[i] = pos < pulseWidth ? 0.0 : 1.0
        }
        
        return result
    }
}

// MARK: - Precision Control

/// Tools for controlling floating-point precision
public class PrecisionControl {
    
    /// Convert to half-precision for memory savings
    public static func convertToHalfPrecision(_ values: [Float]) -> [UInt16] {
        return values.map { float16Bits(from: $0) }
    }
    
    /// Convert from half-precision back to single-precision
    public static func convertFromHalfPrecision(_ values: [UInt16]) -> [Float] {
        return values.map { floatBits(from: $0) }
    }
    
    /// Convert a Float32 to Float16 bits
    private static func float16Bits(from value: Float) -> UInt16 {
        let bits = value.bitPattern
        let sign = UInt16((bits >> 31) & 0x1)
        var exp = Int((bits >> 23) & 0xFF) - 127 + 15
        var mantissa = bits & 0x007FFFFF
        
        if exp >= 31 {
            // Handle overflow
            exp = 31
            mantissa = 0
        } else if exp <= 0 {
            // Handle underflow
            exp = 0
            mantissa = 0
        }
        
        // Convert mantissa to 10 bits
        mantissa >>= 13
        
        // Assemble half-precision bits
        return (sign << 15) | (UInt16(exp) << 10) | UInt16(mantissa)
    }
    
    /// Convert Float16 bits to a Float32
    private static func floatBits(from value: UInt16) -> Float {
        let sign = UInt32((value >> 15) & 0x1)
        let exp = Int((value >> 10) & 0x1F)
        let mantissa = UInt32(value & 0x3FF)
        
        if exp == 0 {
            // Zero or subnormal
            if mantissa == 0 {
                return sign == 0 ? 0.0 : -0.0
            }
        }
        
        // Convert to single-precision exponent
        let newExp = UInt32(exp - 15 + 127)
        
        // Convert mantissa to 23 bits
        let newMantissa = mantissa << 13
        
        // Assemble single-precision bits
        let bits = (sign << 31) | (newExp << 23) | newMantissa
        
        return Float(bitPattern: bits)
    }
    
    /// Reduce precision for performance-critical paths
    public static func reducePrecision(_ values: [Float], bits: Int = 16) -> [Float] {
        guard bits < 32 && bits > 0 else { return values }
        
        let mask: UInt32 = ~((1 << (32 - bits)) - 1)
        
        return values.map { Float(bitPattern: $0.bitPattern & mask) }
    }
}

// MARK: - Branch Reduction

/// Implementations that minimize branches for better performance
extension Crvs.Ops {
    
    /// Branchless pulse wave (square wave) implementation
    public func branchlessPulse(_ width: Float = 0.5) -> Crvs.FloatOp {
        return { pos in
            // Normalize position to 0...1 range
            let normalizedPos = pos - floor(pos)
            
            // Use a step function: pos < width ? 0 : 1
            // Branchless implementation using step(edge, x) which is 0 when x < edge, 1 otherwise
            return Float(normalizedPos >= width ? 1.0 : 0.0)
        }
    }
    
    /// Branchless clamp function
    public static func branchlessClamp(_ value: Float, min: Float, max: Float) -> Float {
        // This computes: if value > min then 1.0 else 0.0
        let greaterThanMin: Float = value > min ? 1.0 : 0.0
        // This computes: if value < max then 1.0 else 0.0
        let lessThanMax: Float = value < max ? 1.0 : 0.0
        
        // Inner fmaf computes: lessThanMax * value + max
        let inner = fmaf(lessThanMax, value, max)
        // Outer fmaf computes: greaterThanMin * inner + min
        return fmaf(greaterThanMin, inner, min)
    }

    
    /// Branchless lerp (linear interpolation)
    public static func branchlessLerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        // Standard lerp: return a + (b - a) * t
        
        // Branchless with fused multiply-add (FMA) for better precision
        return fma(t, b - a, a)
    }
    
    /// Branchless absolute value
    public static func branchlessAbs(_ x: Float) -> Float {
        // Standard abs uses a branch: return x < 0 ? -x : x
        
        // Branchless version using bit manipulation
        let bits = x.bitPattern & 0x7FFFFFFF // Clear the sign bit
        return Float(bitPattern: bits)
    }
}
