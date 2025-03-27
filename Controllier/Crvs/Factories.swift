import Foundation

// MARK: - Core Factory System

/// Factory system that generates novel FloatOps through algorithmic composition
class OpFactory {
    private let ops = Crvs.Ops()
    private var rng: RandomNumberGenerator
    
    // Classification of available operations by category
    private let oscillators: [String: (OpFactory) -> Crvs.FloatOp]
    private let modulators: [String: (OpFactory) -> Crvs.FloatOp]
    private let shapers: [String: (OpFactory) -> Crvs.FloatOp]
    private let combiners: [String: (OpFactory, Crvs.FloatOp, Crvs.FloatOp) -> Crvs.FloatOp]
    
    /// Initialize with optional seed for reproducibility
    init(seed: UInt64? = nil) {
        // Create seeded RNG if seed provided, otherwise use system RNG
        if let seed = seed {
            var seededGenerator = SeededGenerator(seed: seed)
            self.rng = seededGenerator
        } else {
            self.rng = SystemRandomNumberGenerator()
        }
        
        // Define available operations by category
        
        // Basic oscillators (generate base waveforms)
        oscillators = [
            "sine": { factory in factory.ops.sine(factory.randomFloatInRange(0.0...0.3)) },
            "triangle": { factory in factory.ops.tri(factory.randomFloatInRange(0.2...0.8)) },
            "saw": { factory in factory.ops.saw() },
            "square": { factory in factory.ops.pulse(factory.randomFloatInRange(0.2...0.8)) },
            "perlin": { factory in 
                factory.ops.perlin(
                    factory.ops.phasor(),
                    factory.ops.c(factory.randomFloatInRange(0.0...1.0)),
                    nil,
                    factory.ops.c(factory.randomFloatInRange(0.3...0.7)),
                    factory.ops.c(Float(factory.randomIntInRange(1...3)))
                )
            }
        ]
        
        // Modulators (modify other operations)
        modulators = [
            "phase": { factory in 
                { op in factory.ops.phase(op, factory.randomFloatInRange(0.0...0.5)) }
            },
            "rate": { factory in 
                { op in factory.ops.rate(op, factory.randomFloatInRange(0.5...2.0)) }
            },
            "bias": { factory in 
                { op in factory.ops.bias(op, factory.randomFloatInRange(-0.2...0.2)) }
            },
            "multiply": { factory in 
                { op in factory.ops.mult(op, factory.randomFloatInRange(0.5...1.5)) }
            }
        ]
        
        // Shapers (transform the signal)
        shapers = [
            "easeIn": { factory in factory.ops.easeIn(factory.randomFloatInRange(1.5...3.0)) },
            "easeOut": { factory in factory.ops.easeOut(factory.randomFloatInRange(1.5...3.0)) },
            "easeInOut": { factory in factory.ops.easeInOut(factory.randomFloatInRange(1.5...3.0)) },
            "fold": { factory in 
                { op in factory.ops.fold(op, factory.randomFloatInRange(0.7...1.0)) }
            },
            "abs": { factory in 
                { op in factory.ops.abs(op) }
            }
        ]
        
        // Combiners (combine multiple operations)
        combiners = [
            "ring": { factory, opA, opB in factory.ops.ring(opA, opB) },
            "mix": { factory, opA, opB in 
                factory.ops.mix([opA, opB], [factory.randomFloatInRange(0.3...0.7), factory.randomFloatInRange(0.3...0.7)])
            },
            "morph": { factory, opA, opB in 
                factory.ops.morph(opA, opB, factory.ops.c(factory.randomFloatInRange(0.0...1.0)))
            }
        ]
    }
    
    // MARK: - Core Generation Methods
    
    /// Generate a novel oscillator with a random structure
    public func generateOp(complexity: Float = 0.5) -> Crvs.FloatOp {
        // More complexity means more operations chained together
        let numOperations = 2 + Int(complexity * 5)
        
        // Start with a base oscillator
        var currentOp = generateBaseOscillator()
        
        // Apply random modulations and transformations
        for _ in 0..<numOperations {
            // Randomly decide which type of operation to apply next
            let operationType = randomIntInRange(0...2)
            
            switch operationType {
            case 0:
                // Apply a modulator
                if let modulator = randomModulator() {
                    currentOp = modulator(currentOp)
                }
            case 1:
                // Apply a shaper
                if let shaper = randomShaper() {
                    // Some shapers take the op as an argument, others are applied to it
                    if randomBool() {
                        currentOp = shaper(currentOp)
                    } else {
                        let shaperOp = shaper
                        currentOp = ops.chain([currentOp, shaperOp])
                    }
                }
            case 2:
                // Combine with another operation
                if let combiner = randomCombiner() {
                    let secondaryOp = generateBaseOscillator()
                    currentOp = combiner(self, currentOp, secondaryOp)
                }
            default:
                break
            }
        }
        
        return currentOp
    }
    
    /// Generate a specific type of oscillator with controlled parameters
    public func generateOscillator(type: String, parameters: [String: Float] = [:]) -> Crvs.FloatOp {
        switch type {
        case "sine":
            let feedback = parameters["feedback"] ?? randomFloatInRange(0.0...0.3)
            return ops.sine(feedback)
        case "triangle":
            let symmetry = parameters["symmetry"] ?? randomFloatInRange(0.2...0.8)
            return ops.tri(symmetry)
        case "saw":
            return ops.saw()
        case "square", "pulse":
            let width = parameters["width"] ?? randomFloatInRange(0.2...0.8)
            return ops.pulse(width)
        case "perlin":
            return ops.perlin(
                ops.phasor(),
                ops.c(parameters["y"] ?? randomFloatInRange(0.0...1.0)),
                nil,
                ops.c(parameters["falloff"] ?? randomFloatInRange(0.3...0.7)),
                ops.c(Float(Int(parameters["octaves"] ?? Float(randomIntInRange(1...3)))))
            )
        default:
            // Default to sine wave if type not recognized
            return ops.sine()
        }
    }
    
    /// Generate a modulated version of an operation
    public func generateModulatedOp(baseOp: Crvs.FloatOp, modulationType: String, amount: Float = 0.5) -> Crvs.FloatOp {
        switch modulationType {
        case "phase":
            // Phase modulation with LFO
            let modulationOp = generateOscillator(type: "sine", parameters: ["frequency": 0.25])
            return ops.phase(baseOp, ops.mult(modulationOp, amount * 0.2))
        case "amplitude":
            // Amplitude modulation with LFO
            let modulationOp = generateOscillator(type: "triangle", parameters: ["frequency": 0.5])
            return ops.ring(baseOp, ops.bias(ops.mult(modulationOp, amount * 0.5), 1.0 - amount * 0.5))
        case "frequency":
            // Frequency/rate modulation
            let rate = 1.0 + amount * randomFloatInRange(-0.5...1.0)
            return ops.rate(baseOp, rate)
        default:
            return baseOp
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generate a random base oscillator
    private func generateBaseOscillator() -> Crvs.FloatOp {
        let oscillatorNames = Array(oscillators.keys)
        let randomIndex = randomIntInRange(0..<oscillatorNames.count)
        let oscillatorName = oscillatorNames[randomIndex]
        
        if let oscillatorGenerator = oscillators[oscillatorName] {
            return oscillatorGenerator(self)
        }
        
        // Fallback to sine wave
        return ops.sine()
    }
    
    /// Get a random modulator function
    private func randomModulator() -> ((Crvs.FloatOp) -> Crvs.FloatOp)? {
        let modulatorNames = Array(modulators.keys)
        guard !modulatorNames.isEmpty else { return nil }
        
        let randomIndex = randomIntInRange(0..<modulatorNames.count)
        let modulatorName = modulatorNames[randomIndex]
        
        if let modulatorGenerator = modulators[modulatorName] {
            return modulatorGenerator(self)
        }
        
        return nil
    }
    
    /// Get a random shaper function
    private func randomShaper() -> ((Crvs.FloatOp) -> Crvs.FloatOp)? {
        let shaperNames = Array(shapers.keys)
        guard !shaperNames.isEmpty else { return nil }
        
        let randomIndex = randomIntInRange(0..<shaperNames.count)
        let shaperName = shaperNames[randomIndex]
        
        if let shaperGenerator = shapers[shaperName] {
            return shaperGenerator(self)
        }
        
        return nil
    }
    
    /// Get a random shaper as a standalone operation
    private func randomShaperOp() -> Crvs.FloatOp? {
        let shaperNames = Array(shapers.keys)
        guard !shaperNames.isEmpty else { return nil }
        
        let randomIndex = randomIntInRange(0..<shaperNames.count)
        let shaperName = shaperNames[randomIndex]
        
        if let shaperGenerator = shapers[shaperName] {
            return shaperGenerator(self)
        }
        
        return nil
    }
    
    /// Get a random combiner function
    private func randomCombiner() -> ((OpFactory, Crvs.FloatOp, Crvs.FloatOp) -> Crvs.FloatOp)? {
        let combinerNames = Array(combiners.keys)
        guard !combinerNames.isEmpty else { return nil }
        
        let randomIndex = randomIntInRange(0..<combinerNames.count)
        let combinerName = combinerNames[randomIndex]
        
        return combiners[combinerName]
    }
    
    // MARK: - Random Value Generation
    
    /// Generate a random float in the specified range
    func randomFloatInRange(_ range: ClosedRange<Float>) -> Float {
        return Float.random(in: range, using: &rng)
    }
    
    /// Generate a random integer in the specified range
    func randomIntInRange(_ range: Range<Int>) -> Int {
        return Int.random(in: range, using: &rng)
    }
    
    /// Generate a random integer in the specified closed range
    func randomIntInRange(_ range: ClosedRange<Int>) -> Int {
        return Int.random(in: range, using: &rng)
    }
    
    /// Generate a random boolean
    func randomBool() -> Bool {
        return Bool.random(using: &rng)
    }
    
    /// Choose a random element from an array
    func randomChoice<T>(_ array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let index = randomIntInRange(0..<array.count)
        return array[index]
    }
}

// MARK: - Seeded Random Generator

/// Custom random number generator for seeded randomness
struct SeededGenerator: RandomNumberGenerator {
    private var seed: UInt64
    
    init(seed: UInt64) {
        self.seed = seed
    }
    
    mutating func next() -> UInt64 {
        // Simple xorshift algorithm
        seed ^= seed << 13
        seed ^= seed >> 7
        seed ^= seed << 17
        return seed
    }
}

// MARK: - Rhythm Pattern Factory

/// Factory for generating rhythmic patterns with musical constraints
class RhythmFactory {
    private let opFactory: OpFactory
    private let ops = Crvs.Ops()
    
    /// Initialize with optional seed for reproducibility
    init(seed: UInt64? = nil) {
        self.opFactory = OpFactory(seed: seed)
    }
    
    // MARK: - Main Generation Methods
    
    /// Generate a rhythm pattern with specified musical parameters
    /// - Parameters:
    ///   - density: Rhythmic density (0-1, from sparse to dense)
    ///   - complexity: Pattern complexity (0-1, from simple to complex)
    ///   - style: Rhythmic style ("straight", "swing", "broken", "syncopated")
    /// - Returns: A rhythm generation function
    public func generate(density: Float, complexity: Float, style: String = "straight") -> Crvs.FloatOp {
        switch style.lowercased() {
        case "swing":
            return generateSwingRhythm(density: density, complexity: complexity)
        case "broken":
            return generateBrokenRhythm(density: density, complexity: complexity)
        case "syncopated":
            return generateSyncopatedRhythm(density: density, complexity: complexity)
        case "euclidean":
            return generateEuclideanRhythm(density: density, complexity: complexity)
        default:
            return generateStraightRhythm(density: density, complexity: complexity)
        }
    }
    
    /// Generate a completely novel rhythm based on specified characteristics
    /// - Parameters:
    ///   - character: Descriptive terms for the desired rhythm
    ///   - parameters: Optional specific parameters to control generation
    /// - Returns: A rhythm generation function with the desired character
    public func generateNovel(character: [String], parameters: [String: Float] = [:]) -> Crvs.FloatOp {
        // Map character terms to generation parameters
        var density: Float = 0.5
        var complexity: Float = 0.5
        var styles: [String] = ["straight"]
        
        for term in character {
            switch term.lowercased() {
            case "sparse":
                density = opFactory.randomFloatInRange(0.1...0.3)
            case "dense":
                density = opFactory.randomFloatInRange(0.7...0.9)
            case "simple":
                complexity = opFactory.randomFloatInRange(0.1...0.3)
            case "complex":
                complexity = opFactory.randomFloatInRange(0.7...0.9)
            case "swing", "broken", "syncopated", "euclidean":
                styles.append(term.lowercased())
            case "natural", "human":
                // Add humanization
                complexity += 0.2
            case "electronic", "mechanical":
                // Reduce humanization
                complexity -= 0.2
            default:
                break
            }
        }
        
        // Override with explicit parameters if provided
        if let paramDensity = parameters["density"] {
            density = paramDensity
        }
        
        if let paramComplexity = parameters["complexity"] {
            complexity = paramComplexity
        }
        
        // Constrain parameters to valid ranges
        density = min(max(density, 0.0), 1.0)
        complexity = min(max(complexity, 0.0), 1.0)
        
        // Choose a style if multiple are specified
        let style = styles.count > 1 ? styles[opFactory.randomIntInRange(1..<styles.count)] : "straight"
        
        // Generate base rhythm
        var rhythm = generate(density: density, complexity: complexity, style: style)
        
        // Add humanization based on complexity
        if complexity > 0.5 {
            let humanizationAmount = (complexity - 0.5) * 0.2
            rhythm = humanizeRhythm(rhythm, amount: humanizationAmount)
        }
        
        return rhythm
    }
    
    /// Generate multiple rhythm variations based on a common theme
    /// - Parameters:
    ///   - baseCharacter: Base character for all variations
    ///   - variationCount: Number of variations to generate
    ///   - variationAmount: How much the variations should differ (0-1)
    /// - Returns: Array of rhythm generation functions
    public func generateVariations(baseCharacter: [String], variationCount: Int, variationAmount: Float) -> [Crvs.FloatOp] {
        // Create base rhythm
        let baseRhythm = generateNovel(character: baseCharacter)
        
        var variations = [baseRhythm]
        
        // Generate variations
        for _ in 1..<variationCount {
            let variationType = opFactory.randomIntInRange(0...3)
            
            switch variationType {
            case 0:
                // Density variation
                let densityChange = opFactory.randomFloatInRange(-variationAmount...variationAmount) * 0.3
                let varRhythm = generateNovel(
                    character: baseCharacter,
                    parameters: ["density": 0.5 + densityChange]
                )
                variations.append(varRhythm)
                
            case 1:
                // Complexity variation
                let complexityChange = opFactory.randomFloatInRange(-variationAmount...variationAmount) * 0.3
                let varRhythm = generateNovel(
                    character: baseCharacter,
                    parameters: ["complexity": 0.5 + complexityChange]
                )
                variations.append(varRhythm)
                
            case 2:
                // Phase variation
                let phaseOffset = opFactory.randomFloatInRange(0.0...0.25) * variationAmount
                let varRhythm = ops.phase(baseRhythm, phaseOffset)
                variations.append(varRhythm)
                
            case 3:
                // Style variation
                var modifiedCharacter = baseCharacter
                let styles = ["swing", "straight", "broken", "syncopated", "euclidean"]
                if let newStyle = opFactory.randomChoice(styles) {
                    modifiedCharacter.append(newStyle)
                    let varRhythm = generateNovel(character: modifiedCharacter)
                    variations.append(varRhythm)
                }
                
            default:
                variations.append(baseRhythm)
            }
        }
        
        return variations
    }
    
    // MARK: - Specific Rhythm Types
    
    /// Generate a straight rhythm with regular divisions
    private func generateStraightRhythm(density: Float, complexity: Float) -> Crvs.FloatOp {
        // Calculate number of pulses based on density (1 to 16)
        let pulsesPerCycle = 1 + Int(density * 15)
        
        // Base pulse division
        let pulseDivision = ops.pulse(
            ops.mult(
                ops.phasor(),
                Float(pulsesPerCycle)
            ),
            0.3
        )
        
        // If complexity is low, return simple pulse division
        if complexity < 0.3 {
            return pulseDivision
        }
        
        // For higher complexity, add variations
        if complexity < 0.6 {
            // Add subtle variations in pulse width
            let pulseWidthLFO = ops.bias(
                ops.mult(
                    ops.sine(ops.c(0.0)),
                    complexity * 0.15
                ),
                0.3
            )
            
            return ops.pulse(
                ops.mult(
                    ops.phasor(),
                    Float(pulsesPerCycle)
                ),
                pulseWidthLFO
            )
        } else {
            // More complex version: add occasional extra hits
            let primaryPulse = pulseDivision
            
            // Create secondary pulse with offset
            let secondaryPulse = ops.pulse(
                ops.phase(
                    ops.mult(
                        ops.phasor(),
                        Float(pulsesPerCycle) * 2
                    ),
                    0.25
                ),
                0.15
            )
            
            // Mix with probability based on complexity
            let probability = (complexity - 0.6) * 2.5  // 0.0 to 1.0 as complexity goes from 0.6 to 1.0
            
            return { pos in
                let primary = primaryPulse(pos)
                let secondary = secondaryPulse(pos)
                
                // Probabilistic inclusion of secondary pulse
                let useProbability = self.opFactory.randomFloatInRange(0.0...1.0)
                let useSecondary = useProbability < probability
                
                // Always include primary, sometimes include secondary
                return primary > 0.5 || (useSecondary && secondary > 0.5) ? 1.0 : 0.0
            }
        }
    }
    
    /// Generate a swing rhythm with uneven subdivisions
    private func generateSwingRhythm(density: Float, complexity: Float) -> Crvs.FloatOp {
        // Base pulse count similar to straight rhythm
        let pulsesPerCycle = 1 + Int(density * 7) * 2  // Ensure even number for swing
        
        // Calculate swing amount (0.5 = even, higher = more swing)
        let swingAmount = 0.55 + (complexity * 0.25)
        
        // Create swing feel by phase distortion
        let swingDistortion = ops.bias(
            ops.mult(
                ops.sine(ops.c(0.0)),
                complexity * 0.15
            ),
            ops.phasor()
        )
        
        // Base pulse with swing applied
        let swingPulse = ops.pulse(
            swingDistortion,
            0.3
        )
        
        // Apply division to create rhythm
        return ops.pulse(
            ops.mult(
                swingDistortion,
                Float(pulsesPerCycle)
            ),
            0.3
        )
    }
    
    /// Generate a broken rhythm with irregular groupings
    private func generateBrokenRhythm(density: Float, complexity: Float) -> Crvs.FloatOp {
        // Create irregular divisions
        let basePulses = 2 + Int(density * 6)
        let irregularDivider = 3 + Int(complexity * 4)
        
        // Combine different divisions to create broken feel
        let rhythm1 = ops.pulse(
            ops.mult(
                ops.phasor(),
                Float(basePulses)
            ),
            0.3
        )
        
        let rhythm2 = ops.pulse(
            ops.mult(
                ops.phasor(),
                Float(irregularDivider)
            ),
            0.3
        )
        
        // Mix rhythms with varying weights
        let weight1 = 0.6 + (complexity * 0.3)
        let weight2 = 1.0 - weight1
        
        return { pos in
            let value1 = rhythm1(pos)
            let value2 = rhythm2(pos)
            
            // Combination of rhythms with weights
            return (value1 * weight1 + value2 * weight2) > 0.5 ? 1.0 : 0.0
        }
    }
    
    /// Generate a syncopated rhythm that emphasizes offbeats
    private func generateSyncopatedRhythm(density: Float, complexity: Float) -> Crvs.FloatOp {
        // Base division
        let baseDivision = 4 + Int(density * 4)
        
        // Create base pulse on downbeats
        let basePulse = ops.pulse(
            ops.mult(
                ops.phasor(),
                Float(baseDivision)
            ),
            0.3
        )
        
        // Create offbeat pulse (syncopation)
        let offbeatPulse = ops.pulse(
            ops.phase(
                ops.mult(
                    ops.phasor(),
                    Float(baseDivision)
                ),
                0.5 / Float(baseDivision)
            ),
            0.3
        )
        
        // Mix downbeats and offbeats based on complexity
        let downbeatProbability = max(0.1, 1.0 - complexity)
        let offbeatProbability = complexity
        
        return { [self] pos in
            let onDownbeat = basePulse(pos) > 0.5
            let onOffbeat = offbeatPulse(pos) > 0.5
            
            let useDownbeat = onDownbeat && opFactory.randomFloatInRange(0.0...1.0) < downbeatProbability
            let useOffbeat = onOffbeat && opFactory.randomFloatInRange(0.0...1.0) < offbeatProbability
            
            return useDownbeat || useOffbeat ? 1.0 : 0.0
        }
    }
    
    /// Generate Euclidean rhythm (evenly distributed pulses)
    private func generateEuclideanRhythm(density: Float, complexity: Float) -> Crvs.FloatOp {
        // Calculate Euclidean parameters
        let steps = 8 + Int(complexity * 8)  // 8 to 16 steps
        let pulses = 1 + Int(density * Float(steps - 1))  // 1 to steps pulses
        
        // Calculate Euclidean pattern
        var pattern = [Float](repeating: 0, count: steps)
        
        // Implement Bjorklund's algorithm
        if pulses > 0 && pulses <= steps {
            // Calculate distribution
            let bucket = steps / pulses
            let remainder = steps % pulses
            
            var index = 0
            for i in 0..<pulses {
                pattern[index] = 1.0
                index += bucket
                
                // Distribute the remainder evenly
                if i < remainder {
                    index += 1
                }
                
                if index >= steps {
                    index = index % steps
                }
            }
        }
        
        // Add rotation/phase offset based on complexity
        let rotationSteps = Int(complexity * Float(steps) * 0.5)
        if rotationSteps > 0 {
            let firstPart = Array(pattern[0..<rotationSteps])
            let secondPart = Array(pattern[rotationSteps..<steps])
            pattern = secondPart + firstPart
        }
        
        // Create function to sample the pattern
        return { pos in
            let index = Int(pos * Float(steps)) % steps
            return pattern[index]
        }
    }
    
    // MARK: - Helper Methods
    
    /// Add humanization to a rhythm
    private func humanizeRhythm(_ rhythm: @escaping Crvs.FloatOp, amount: Float) -> Crvs.FloatOp {
        // Create subtle timing variation
        return { pos in
            // Add small timing jitter
            let jitter = self.opFactory.randomFloatInRange(-amount...amount) * 0.05
            let adjustedPos = fmod(pos + jitter, 1.0)
            
            // Apply base rhythm at adjusted position
            return rhythm(adjustedPos)
        }
    }
    
    /// Create a rhythm with accent pattern
    public func createAccentedRhythm(baseRhythm: @escaping Crvs.FloatOp, accentPattern: [Float]) -> Crvs.FloatOp {
        guard !accentPattern.isEmpty else { return baseRhythm }
        
        return { pos in
            let value = baseRhythm(pos)
            
            // Apply accent only to active steps
            if value > 0.5 {
                // Determine current position in accent pattern
                let patternPos = pos * Float(accentPattern.count)
                let patternIndex = Int(patternPos) % accentPattern.count
                
                // Return accented value (1.0 for full accent, lower for less accent)
                return 0.5 + (accentPattern[patternIndex] * 0.5)
            }
            
            return value
        }
    }
}

// MARK: - Musical Pattern Factory

/// Factory for generating musical patterns beyond just rhythms
class PatternFactory {
    private let opFactory: OpFactory
    private let rhythmFactory: RhythmFactory
    private let ops = Crvs.Ops()
    
    /// Initialize with optional seed for reproducibility
    init(seed: UInt64? = nil) {
        self.opFactory = OpFactory(seed: seed)
        self.rhythmFactory = RhythmFactory(seed: seed)
    }
    
    // MARK: - Melodic Pattern Generation
    
    /// Generate a melodic pattern based on musical parameters
    /// - Parameters:
    ///   - scale: Scale degrees to use (e.g., [0, 2, 4, 5, 7, 9, 11] for major)
    ///   - range: Range in scale degrees (e.g., 7 for one octave)
    ///   - complexity: Pattern complexity (0-1)
    /// - Returns: A function that generates scale degree values
    public func generateMelodicPattern(scale: [Int], range: Int, complexity: Float) -> Crvs.FloatOp {
        // Create base contour function
        let contourOp = generateMelodicContour(complexity: complexity)
        
        // Map continuous contour to discrete scale values
        return { pos in
            // Get continuous value from contour
            let rawValue = contourOp(pos)
            
            // Map to scale range
            let scalePos = rawValue * Float(range)
            let scaleDegree = Int(scalePos) % scale.count
            
            // Convert to normalized scale degree
            return Float(scale[scaleDegree]) / 12.0
        }
    }
    
    /// Generate a melodic contour with varying complexity
    private func generateMelodicContour(complexity: Float) -> Crvs.FloatOp {
        // For low complexity, use simple wave shapes
        if complexity < 0.3 {
            return opFactory.generateOscillator(type: "triangle")
        }
        
        // For medium complexity, use combination of waves
        if complexity < 0.6 {
            let primaryWave = opFactory.generateOscillator(
                type: opFactory.randomChoice(["sine", "triangle"]) ?? "sine"
            )
            
            let secondaryWave = opFactory.generateOscillator(
                type: "sine",
                parameters: ["frequency": 0.5]
            )
            
            return ops.morph(
                primaryWave,
                secondaryWave,
                ops.c(complexity)
            )
        }
        
        // For high complexity, use more advanced generation
        return opFactory.generateOp(complexity: complexity)
    }
    
    // MARK: - Modulation Pattern Generation
    
    /// Generate a modulation pattern for controlling parameters over time
    /// - Parameters:
    ///   - rate: Speed of modulation (0-1, slow to fast)
    ///   - depth: Depth of modulation (0-1, subtle to extreme)
    ///   - type: Type of modulation ("smooth", "stepped", "random")
    /// - Returns: A modulation function that outputs values in the 0-1 range
    public func generateModulationPattern(rate: Float, depth: Float, type: String) -> Crvs.FloatOp {
        let rateValue = 0.1 + (rate * 2.9)  // 0.1 to 3.0
        let depthValue = depth
        
        // Generate base waveform based on type
        var baseOp: Crvs.FloatOp
        
        switch type.lowercased() {
        case "smooth":
            baseOp = ops.sine(ops.c(0.0))
        case "stepped":
            baseOp = ops.pulse(
                ops.mult(ops.phasor(), 4 + Float(Int(rate * 8))),
                0.5
            )
        case "random":
            baseOp = ops.perlin(
                ops.phasor(),
                ops.c(0.5),
                nil,
                ops.c(0.5),
                ops.c(1.0 + rate * 3.0)
            )
        default:
            baseOp = ops.sine(ops.c(0.0))
        }
        
        // Apply rate
        baseOp = ops.rate(baseOp, rateValue)
        
        // Apply depth and center around 0.5
        baseOp = ops.bias(
            ops.mult(baseOp, depthValue),
            0.5 - (depthValue * 0.5)
        )
        
        return baseOp
    }
    
    // MARK: - Complete Musical Phrase Generation
    
    /// Generate a complete musical phrase with rhythm, pitch, and dynamics
    /// - Parameters:
    ///   - length: Length in musical bars
    ///   - complexity: Overall complexity (0-1)
    ///   - style: Musical style ("minimal", "evolving", "chaotic")
    /// - Returns: A tuple of (rhythm, pitch, dynamics) functions
    public func generateMusicalPhrase(length: Float, complexity: Float, style: String) -> (
        rhythm: Crvs.FloatOp,
        pitch: Crvs.FloatOp,
        dynamics: Crvs.FloatOp
    ) {
        // Generate rhythm based on style
        let rhythm: Crvs.FloatOp
        switch style.lowercased() {
        case "minimal":
            rhythm = rhythmFactory.generate(
                density: 0.3 + (complexity * 0.3),
                complexity: complexity * 0.6,
                style: "straight"
            )
        case "evolving":
            rhythm = rhythmFactory.generate(
                density: 0.4 + (complexity * 0.4),
                complexity: complexity,
                style: "euclidean"
            )
        case "chaotic":
            rhythm = rhythmFactory.generate(
                density: 0.5 + (complexity * 0.5),
                complexity: complexity,
                style: "broken"
            )
        default:
            rhythm = rhythmFactory.generate(
                density: 0.4,
                complexity: complexity,
                style: "straight"
            )
        }
        
        // Generate pitch pattern (using a scale)
        let majorScale = [0, 2, 4, 5, 7, 9, 11]
        let pitch = generateMelodicPattern(
            scale: majorScale,
            range: 7 + Int(complexity * 7),
            complexity: complexity
        )
        
        // Generate dynamics pattern
        let dynamics = generateModulationPattern(
            rate: 0.3 + (complexity * 0.4),
            depth: 0.3 + (complexity * 0.4),
            type: style == "minimal" ? "smooth" : (style == "chaotic" ? "random" : "stepped")
        )
        
        return (rhythm: rhythm, pitch: pitch, dynamics: dynamics)
    }
}

// MARK: - Example Usage of Factories

class FactoryUsageExample {
    // Create factories with optional seed for reproducibility
    let opFactory = OpFactory(seed: 12345)
    let rhythmFactory = RhythmFactory(seed: 12345)
    let patternFactory = PatternFactory(seed: 12345)
    
    func demonstrateOpFactory() {
        // Generate a novel operation with medium complexity
        let novelOp = opFactory.generateOp(complexity: 0.5)
        
        // Generate a specific type of oscillator with some parameters
        let customSine = opFactory.generateOscillator(
            type: "sine",
            parameters: ["feedback": 0.2]
        )
        
        // Apply modulation to an operation
        let modulatedOp = opFactory.generateModulatedOp(
            baseOp: customSine,
            modulationType: "amplitude",
            amount: 0.3
        )
        
        // Sample the operations
        for i in 0..<10 {
            let pos = Float(i) / 10.0
            print("Position \(pos):")
            print("  Novel Op: \(novelOp(pos))")
            print("  Custom Sine: \(customSine(pos))")
            print("  Modulated Op: \(modulatedOp(pos))")
        }
    }
    
    func demonstrateRhythmFactory() {
        // Generate different styles of rhythms
        let straightRhythm = rhythmFactory.generate(
            density: 0.4,
            complexity: 0.3,
            style: "straight"
        )
        
        let swingRhythm = rhythmFactory.generate(
            density: 0.4,
            complexity: 0.5,
            style: "swing"
        )
        
        let euclideanRhythm = rhythmFactory.generate(
            density: 0.5,
            complexity: 0.7,
            style: "euclidean"
        )
        
        // Generate a novel rhythm with specific character
        let novelRhythm = rhythmFactory.generateNovel(
            character: ["dense", "complex", "syncopated"],
            parameters: ["complexity": 0.8]
        )
        
        // Generate variations on a theme
        let variations = rhythmFactory.generateVariations(
            baseCharacter: ["sparse", "simple"],
            variationCount: 3,
            variationAmount: 0.5
        )
        
        // Generate pattern samples
        func printPattern(name: String, pattern: Crvs.FloatOp) {
            var patternStr = "\(name): "
            for i in 0..<16 {
                let pos = Float(i) / 16.0
                let value = pattern(pos)
                patternStr += value > 0.5 ? "X" : "."
            }
            print(patternStr)
        }
        
        printPattern(name: "Straight", pattern: straightRhythm)
        printPattern(name: "Swing", pattern: swingRhythm)
        printPattern(name: "Euclidean", pattern: euclideanRhythm)
        printPattern(name: "Novel", pattern: novelRhythm)
        
        for (i, variation) in variations.enumerated() {
            printPattern(name: "Var \(i+1)", pattern: variation)
        }
    }
    
    func demonstratePatternFactory() {
        // Generate a melodic pattern
        let majorScale = [0, 2, 4, 5, 7, 9, 11]
        let melody = patternFactory.generateMelodicPattern(
            scale: majorScale,
            range: 14,  // Two octaves
            complexity: 0.6
        )
        
        // Generate a modulation pattern
        let modulation = patternFactory.generateModulationPattern(
            rate: 0.3,
            depth: 0.7,
            type: "smooth"
        )
        
        // Generate a complete musical phrase
        let phrase = patternFactory.generateMusicalPhrase(
            length: 2.0,  // 2 bars
            complexity: 0.5,
            style: "evolving"
        )
        
        // Sample the patterns
        print("\nMelodic Pattern:")
        for i in 0..<16 {
            let pos = Float(i) / 16.0
            let midiNote = Int(melody(pos) * 12) + 60  // Middle C as base
            print("  Step \(i): MIDI note \(midiNote)")
        }
        
        print("\nComplete Musical Phrase:")
        for i in 0..<16 {
            let pos = Float(i) / 16.0
            let trigger = phrase.rhythm(pos) > 0.5
            let midiNote = Int(phrase.pitch(pos) * 12) + 60
            let velocity = Int(phrase.dynamics(pos) * 127)
            
            if trigger {
                print("  Step \(i): Note \(midiNote), Velocity \(velocity)")
            } else {
                print("  Step \(i): Rest")
            }
        }
    }
}

// MARK: - Swift DSL Integration

/// Protocol for any generative component
protocol GenerativeElement {
    func generate(seed: UInt64?) -> Crvs.FloatOp
}

/// Result builder for generative composition
@resultBuilder
struct GenerativeCompositionBuilder {
    static func buildBlock(_ components: GenerativeElement...) -> [GenerativeElement] {
        return components
    }
    
    static func buildOptional(_ component: [GenerativeElement]?) -> [GenerativeElement] {
        return component ?? []
    }
    
    static func buildEither(first component: [GenerativeElement]) -> [GenerativeElement] {
        return component
    }
    
    static func buildEither(second component: [GenerativeElement]) -> [GenerativeElement] {
        return component
    }
    
    static func buildArray(_ components: [[GenerativeElement]]) -> [GenerativeElement] {
        return components.flatMap { $0 }
    }
}

/// Generative rhythm element
struct GenerativeRhythm: GenerativeElement {
    let character: [String]
    let parameters: [String: Float]
    
    init(_ character: String..., parameters: [String: Float] = [:]) {
        self.character = character
        self.parameters = parameters
    }
    
    func generate(seed: UInt64?) -> Crvs.FloatOp {
        let factory = RhythmFactory(seed: seed)
        return factory.generateNovel(character: character, parameters: parameters)
    }
}

/// Generative modulation element
struct GenerativeModulation: GenerativeElement {
    let rate: Float
    let depth: Float
    let type: String
    
    init(rate: Float, depth: Float, type: String = "smooth") {
        self.rate = rate
        self.depth = depth
        self.type = type
    }
    
    func generate(seed: UInt64?) -> Crvs.FloatOp {
        let factory = PatternFactory(seed: seed)
        return factory.generateModulationPattern(rate: rate, depth: depth, type: type)
    }
}

/// Generative melody element
struct GenerativeMelody: GenerativeElement {
    let scale: [Int]
    let range: Int
    let complexity: Float
    
    init(scale: [Int], range: Int, complexity: Float) {
        self.scale = scale
        self.range = range
        self.complexity = complexity
    }
    
    func generate(seed: UInt64?) -> Crvs.FloatOp {
        let factory = PatternFactory(seed: seed)
        return factory.generateMelodicPattern(scale: scale, range: range, complexity: complexity)
    }
}

/// Composition generator that combines generative elements
class CompositionGenerator {
    private let seed: UInt64?
    private let elements: [GenerativeElement]
    
    init(seed: UInt64? = nil, @GenerativeCompositionBuilder elements: () -> [GenerativeElement]) {
        self.seed = seed
        self.elements = elements()
    }
    
    func generate() -> [Crvs.FloatOp] {
        return elements.map { $0.generate(seed: seed) }
    }
}

// MARK: - DSL Example

func demonstrateDSL() {
    // Create a composition using the DSL
    let composition = CompositionGenerator(seed: 12345) {
        // Rhythm pattern
        GenerativeRhythm("dense", "complex", "swing",
                         parameters: ["density": 0.7])
        
        // Melodic pattern
        GenerativeMelody(
            scale: [0, 2, 4, 5, 7, 9, 11],  // Major scale
            range: 14,  // Two octaves
            complexity: 0.6
        )
        
        // Modulation patterns
        GenerativeModulation(rate: 0.3, depth: 0.7, type: "smooth")
        
        // Conditional elements
        if Bool.random() {
            GenerativeRhythm("sparse", "euclidean")
        }
        
        // Loop to create multiple elements
        for i in 0..<3 {
            GenerativeModulation(
                rate: Float(i) * 0.2,
                depth: 0.5,
                type: "stepped"
            )
        }
    }
    
    // Generate the composition
    let generatedPatterns = composition.generate()
    
    print("Generated \(generatedPatterns.count) patterns")
}
