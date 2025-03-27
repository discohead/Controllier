import Foundation

// MARK: - Core Named Parameter Implementation

/// Protocol for nodes that support parameter modification through a fluent interface
public protocol ParameterizedNode: WaveformNode {
    /// Creates a copy of this node with updated parameters
    func copyWithParameters() -> Self
}

// MARK: - Sequence Generator

/// Sequence generator with configurable parameters
public struct Sequence: ParameterizedNode {
    // Parameters
    private var steps: Int = 16
    private var activeSteps: Int = 8
    private var distribution: DistributionType = .even
    private var rotate: Int = 0
    private var jitter: Float = 0.0
    private var swing: Float = 0.0
    
    // Configuration options
    public enum DistributionType {
        case even          // Evenly distributed steps (like Euclidean)
        case grouped       // Steps grouped together
        case random        // Randomly distributed
        case weighted      // Weighted distribution toward start or end
    }
    
    // MARK: Initialization
    
    public init(steps: Int = 16) {
        self.steps = max(1, steps)
        self.activeSteps = steps / 2
    }
    
    // MARK: WaveformNode Implementation
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        // Generate the pattern based on distribution type
        var pattern = generatePattern()
        
        // Apply rotation if specified
        if rotate != 0 {
            let normalizedRotation = ((rotate % steps) + steps) % steps
            if normalizedRotation > 0 {
                let firstPart = Array(pattern[0..<normalizedRotation])
                let secondPart = Array(pattern[normalizedRotation..<steps])
                pattern = secondPart + firstPart
            }
        }
        
        // Create base sequence function
        var sequenceFunc: Crvs.FloatOp = { pos in
            let index = Int(pos * Float(pattern.count)) % pattern.count
            return pattern[index]
        }
        
        // Apply swing if specified
        if swing > 0.0 {
            let swingOp = ops.bias(
                ops.mult(
                    ops.sine(ops.c(0.0)),
                    swing * 0.1
                ),
                ops.phasor()
            )
            
            sequenceFunc = { pos in
                let modPos = swingOp(pos)
                let index = Int(modPos * Float(pattern.count)) % pattern.count
                return pattern[index]
            }
        }
        
        // Apply jitter if specified
        if jitter > 0.0 {
            let finalFunc = sequenceFunc
            sequenceFunc = { pos in
                // Determine if we should apply jitter to this step
                let shouldJitter = Float.random(in: 0...1) < jitter
                
                if shouldJitter {
                    // Calculate jittered position
                    let jitterAmount = Float.random(in: -0.5...0.5) * jitter * 0.1
                    let adjustedPos = max(0, min(1, pos + jitterAmount))
                    return finalFunc(adjustedPos)
                } else {
                    return finalFunc(pos)
                }
            }
        }
        
        return sequenceFunc
    }
    
    /// Generate the pattern based on distribution type
    private func generatePattern() -> [Float] {
        var pattern = [Float](repeating: 0, count: steps)
        
        switch distribution {
        case .even:
            // Euclidean-style even distribution
            if activeSteps > 0 {
                let stepSpacing = Float(steps) / Float(activeSteps)
                
                for i in 0..<activeSteps {
                    let index = Int(Float(i) * stepSpacing) % steps
                    pattern[index] = 1.0
                }
            }
            
        case .grouped:
            // Create groups of active steps
            let groupCount = min(activeSteps, steps / 2)
            let groupSize = activeSteps / groupCount
            let remainingSteps = activeSteps % groupCount
            
            var stepIndex = 0
            for _ in 0..<groupCount {
                let currentGroupSize = groupSize + (remainingSteps > 0 ? 1 : 0)
                
                for j in 0..<currentGroupSize {
                    if stepIndex + j < steps {
                        pattern[stepIndex + j] = 1.0
                    }
                }
                
                stepIndex += currentGroupSize + 1 // Gap between groups
            }
            
        case .random:
            // Randomly distribute active steps
            var activeIndices = Set<Int>()
            while activeIndices.count < min(activeSteps, steps) {
                activeIndices.insert(Int.random(in: 0..<steps))
            }
            
            for index in activeIndices {
                pattern[index] = 1.0
            }
            
        case .weighted:
            // More active steps toward the beginning, fewer toward the end
            for i in 0..<steps {
                let probability = 1.0 - (Float(i) / Float(steps))
                let threshold = Float(activeSteps) / Float(steps)
                
                if probability > threshold * 0.5 && Float.random(in: 0...1) < probability {
                    pattern[i] = 1.0
                }
            }
            
            // Ensure we have at least some active steps
            if pattern.filter({ $0 > 0.5 }).count == 0 {
                pattern[0] = 1.0
            }
        }
        
        return pattern
    }
    
    // MARK: Fluent Parameter Interface
    
    /// Creates a copy of this node with updated parameters
    public func copyWithParameters() -> Sequence {
        return self
    }
    
    /// Set the total number of steps in the sequence
    public func steps(_ count: Int) -> Sequence {
        var copy = copyWithParameters()
        copy.steps = max(1, count)
        return copy
    }
    
    /// Set the number of active steps in the sequence
    public func active(_ count: Int) -> Sequence {
        var copy = copyWithParameters()
        copy.activeSteps = max(0, min(count, steps))
        return copy
    }
    
    /// Set the distribution pattern
    public func distribution(_ type: DistributionType) -> Sequence {
        var copy = copyWithParameters()
        copy.distribution = type
        return copy
    }
    
    /// Rotate the pattern by a number of steps
    public func rotate(_ steps: Int) -> Sequence {
        var copy = copyWithParameters()
        copy.rotate = steps
        return copy
    }
    
    /// Add timing jitter (0.0-1.0) to introduce humanization
    public func jitter(_ amount: Float) -> Sequence {
        var copy = copyWithParameters()
        copy.jitter = max(0, min(amount, 1.0))
        return copy
    }
    
    /// Add swing feel (0.0-1.0) to the sequence
    public func swing(_ amount: Float) -> Sequence {
        var copy = copyWithParameters()
        copy.swing = max(0, min(amount, 1.0))
        return copy
    }
}

// MARK: - Control Signal Modulator

/// Modulates a control signal with configurable parameters
public struct Modulator: ParameterizedNode {
    // Input source
    private let input: WaveformNode
    
    // Parameters
    private var type: ModulationType = .scale
    private var amount: Float = 0.5
    private var rate: Float = 1.0
    private var shape: ModulationShape = .sine
    private var bipolar: Bool = false
    private var smooth: Float = 0.0
    
    // Configuration options
    public enum ModulationType {
        case scale        // Multiply input
        case offset       // Add to input
        case fold         // Fold input when it exceeds threshold
        case quantize     // Quantize input to steps
        case envelope     // Apply an envelope shape
    }
    
    public enum ModulationShape {
        case sine
        case triangle
        case square
        case random
        case custom(Crvs.FloatOp)
    }
    
    // MARK: Initialization
    
    public init(_ input: WaveformNode) {
        self.input = input
    }
    
    // MARK: WaveformNode Implementation
    
    public func createOperation() -> Crvs.FloatOp {
        let inputOp = input.createOperation()
        
        // Create modulation signal
        let modulationOp = createModulationSignal()
        
        // Apply modulation based on type
        let modulatedOp: Crvs.FloatOp
        
        switch type {
        case .scale:
            // Scale the input by the modulation signal
            if bipolar {
                // Scaling from 0.5-1.5
                modulatedOp = { pos in
                    let modValue = modulationOp(pos)
                    let scaleFactor = 1.0 + (modValue - 0.5) * 2.0 * amount
                    return inputOp(pos) * scaleFactor
                }
            } else {
                // Scaling from 0-1
                modulatedOp = { pos in
                    let modValue = modulationOp(pos)
                    let scaleFactor = 1.0 - amount + modValue * amount
                    return inputOp(pos) * scaleFactor
                }
            }
            
        case .offset:
            // Offset the input by the modulation signal
            if bipolar {
                // Offset -amount to +amount
                modulatedOp = { pos in
                    let modValue = modulationOp(pos)
                    let offsetValue = (modValue - 0.5) * 2.0 * amount
                    return inputOp(pos) + offsetValue
                }
            } else {
                // Offset 0 to +amount
                modulatedOp = { pos in
                    let modValue = modulationOp(pos)
                    let offsetValue = modValue * amount
                    return inputOp(pos) + offsetValue
                }
            }
            
        case .fold:
            // Fold the input when it exceeds a threshold
            modulatedOp = { pos in
                let inputValue = inputOp(pos)
                let thresholdValue = 1.0 - (modulationOp(pos) * amount * 0.5)
                
                if inputValue > thresholdValue {
                    return thresholdValue - (inputValue - thresholdValue)
                } else {
                    return inputValue
                }
            }
            
        case .quantize:
            // Quantize the input to steps
            modulatedOp = { pos in
                let inputValue = inputOp(pos)
                let steps = 2 + Int(modulationOp(pos) * amount * 10)
                let normalized = min(max(inputValue, 0.0), 1.0)
                let quantized = round(normalized * Float(steps)) / Float(steps)
                return quantized
            }
            
        case .envelope:
            // Apply an envelope shape
            modulatedOp = { pos in
                let modValue = modulationOp(pos)
                
                if modValue < 0.001 {
                    return 0.0
                }
                
                return inputOp(pos) * modValue
            }
        }
        
        // Apply smoothing if specified
        if smooth > 0.0 {
            var lastOutput: Float = 0.0
            let smoothAmount = smooth * 0.9 + 0.1 // Range 0.1 to 1.0
            
            return { pos in
                let rawOutput = modulatedOp(pos)
                lastOutput = lastOutput * smoothAmount + rawOutput * (1.0 - smoothAmount)
                return lastOutput
            }
        }
        
        return modulatedOp
    }
    
    /// Create the modulation signal based on shape and rate
    private func createModulationSignal() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        // Create base shape
        let baseOp: Crvs.FloatOp
        
        switch shape {
        case .sine:
            baseOp = ops.sine(ops.c(0.0))
        case .triangle:
            baseOp = ops.tri()
        case .square:
            baseOp = ops.square()
        case .random:
            baseOp = { _ in Float.random(in: 0...1) }
        case .custom(let customOp):
            baseOp = customOp
        }
        
        // Apply rate
        return ops.rate(baseOp, rate)
    }
    
    // MARK: Fluent Parameter Interface
    
    /// Creates a copy of this node with updated parameters
    public func copyWithParameters() -> Modulator {
        return self
    }
    
    /// Set the modulation type
    public func type(_ modulationType: ModulationType) -> Modulator {
        var copy = copyWithParameters()
        copy.type = modulationType
        return copy
    }
    
    /// Set the modulation amount (0.0-1.0)
    public func amount(_ value: Float) -> Modulator {
        var copy = copyWithParameters()
        copy.amount = max(0, min(value, 1.0))
        return copy
    }
    
    /// Set the modulation rate (frequency multiplier)
    public func rate(_ value: Float) -> Modulator {
        var copy = copyWithParameters()
        copy.rate = max(0.1, value)
        return copy
    }
    
    /// Set the modulation shape
    public func shape(_ modulationShape: ModulationShape) -> Modulator {
        var copy = copyWithParameters()
        copy.shape = modulationShape
        return copy
    }
    
    /// Set whether modulation is bipolar (centered around 0) or unipolar (0 to 1)
    public func bipolar(_ enabled: Bool = true) -> Modulator {
        var copy = copyWithParameters()
        copy.bipolar = enabled
        return copy
    }
    
    /// Set smoothing amount (0.0-1.0) to smooth transitions
    public func smooth(_ amount: Float) -> Modulator {
        var copy = copyWithParameters()
        copy.smooth = max(0, min(amount, 1.0))
        return copy
    }
}

// MARK: - Pattern Transformer

/// Transforms patterns with configurable parameters
public struct PatternTransformer: ParameterizedNode {
    // Input source
    private let input: WaveformNode
    
    // Parameters
    private var transformation: TransformationType = .repeat
    private var factor: Int = 2
    private var mix: Float = 1.0
    private var feedback: Float = 0.0
    private var invert: Bool = false
    private var threshold: Float = 0.5
    
    // Configuration options
    public enum TransformationType {
        case `repeat`      // Repeat the pattern multiple times
        case reverse       // Reverse the pattern
        case palindrome    // Play forward then backward
        case interleave    // Interleave with delayed version
        case probabilistic // Apply probabilistic variation
    }
    
    // MARK: Initialization
    
    public init(_ input: WaveformNode) {
        self.input = input
    }
    
    // MARK: WaveformNode Implementation
    
    public func createOperation() -> Crvs.FloatOp {
        let inputOp = input.createOperation()
        
        // Apply transformation based on type
        var transformedOp: Crvs.FloatOp
        
        switch transformation {
        case .repeat:
            // Repeat pattern multiple times (compressed)
            transformedOp = { pos in
                let scaledPos = pos * Float(factor)
                let wrappedPos = scaledPos - floor(scaledPos)
                return inputOp(wrappedPos)
            }
            
        case .reverse:
            // Reverse pattern
            transformedOp = { pos in
                return inputOp(1.0 - pos)
            }
            
        case .palindrome:
            // Play forward then backward
            transformedOp = { pos in
                let scaledPos = pos * 2.0
                if scaledPos < 1.0 {
                    // First half - forward
                    return inputOp(scaledPos)
                } else {
                    // Second half - backward
                    return inputOp(2.0 - scaledPos)
                }
            }
            
        case .interleave:
            // Interleave with delayed version
            let delayAmount = 1.0 / Float(factor * 2)
            
            transformedOp = { pos in
                // Original pattern
                let originalVal = inputOp(pos)
                
                // Delayed pattern
                let delayedPos = (pos + delayAmount).truncatingRemainder(dividingBy: 1.0)
                let delayedVal = inputOp(delayedPos)
                
                // Interleave based on position
                let useOriginal = (pos * Float(factor * 2)).truncatingRemainder(dividingBy: 2.0) < 1.0
                return useOriginal ? originalVal : delayedVal
            }
            
        case .probabilistic:
            // Apply probabilistic variations
            transformedOp = { pos in
                let originalVal = inputOp(pos)
                
                // Decide whether to transform this step
                let rand = Float.random(in: 0...1)
                let transformProb = mix
                
                if rand < transformProb {
                    // Transform by threshold
                    return originalVal > threshold ? 1.0 : 0.0
                } else {
                    return originalVal
                }
            }
        }
        
        // Apply inversion if specified
        if invert {
            let baseOp = transformedOp
            transformedOp = { pos in
                return 1.0 - baseOp(pos)
            }
        }
        
        // Apply feedback if specified
        if feedback > 0.0 {
            var lastOutput: Float = 0.0
            let feedbackOp = transformedOp
            
            transformedOp = { pos in
                let currentOutput = feedbackOp(pos)
                let result = currentOutput + lastOutput * feedback
                lastOutput = currentOutput
                return min(1.0, result)
            }
        }
        
        // Apply mix if not using probabilistic transformation
        if transformation != .probabilistic && mix < 1.0 {
            let originalOp = inputOp
            let transformOp = transformedOp
            
            transformedOp = { pos in
                let original = originalOp(pos)
                let transformed = transformOp(pos)
                return original * (1.0 - mix) + transformed * mix
            }
        }
        
        return transformedOp
    }
    
    // MARK: Fluent Parameter Interface
    
    /// Creates a copy of this node with updated parameters
    public func copyWithParameters() -> PatternTransformer {
        return self
    }
    
    /// Set the transformation type
    public func transformation(_ type: TransformationType) -> PatternTransformer {
        var copy = copyWithParameters()
        copy.transformation = type
        return copy
    }
    
    /// Set the transformation factor (for repeat, interleave)
    public func factor(_ value: Int) -> PatternTransformer {
        var copy = copyWithParameters()
        copy.factor = max(1, value)
        return copy
    }
    
    /// Set the mix amount (0.0-1.0) between original and transformed
    public func mix(_ value: Float) -> PatternTransformer {
        var copy = copyWithParameters()
        copy.mix = max(0, min(value, 1.0))
        return copy
    }
    
    /// Set feedback amount (0.0-1.0)
    public func feedback(_ value: Float) -> PatternTransformer {
        var copy = copyWithParameters()
        copy.feedback = max(0, min(value, 0.95)) // Limit to avoid runaway feedback
        return copy
    }
    
    /// Set whether to invert the pattern
    public func invert(_ enabled: Bool = true) -> PatternTransformer {
        var copy = copyWithParameters()
        copy.invert = enabled
        return copy
    }
    
    /// Set threshold for probabilistic transformation
    public func threshold(_ value: Float) -> PatternTransformer {
        var copy = copyWithParameters()
        copy.threshold = max(0, min(value, 1.0))
        return copy
    }
}

// MARK: - Clock Divider/Multiplier

/// Clock division/multiplication with configurable parameters
public struct DivMultClock: ParameterizedNode {
    // Parameters
    private var division: Float = 1.0
    private var pulseWidth: Float = 0.5
    private var shift: Float = 0.0
    private var shuffle: Float = 0.0
    private var ratcheting: Int = 1
    private var skipProbability: Float = 0.0
    
    // MARK: Initialization
    
    public init(division: Float = 1.0) {
        self.division = max(0.01, division)
    }
    
    // MARK: WaveformNode Implementation
    
    public func createOperation() -> Crvs.FloatOp {
        // Create base clock with division
        var clockOp: Crvs.FloatOp = { pos in
            let scaledPos = pos * division
            let normalizedPos = scaledPos - floor(scaledPos)
            return normalizedPos < pulseWidth ? 1.0 : 0.0
        }
        
        // Apply shift if specified
        if shift != 0.0 {
            let baseOp = clockOp
            clockOp = { pos in
                let shiftedPos = (pos + shift).truncatingRemainder(dividingBy: 1.0)
                return baseOp(shiftedPos)
            }
        }
        
        // Apply shuffle if specified
        if shuffle > 0.0 {
            let baseOp = clockOp
            clockOp = { pos in
                // Every other beat is shifted
                let isBeatShifted = (pos * division * 2).truncatingRemainder(dividingBy: 2.0) >= 1.0
                
                if isBeatShifted {
                    let shuffleAmount = shuffle * 0.25 // Max 25% shift
                    let shuffledPos = (pos + shuffleAmount).truncatingRemainder(dividingBy: 1.0)
                    return baseOp(shuffledPos)
                } else {
                    return baseOp(pos)
                }
            }
        }
        
        // Apply ratcheting if specified
        if ratcheting > 1 {
            let baseOp = clockOp
            clockOp = { pos in
                let baseClock = baseOp(pos)
                
                if baseClock > 0.5 {
                    // During a clock pulse, generate ratcheting pulses
                    let ratchetPos = (pos * division * Float(ratcheting)).truncatingRemainder(dividingBy: 1.0)
                    return ratchetPos < pulseWidth ? 1.0 : 0.0
                } else {
                    return 0.0
                }
            }
        }
        
        // Apply skip probability if specified
        if skipProbability > 0.0 {
            let baseOp = clockOp
            clockOp = { pos in
                let normalClock = baseOp(pos)
                
                // Only consider skipping when there would be a pulse
                if normalClock > 0.5 {
                    // Decide whether to skip this pulse
                    let skipRand = Float.random(in: 0...1)
                    if skipRand < skipProbability {
                        return 0.0
                    }
                }
                
                return normalClock
            }
        }
        
        return clockOp
    }
    
    // MARK: Fluent Parameter Interface
    
    /// Creates a copy of this node with updated parameters
    public func copyWithParameters() -> DivMultClock {
        return self
    }
    
    /// Set the clock division factor
    public func division(_ value: Float) -> DivMultClock {
        var copy = copyWithParameters()
        copy.division = max(0.01, value)
        return copy
    }
    
    /// Set the pulse width (0.0-1.0)
    public func pulseWidth(_ value: Float) -> DivMultClock {
        var copy = copyWithParameters()
        copy.pulseWidth = max(0.01, min(value, 0.99))
        return copy
    }
    
    /// Set the phase shift (0.0-1.0)
    public func shift(_ value: Float) -> DivMultClock {
        var copy = copyWithParameters()
        copy.shift = value.truncatingRemainder(dividingBy: 1.0)
        return copy
    }
    
    /// Set the shuffle amount (0.0-1.0) for swing feel
    public func shuffle(_ value: Float) -> DivMultClock {
        var copy = copyWithParameters()
        copy.shuffle = max(0, min(value, 1.0))
        return copy
    }
    
    /// Set the ratcheting factor (1 = no ratcheting, >1 = subdivide pulses)
    public func ratcheting(_ count: Int) -> DivMultClock {
        var copy = copyWithParameters()
        copy.ratcheting = max(1, count)
        return copy
    }
    
    /// Set the probability of skipping pulses (0.0-1.0)
    public func skipProbability(_ value: Float) -> DivMultClock {
        var copy = copyWithParameters()
        copy.skipProbability = max(0, min(value, 1.0))
        return copy
    }
}

// MARK: - Randomizer Node

/// Generates random patterns with configurable parameters
public struct Randomizer: ParameterizedNode {
    // Parameters
    private var density: Float = 0.5
    private var seed: Int = 0
    private var smooth: Float = 0.0
    private var fractal: Bool = false
    private var octaves: Int = 1
    private var correlationX: Float = 0.1
    private var correlationY: Float = 0.1
    
    // MARK: Initialization
    
    public init(density: Float = 0.5) {
        self.density = max(0, min(density, 1.0))
    }
    
    // MARK: WaveformNode Implementation
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        // Create randomized function based on parameters
        var randomOp: Crvs.FloatOp
        
        if fractal {
            // Use Perlin noise for smoother randomization
            randomOp = ops.perlin(
                ops.mult(ops.phasor(), correlationX),
                ops.c(correlationY),
                nil,
                ops.c(0.5),
                ops.c(Float(octaves))
            )
        } else {
            // Use basic random function
            let seededRandom = SeededRandom(seed: seed)
            randomOp = { pos in
                // Use position for deterministic randomness
                let scaledPos = Int(pos * 1000) + seed
                return seededRandom.random(seed: scaledPos)
            }
        }
        
        // Apply density threshold
        var thresholdOp: Crvs.FloatOp = { pos in
            let randomValue = randomOp(pos)
            return randomValue < density ? 1.0 : 0.0
        }
        
        // Apply smoothing if specified
        if smooth > 0.0 {
            var lastOutput: Float = 0.0
            let smoothAmount = smooth * 0.9 + 0.1 // Range 0.1 to 1.0
            let baseOp = thresholdOp
            
            thresholdOp = { pos in
                let rawOutput = baseOp(pos)
                lastOutput = lastOutput * smoothAmount + rawOutput * (1.0 - smoothAmount)
                return lastOutput
            }
        }
        
        return thresholdOp
    }
    
    // MARK: Fluent Parameter Interface
    
    /// Creates a copy of this node with updated parameters
    public func copyWithParameters() -> Randomizer {
        return self
    }
    
    /// Set the density (probability) of active steps (0.0-1.0)
    public func density(_ value: Float) -> Randomizer {
        var copy = copyWithParameters()
        copy.density = max(0, min(value, 1.0))
        return copy
    }
    
    /// Set the random seed for deterministic output
    public func seed(_ value: Int) -> Randomizer {
        var copy = copyWithParameters()
        copy.seed = value
        return copy
    }
    
    /// Set smoothing amount (0.0-1.0)
    public func smooth(_ value: Float) -> Randomizer {
        var copy = copyWithParameters()
        copy.smooth = max(0, min(value, 1.0))
        return copy
    }
    
    /// Set whether to use fractal noise instead of pure random
    public func fractal(_ enabled: Bool = true) -> Randomizer {
        var copy = copyWithParameters()
        copy.fractal = enabled
        return copy
    }
    
    /// Set the number of octaves for fractal noise
    public func octaves(_ count: Int) -> Randomizer {
        var copy = copyWithParameters()
        copy.octaves = max(1, min(count, 8))
        return copy
    }
    
    /// Set the correlation along X axis (0.0-1.0)
    public func correlationX(_ value: Float) -> Randomizer {
        var copy = copyWithParameters()
        copy.correlationX = max(0.001, min(value, 10.0))
        return copy
    }
    
    /// Set the correlation along Y axis (0.0-1.0)
    public func correlationY(_ value: Float) -> Randomizer {
        var copy = copyWithParameters()
        copy.correlationY = max(0.001, min(value, 10.0))
        return copy
    }
}

// MARK: - Helper Classes

/// Deterministic random number generator based on seed
fileprivate struct SeededRandom {
    let seed: Int
    
    func random(seed: Int) -> Float {
        // Simple but effective hash function for generating pseudo-random numbers
        var h = seed
        h = ((h >> 16) ^ h) &* 0x45d9f3b
        h = ((h >> 16) ^ h) &* 0x45d9f3b
        h = (h >> 16) ^ h
        
        // Convert to 0.0-1.0 range
        return Float(h & 0x7FFFFFFF) / Float(0x7FFFFFFF)
    }
}

// MARK: - Pattern Combiner

/// Combines multiple patterns with configurable parameters
public struct PatternCombiner: ParameterizedNode {
    // Input patterns
    private let inputs: [WaveformNode]
    
    // Parameters
    private var mode: CombineMode = .mix
    private var weights: [Float]?
    private var threshold: Float = 0.5
    private var smoothing: Float = 0.0
    
    // Configuration options
    public enum CombineMode {
        case mix       // Weighted mix of patterns
        case crossfade // Dynamic crossfade between patterns
        case layer     // Layer patterns (sum with threshold)
        case select    // Select between patterns based on position
        case logical   // Apply logical operations (AND, OR, XOR)
    }
    
    private enum LogicalOperation {
        case and, or, xor
    }
    private var logicalOp: LogicalOperation = .or
    
    // MARK: Initialization
    
    public init(_ inputs: [WaveformNode]) {
        self.inputs = inputs
    }
    
    public init(_ inputs: WaveformNode...) {
        self.inputs = inputs
    }
    
    // MARK: WaveformNode Implementation
    
    public func createOperation() -> Crvs.FloatOp {
        // Handle empty inputs
        guard !inputs.isEmpty else {
            return { _ in 0.0 }
        }
        
        // If only one input, just pass through
        if inputs.count == 1 {
            return inputs[0].createOperation()
        }
        
        // Process input operations
        let inputOps = inputs.map { $0.createOperation() }
        
        // Apply combination based on mode
        var combinedOp: Crvs.FloatOp
        
        switch mode {
        case .mix:
            // Weighted mix of patterns
            let normalizedWeights = normalizeWeights()
            
            combinedOp = { pos in
                var weightedSum: Float = 0.0
                
                for i in 0..<inputOps.count {
                    let weight = i < normalizedWeights.count ? normalizedWeights[i] : 1.0 / Float(inputOps.count)
                    weightedSum += inputOps[i](pos) * weight
                }
                
                return weightedSum
            }
            
        case .crossfade:
            // Dynamic crossfade between patterns based on position
            combinedOp = { pos in
                let fadePosition = pos * Float(inputOps.count)
                let index1 = Int(fadePosition) % inputOps.count
                let index2 = (index1 + 1) % inputOps.count
                let fade = fadePosition - Float(Int(fadePosition))
                
                return inputOps[index1](pos) * (1.0 - fade) + inputOps[index2](pos) * fade
            }
            
        case .layer:
            // Layer patterns (sum with threshold)
            combinedOp = { pos in
                var sum: Float = 0.0
                
                for op in inputOps {
                    sum += op(pos)
                }
                
                // Apply threshold
                return sum > threshold ? 1.0 : 0.0
            }
            
        case .select:
            // Select between patterns based on position
            combinedOp = { pos in
                let selectPosition = pos * Float(inputOps.count)
                let index = Int(selectPosition) % inputOps.count
                return inputOps[index](pos)
            }
            
        case .logical:
            // Apply logical operations (AND, OR, XOR)
            combinedOp = { pos in
                // Get values from all inputs
                let values = inputOps.map { $0(pos) > threshold ? 1.0 : 0.0 }
                
                // Apply logical operation
                switch logicalOp {
                case .and:
                    return values.allSatisfy { $0 > 0.0 } ? 1.0 : 0.0
                case .or:
                    return values.contains(where: { $0 > 0.0 }) ? 1.0 : 0.0
                case .xor:
                    let activeCount = values.filter { $0 > 0.0 }.count
                    return activeCount % 2 == 1 ? 1.0 : 0.0
                }
            }
        }
        
        // Apply smoothing if specified
        if smoothing > 0.0 {
            var lastOutput: Float = 0.0
            let smoothingFactor = smoothing * 0.9 + 0.1 // Range 0.1 to 1.0
            let baseOp = combinedOp
            
            combinedOp = { pos in
                let rawOutput = baseOp(pos)
                lastOutput = lastOutput * smoothingFactor + rawOutput * (1.0 - smoothingFactor)
                return lastOutput
            }
        }
        
        return combinedOp
    }
    
    /// Normalize weights to sum to 1.0
    private func normalizeWeights() -> [Float] {
        guard let weights = weights, !weights.isEmpty else {
            // Default to equal weights
            return [Float](repeating: 1.0 / Float(inputs.count), count: inputs.count)
        }
        
        let weightSum = weights.reduce(0, +)
        
        if weightSum > 0 {
            return weights.map { $0 / weightSum }
        } else {
            return [Float](repeating: 1.0 / Float(weights.count), count: weights.count)
        }
    }
    
    // MARK: Fluent Parameter Interface
    
    /// Creates a copy of this node with updated parameters
    public func copyWithParameters() -> PatternCombiner {
        return self
    }
    
    /// Set the combination mode
    public func mode(_ combineMode: CombineMode) -> PatternCombiner {
        var copy = copyWithParameters()
        copy.mode = combineMode
        return copy
    }
    
    /// Set the weights for mixing patterns
    public func weights(_ values: [Float]) -> PatternCombiner {
        var copy = copyWithParameters()
        copy.weights = values
        return copy
    }
    
    /// Set the threshold for layer mode
    public func threshold(_ value: Float) -> PatternCombiner {
        var copy = copyWithParameters()
        copy.threshold = max(0, min(value, 1.0))
        return copy
    }
    
    /// Set smoothing amount (0.0-1.0)
    public func smoothing(_ value: Float) -> PatternCombiner {
        var copy = copyWithParameters()
        copy.smoothing = max(0, min(value, 1.0))
        return copy
    }
    
    /// Set the logical operation mode
    public func logical(_ operation: String) -> PatternCombiner {
        var copy = copyWithParameters()
        copy.mode = .logical
        
        switch operation.lowercased() {
        case "and":
            copy.logicalOp = .and
        case "xor":
            copy.logicalOp = .xor
        default:
            copy.logicalOp = .or
        }
        
        return copy
    }
}

// MARK: - Usage Examples

/// Examples of using the parameters pattern in practice
class NamedParameterExamples {
    let ops = Crvs.Ops()
    
    func basicSequenceExample() -> Crvs.FloatOp {
        // Create a sequence with named parameters
        let sequence = ops.waveform {
            Sequence(steps: 16)
                .active(8)
                .distribution(.even)
                .rotate(2)
                .swing(0.3)
        }
        
        return sequence
    }
    
    func complexModulationExample() -> Crvs.FloatOp {
        // Create a sequence with complex modulation
        let modulatedSequence = ops.waveform {
            Modulator(
                Sequence()
                    .active(5)
                    .distribution(.random)
                    .swing(0.2)
            )
            .type(.scale)
            .amount(0.7)
            .rate(0.25)
            .shape(.triangle)
            .bipolar(true)
        }
        
        return modulatedSequence
    }
    
    func patternTransformationExample() -> Crvs.FloatOp {
        // Create a transformed pattern
        let transformedPattern = ops.waveform {
            PatternTransformer(
                Sequence()
                    .active(4)
                    .distribution(.even)
            )
            .transformation(.palindrome)
            .mix(0.8)
            .feedback(0.3)
        }
        
        return transformedPattern
    }
    
    func clockDivisionExample() -> Crvs.FloatOp {
        // Create complex clock divisions
        let complexClock = ops.waveform {
            DivMultClock(division: 4)
                .pulseWidth(0.3)
                .shuffle(0.4)
                .ratcheting(3)
                .skipProbability(0.1)
        }
        
        return complexClock
    }
    
    func combinedPatternsExample() -> Crvs.FloatOp {
        // Create a pattern combining multiple sequences
        let combinedPattern = ops.waveform {
            PatternCombiner(
                Sequence().active(3).distribution(.even),
                Sequence().active(4).distribution(.grouped).rotate(2),
                Randomizer().density(0.3).fractal(true).octaves(2)
            )
            .mode(.logical)
            .logical("xor")
            .threshold(0.6)
            .smoothing(0.2)
        }
        
        return combinedPattern
    }
    
    func complexExampleForVisualization() -> Crvs.FloatOp {
        // Create a complex generative sequence for visualization
        let complexSequence = ops.waveform {
            // Base pattern with probability
            PatternCombiner(
                // Euclidean-style pattern
                Sequence()
                    .active(5)
                    .distribution(.even)
                    .swing(0.3),
                
                // Randomized accents
                Randomizer()
                    .density(0.2)
                    .fractal(true)
                    .correlationX(0.5)
            )
            .mode(.layer)
            .threshold(0.3)
            
            // Apply transformation
            PatternTransformer(IdentityNode())
                .transformation(.palindrome)
                .factor(2)
                .mix(0.7)
        }
        
        return complexSequence
    }
}
