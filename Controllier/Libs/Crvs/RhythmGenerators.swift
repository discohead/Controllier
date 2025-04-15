import Foundation

// MARK: - Core Rhythm Generation Concepts

/// Rhythm Pattern Generator using Crvs
class RhythmPatternGenerator {
    private let ops = Crvs.Ops()
    
    // MARK: - Threshold-Based Pattern Generation
    
    /// Generate a rhythm pattern using a threshold-based approach
    /// - Parameters:
    ///   - waveform: The waveform operation to sample
    ///   - threshold: The trigger threshold (0-1)
    ///   - stepCount: Number of steps in the pattern
    /// - Returns: Array of trigger values (0 or 1) representing the rhythm
    func generateThresholdPattern(waveform: @escaping Crvs.FloatOp, threshold: Float, stepCount: Int) -> [Float] {
        var pattern = [Float](repeating: 0, count: stepCount)
        
        for i in 0..<stepCount {
            let position = Float(i) / Float(stepCount)
            let value = waveform(position)
            pattern[i] = value > threshold ? 1.0 : 0.0
        }
        
        return pattern
    }
    
    // MARK: - Euclidean Rhythm Generation
    
    /// Generate a Euclidean rhythm pattern (evenly distributed beats)
    /// - Parameters:
    ///   - pulses: Number of active beats
    ///   - steps: Total steps in pattern
    ///   - rotation: Pattern rotation amount
    /// - Returns: Array of trigger values representing the rhythm
    func generateEuclideanRhythm(pulses: Int, steps: Int, rotation: Int = 0) -> [Float] {
        guard steps > 0 else { return [] }
        guard pulses <= steps else { return [Float](repeating: 1.0, count: steps) }
        
        // Algorithm for Euclidean rhythm distribution
        // Based on Bjorklund's algorithm for efficient distribution
        var pattern = [Float](repeating: 0, count: steps)
        if pulses > 0 {
            let buckets = calculateBuckets(pulses: pulses, steps: steps)
            
            var index = 0
            for bucket in buckets {
                for _ in 0..<bucket {
                    pattern[index] = 1.0
                    index += 1
                }
                
                if index < steps {
                    pattern[index] = 0.0
                    index += 1
                }
            }
        }
        
        // Apply rotation
        if rotation != 0 {
            let normalizedRotation = ((rotation % steps) + steps) % steps
            if normalizedRotation > 0 {
                let firstPart = Array(pattern[0..<normalizedRotation])
                let secondPart = Array(pattern[normalizedRotation..<steps])
                pattern = secondPart + firstPart
            }
        }
        
        return pattern
    }
    
    /// Helper function for Euclidean rhythm calculation
    private func calculateBuckets(pulses: Int, steps: Int) -> [Int] {
        let divisor = steps - pulses
        var buckets = [Int](repeating: 1, count: pulses)
        
        if divisor > 0 {
            var remainder = divisor
            var index = 0
            
            while remainder > 0 {
                buckets[index % pulses] += 1
                remainder -= 1
                index += 1
            }
        }
        
        return buckets
    }
    
    // MARK: - Waveform-Based Rhythm Generators
    
    /// Create a rhythm generator based on standard waveforms
    /// - Parameters:
    ///   - type: Waveform type (sine, square, etc.)
    ///   - pulseWidth: Width for pulse/square waves (0-1)
    ///   - frequency: Number of cycles in the pattern (1 = one complete cycle)
    ///   - phaseOffset: Phase offset (0-1)
    /// - Returns: A function that generates rhythm values for a given position
    func createRhythmGenerator(type: String, pulseWidth: Float = 0.5, 
                             frequency: Float = 1.0, phaseOffset: Float = 0.0) -> Crvs.FloatOp {
        
        let baseWaveform: Crvs.FloatOp
        
        switch type.lowercased() {
        case "sine":
            baseWaveform = ops.sine()
        case "square", "pulse":
            baseWaveform = ops.pulse(pulseWidth)
        case "triangle":
            baseWaveform = ops.tri()
        case "saw":
            baseWaveform = ops.saw()
        default:
            baseWaveform = ops.pulse(pulseWidth)
        }
        
        // Apply frequency and phase
        let scaledWaveform = ops.phase(
            ops.rate(baseWaveform, frequency),
            phaseOffset
        )
        
        return scaledWaveform
    }
    
    /// Create a boolean trigger function from a continuous waveform
    /// - Parameters:
    ///   - waveform: The source waveform operation
    ///   - threshold: Trigger threshold (0-1)
    /// - Returns: A function that outputs 1 when the waveform exceeds the threshold, 0 otherwise
    func createTriggerFunction(waveform: @escaping Crvs.FloatOp, threshold: Float = 0.5) -> Crvs.FloatOp {
        return { pos in
            let value = waveform(pos)
            return value > threshold ? 1.0 : 0.0
        }
    }
    
    // MARK: - Polyrhythm Generation
    
    /// Generate polyrhythm by combining multiple rhythm generators
    /// - Parameters:
    ///   - rhythms: Array of rhythm generating functions
    ///   - weights: Optional weights for mixing (normalized if provided)
    /// - Returns: A function that combines the rhythms
    func createPolyrhythm(rhythms: [Crvs.FloatOp], weights: [Float]? = nil) -> Crvs.FloatOp {
        guard !rhythms.isEmpty else { return { _ in 0.0 } }
        
        // If only one rhythm, return it directly
        if rhythms.count == 1 {
            return rhythms[0]
        }
        
        // Normalize weights if provided
        let normalizedWeights: [Float]
        if let weights = weights, weights.count == rhythms.count {
            let sum = weights.reduce(0, +)
            normalizedWeights = sum > 0 ? weights.map { $0 / sum } : [Float](repeating: 1.0/Float(rhythms.count), count: rhythms.count)
        } else {
            normalizedWeights = [Float](repeating: 1.0/Float(rhythms.count), count: rhythms.count)
        }
        
        // Mix rhythms with weights
        return { pos in
            var result: Float = 0.0
            for i in 0..<rhythms.count {
                result += rhythms[i](pos) * normalizedWeights[i]
            }
            return result
        }
    }
    
    // MARK: - Advanced Rhythm Modulation
    
    /// Modulate a rhythm pattern over time
    /// - Parameters:
    ///   - baseRhythm: The base rhythm function
    ///   - modulationOp: Modulation function (0-1 range)
    ///   - modulationDepth: Depth of modulation effect (0-1)
    /// - Returns: A time-varying rhythm function
    func modulateRhythm(baseRhythm: @escaping Crvs.FloatOp, 
                       modulationOp: @escaping Crvs.FloatOp,
                       modulationDepth: Float = 0.5) -> Crvs.FloatOp {
        
        return { pos in
            // Calculate modulated position
            let modulation = modulationOp(pos) * modulationDepth
            let modPos = fmod(pos + modulation, 1.0)
            
            // Apply base rhythm at modulated position
            return baseRhythm(modPos)
        }
    }
    
    /// Generate a probability-based rhythm
    /// - Parameters:
    ///   - probabilityFunc: Function that returns trigger probability (0-1) for a position
    ///   - steps: Number of discrete steps in pattern
    /// - Returns: Array of trigger values based on probabilities
    func generateProbabilisticRhythm(probabilityFunc: Crvs.FloatOp, steps: Int) -> [Float] {
        var pattern = [Float](repeating: 0, count: steps)
        
        for i in 0..<steps {
            let position = Float(i) / Float(steps)
            let probability = probabilityFunc(position)
            
            // Trigger based on probability
            pattern[i] = Float.random(in: 0..<1) < probability ? 1.0 : 0.0
        }
        
        return pattern
    }
    
    // MARK: - DSL for Rhythm Patterns
    
    /// Create a rhythm pattern using the DSL
    /// - Parameter builder: The rhythm pattern builder function
    /// - Returns: A rhythm generation function
    func rhythm(@RhythmBuilder _ builder: @escaping () -> Crvs.FloatOp) -> Crvs.FloatOp {
        return builder()
    }
}

// MARK: - Rhythm Builder DSL

/// Result builder for creating rhythm patterns
@resultBuilder
public struct RhythmBuilder {
    public static func buildBlock(_ component: @escaping Crvs.FloatOp) -> Crvs.FloatOp {
        return component
    }
    
    public static func buildBlock(_ components: Crvs.FloatOp...) -> Crvs.FloatOp {
        // Chain rhythm processors
        return { pos in
            var value = pos
            for component in components {
                value = component(value)
            }
            return value
        }
    }
    
    public static func buildOptional(_ component: Crvs.FloatOp?) -> Crvs.FloatOp {
        return component ?? { pos in pos }
    }
    
    public static func buildEither(first component: @escaping Crvs.FloatOp) -> Crvs.FloatOp {
        return component
    }
    
    public static func buildEither(second component: @escaping Crvs.FloatOp) -> Crvs.FloatOp {
        return component
    }
}

// MARK: - Rhythm Pattern Nodes

/// Basic pulse/clock divider
public struct PulseDivider: WaveformNode {
    let divisions: Int
    let pulseWidth: Float
    
    public init(divisions: Int = 4, pulseWidth: Float = 0.5) {
        self.divisions = max(1, divisions)
        self.pulseWidth = min(max(0.1, pulseWidth), 0.9)
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.pulse(
            ops.mult(
                ops.phasor(),
                Float(divisions)
            ),
            pulseWidth
        )
    }
}

/// Euclidean rhythm generator
public struct EuclideanRhythm: WaveformNode {
    let pulses: Int
    let steps: Int
    let rotation: Int
    
    public init(pulses: Int, steps: Int, rotation: Int = 0) {
        self.pulses = max(0, pulses)
        self.steps = max(1, steps)
        self.rotation = rotation
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let rhythmGen = RhythmPatternGenerator()
        let pattern = rhythmGen.generateEuclideanRhythm(
            pulses: pulses, 
            steps: steps, 
            rotation: rotation
        )
        
        return { pos in
            let stepIndex = Int(pos * Float(pattern.count)) % pattern.count
            return pattern[stepIndex]
        }
    }
}

/// Probability-based rhythm generator
public struct ProbabilisticTriggers: WaveformNode {
    let probability: Float
    let seed: Int
    
    public init(probability: Float, seed: Int = 0) {
        self.probability = min(max(0, probability), 1)
        self.seed = seed
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        // Use perlin noise for deterministic randomness based on seed
        let noiseOp = ops.perlin(
            ops.phasor(),
            ops.c(Float(seed) * 0.1),
            nil,
            ops.c(0.5),
            ops.c(2)
        )
        
        // Convert noise to binary triggers based on probability
        return { pos in
            let noiseValue = noiseOp(pos)
            return noiseValue < probability ? 1.0 : 0.0
        }
    }
}

/// Polyrhythm generator combining multiple rhythms
public struct Polyrhythm: WaveformNode {
    let rhythms: [WaveformNode]
    let mixMode: MixMode
    
    public enum MixMode {
        case sum            // Add values (can exceed 1.0)
        case average        // Average of all active rhythms
        case maximum        // Take maximum value (logical OR)
        case product        // Multiply values (logical AND)
    }
    
    public init(_ rhythms: [WaveformNode], mixMode: MixMode = .maximum) {
        self.rhythms = rhythms
        self.mixMode = mixMode
    }
    
    public init(rhythms: WaveformNode..., mixMode: MixMode = .maximum) {
        self.rhythms = rhythms
        self.mixMode = mixMode
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        let rhythmOps = rhythms.map { $0.createOperation() }
        
        switch mixMode {
        case .sum:
            return ops.sum(rhythmOps)
        case .average:
            return ops.mean(rhythmOps)
        case .maximum:
            return ops.max(rhythmOps)
        case .product:
            return ops.product(rhythmOps)
        }
    }
}

// MARK: Rhythm Space Generator

/// Advanced rhythm generation using 3D wavetables
class RhythmSpaceGenerator {
    private let ops = Crvs.Ops()
    
    // MARK: - 3D Rhythm Space Construction
    
    /// Create a 3D rhythm space wavetable
    /// - Parameters:
    ///   - xDimension: Size of the x dimension (e.g., rhythmic density)
    ///   - yDimension: Size of the y dimension (e.g., syncopation)
    ///   - zDimension: Size of the z dimension (e.g., subdivision type)
    /// - Returns: 3D array of rhythm generating functions
    func createRhythmSpace(xDimension: Int, yDimension: Int, zDimension: Int) -> [[[Crvs.FloatOp]]] {
        // Pre-allocate the 3D array
        var rhythmSpace = [[[Crvs.FloatOp]]](
            repeating: [[Crvs.FloatOp]](
                repeating: [Crvs.FloatOp](
                    repeating: { _ in 0.0 },
                    count: zDimension
                ),
                count: yDimension
            ),
            count: xDimension
        )
        
        // Populate the rhythm space with functions
        for x in 0..<xDimension {
            for y in 0..<yDimension {
                for z in 0..<zDimension {
                    // Generate a unique rhythm function for this coordinate
                    rhythmSpace[x][y][z] = createRhythmFunction(
                        density: Float(x) / Float(xDimension - 1),
                        syncopation: Float(y) / Float(yDimension - 1),
                        subdivision: Float(z) / Float(zDimension - 1)
                    )
                }
            }
        }
        
        return rhythmSpace
    }
    
    /// Create a rhythm function based on musical parameters
    /// - Parameters:
    ///   - density: Rhythmic density (0-1, from sparse to dense)
    ///   - syncopation: Amount of syncopation (0-1, from regular to syncopated)
    ///   - subdivision: Type of subdivision (0-1, from duple to triple)
    /// - Returns: A function generating rhythm values
    private func createRhythmFunction(density: Float, syncopation: Float, subdivision: Float) -> Crvs.FloatOp {
        // Calculate actual parameters from normalized inputs
        let pulseCount = Int(density * 12) + 1  // 1 to 13 pulses
        let stepCount = 16                      // Fixed step count for consistency
        
        // Calculate subdivision factor (from 2 to 3, allowing for duple to triple feel)
        let subFactor = 2.0 + subdivision
        
        // Create the base rhythm (Euclidean distribution)
        let euclideanRhythm = createEuclideanRhythm(pulses: pulseCount, steps: stepCount)
        
        // Apply syncopation by shifting some beats off the grid
        let syncopatedRhythm = applySyncopation(rhythm: euclideanRhythm, amount: syncopation)
        
        // Apply subdivision feel
        return applySubdivisionFeel(rhythm: syncopatedRhythm, factor: subFactor)
    }
    
    /// Create an Euclidean rhythm distribution
    private func createEuclideanRhythm(pulses: Int, steps: Int) -> Crvs.FloatOp {
        // Calculate Euclidean pattern
        var pattern = [Float](repeating: 0, count: steps)
        
        if pulses > 0 && pulses <= steps {
            // Calculate distribution using Bjorklund's algorithm
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
        
        // Create function that samples this pattern
        return { pos in
            let index = Int(pos * Float(steps)) % steps
            return pattern[index]
        }
    }
    
    /// Apply syncopation to a rhythm
    private func applySyncopation(rhythm: @escaping Crvs.FloatOp, amount: Float) -> Crvs.FloatOp {
        // Create phase modulation based on syncopation amount
        let phaseModulation = ops.mult(
            ops.sine(ops.c(0.0)),
            amount * 0.125  // Maximum shift of 1/8th note
        )
        
        // Apply phase modulation to the rhythm
        return { pos in
            let modPos = fmod(pos + phaseModulation(pos), 1.0)
            return rhythm(modPos)
        }
    }
    
    /// Apply subdivision feel (duple to triple)
    private func applySubdivisionFeel(rhythm: @escaping Crvs.FloatOp, factor: Float) -> Crvs.FloatOp {
        // Create a tempo distortion based on subdivision factor
        return { pos in
            // Calculate a non-linear time distortion
            let distortion = sin(pos * 2.0 * Float.pi) * (factor - 2.0) * 0.1
            let modPos = fmod(pos + distortion, 1.0)
            
            // Apply to original rhythm
            return rhythm(modPos)
        }
    }
    
    // MARK: - Creating Rhythm Trajectories
    
    /// Create a 3D wavetable navigator through the rhythm space
    /// - Parameters:
    ///   - rhythmSpace: The 3D array of rhythm functions
    ///   - xTrajectory: Function controlling movement along x-axis
    ///   - yTrajectory: Function controlling movement along y-axis
    ///   - zTrajectory: Function controlling movement along z-axis
    /// - Returns: A time-varying rhythm generator
    func navigateRhythmSpace(
        rhythmSpace: [[[Crvs.FloatOp]]],
        xTrajectory: @escaping Crvs.FloatOp,
        yTrajectory: @escaping Crvs.FloatOp,
        zTrajectory: @escaping Crvs.FloatOp
    ) -> (Float) -> Crvs.FloatOp {
        // Return a function that takes a time position and returns a rhythm function
        return { timePos in
            // Calculate the coordinates in the rhythm space
            let x = xTrajectory(timePos)
            let y = yTrajectory(timePos)
            let z = zTrajectory(timePos)
            
            // Convert to indices with bounds checking
            let xIndex = min(max(Int(x * Float(rhythmSpace.count - 1)), 0), rhythmSpace.count - 1)
            let yIndex = min(max(Int(y * Float(rhythmSpace[0].count - 1)), 0), rhythmSpace[0].count - 1)
            let zIndex = min(max(Int(z * Float(rhythmSpace[0][0].count - 1)), 0), rhythmSpace[0][0].count - 1)
            
            // Return the function at these coordinates
            return rhythmSpace[xIndex][yIndex][zIndex]
        }
    }
    
    /// Create a circular trajectory through a plane in the rhythm space
    /// - Parameters:
    ///   - axis: Which axis the circle is perpendicular to (0=x, 1=y, 2=z)
    ///   - axisValue: The fixed value along the perpendicular axis
    ///   - radius: Radius of the circular path (0-0.5)
    ///   - speed: Angular speed of rotation
    /// - Returns: A triple of (x,y,z) trajectories
    func createCircularTrajectory(
        axis: Int,
        axisValue: Float,
        radius: Float,
        speed: Float
    ) -> (x: Crvs.FloatOp, y: Crvs.FloatOp, z: Crvs.FloatOp) {
        
        // Create time-based angle
        let angle = ops.mult(
            ops.phasor(),
            speed
        )
        
        // Create circular motion
        let circleX = ops.bias(
            ops.mult(
                ops.cos(angle),
                radius
            ),
            0.5
        )
        
        let circleY = ops.bias(
            ops.mult(
                ops.sine(angle),
                radius
            ),
            0.5
        )
        
        // Assign trajectories based on specified axis
        switch axis {
        case 0: // Circle in YZ plane, X fixed
            return (
                x: ops.c(axisValue),
                y: circleX,
                z: circleY
            )
        case 1: // Circle in XZ plane, Y fixed
            return (
                x: circleX,
                y: ops.c(axisValue),
                z: circleY
            )
        case 2: // Circle in XY plane, Z fixed
            return (
                x: circleX,
                y: circleY,
                z: ops.c(axisValue)
            )
        default:
            return (
                x: ops.c(0.5),
                y: ops.c(0.5),
                z: ops.c(0.5)
            )
        }
    }
    
    /// Create a Lissajous trajectory through the rhythm space
    /// - Parameters:
    ///   - xFreq: Frequency for x-axis oscillation
    ///   - yFreq: Frequency for y-axis oscillation
    ///   - zFreq: Frequency for z-axis oscillation
    ///   - xPhase: Phase offset for x-axis
    ///   - yPhase: Phase offset for y-axis
    ///   - zPhase: Phase offset for z-axis
    /// - Returns: A triple of (x,y,z) trajectories
    func createLissajousTrajectory(
        xFreq: Float, yFreq: Float, zFreq: Float,
        xPhase: Float = 0.0, yPhase: Float = 0.0, zPhase: Float = 0.0
    ) -> (x: Crvs.FloatOp, y: Crvs.FloatOp, z: Crvs.FloatOp) {
        
        // Create base oscillator
        let timePhasor = ops.timePhasor(cycleDurationSeconds: 32.0)
        
        // Create axes oscillators with different frequencies
        let xOsc = ops.bias(
            ops.mult(
                ops.cos(
                    ops.bias(
                        ops.mult(timePhasor, xFreq),
                        xPhase
                    )
                ),
                0.4
            ),
            0.5
        )
        
        let yOsc = ops.bias(
            ops.mult(
                ops.sine(
                    ops.bias(
                        ops.mult(timePhasor, yFreq),
                        yPhase
                    )
                ),
                0.4
            ),
            0.5
        )
        
        let zOsc = ops.bias(
            ops.mult(
                ops.sine(
                    ops.bias(
                        ops.mult(timePhasor, zFreq),
                        zPhase
                    )
                ),
                0.4
            ),
            0.5
        )
        
        return (x: xOsc, y: yOsc, z: zOsc)
    }
    
    /// Create a trajectory that visits specific points in rhythm space
    /// - Parameters:
    ///   - points: Array of (x,y,z) coordinates to visit
    ///   - transitionTime: Time spent transitioning between points (0-1)
    /// - Returns: A triple of (x,y,z) trajectories
    func createPointSequenceTrajectory(
        points: [(x: Float, y: Float, z: Float)],
        transitionTime: Float
    ) -> (x: Crvs.FloatOp, y: Crvs.FloatOp, z: Crvs.FloatOp) {
        
        guard !points.isEmpty else {
            return (
                x: ops.c(0.5),
                y: ops.c(0.5),
                z: ops.c(0.5)
            )
        }
        
        // Create time-based position
        // TODO: figure out how this timePhasor was intended to be used
        // let timePhasor = ops.timePhasor(cycleDurationSeconds: Double(points.count) * 4.0)
        
        // Trajectory interpolation function
        let xTraj: Crvs.FloatOp = { pos in
            let totalPoints = Float(points.count)
            let pointPos = pos * totalPoints
            let currentIndex = Int(pointPos) % points.count
            let nextIndex = (currentIndex + 1) % points.count
            
            let fracPos = pointPos - Float(Int(pointPos))
            
            // Determine if in transition
            if fracPos < transitionTime {
                // Normalize transition progress
                let t = fracPos / transitionTime
                
                // Use easing function for smooth transition
                let eased = (1.0 - cos(t * Float.pi)) * 0.5
                
                // Interpolate between points
                return points[currentIndex].x * (1.0 - eased) + points[nextIndex].x * eased
            } else {
                // Hold at current point
                return points[currentIndex].x
            }
        }
        
        // Similar functions for y and z
        let yTraj: Crvs.FloatOp = { pos in
            let totalPoints = Float(points.count)
            let pointPos = pos * totalPoints
            let currentIndex = Int(pointPos) % points.count
            let nextIndex = (currentIndex + 1) % points.count
            
            let fracPos = pointPos - Float(Int(pointPos))
            
            if fracPos < transitionTime {
                let t = fracPos / transitionTime
                let eased = (1.0 - cos(t * Float.pi)) * 0.5
                return points[currentIndex].y * (1.0 - eased) + points[nextIndex].y * eased
            } else {
                return points[currentIndex].y
            }
        }
        
        let zTraj: Crvs.FloatOp = { pos in
            let totalPoints = Float(points.count)
            let pointPos = pos * totalPoints
            let currentIndex = Int(pointPos) % points.count
            let nextIndex = (currentIndex + 1) % points.count
            
            let fracPos = pointPos - Float(Int(pointPos))
            
            if fracPos < transitionTime {
                let t = fracPos / transitionTime
                let eased = (1.0 - cos(t * Float.pi)) * 0.5
                return points[currentIndex].z * (1.0 - eased) + points[nextIndex].z * eased
            } else {
                return points[currentIndex].z
            }
        }
        
        return (x: xTraj, y: yTraj, z: zTraj)
    }
    
    // MARK: - Rhythmic Complexity Functions
    
    /// Create a multi-dimensional rhythm complexity space
    /// - Parameters:
    ///   - densityLevels: Number of different density levels
    ///   - variationLevels: Number of different variation/syncopation levels
    ///   - textureTypes: Number of different textural approaches
    /// - Returns: A 3D array of rhythm functions
    func createComplexitySpace(
        densityLevels: Int,
        variationLevels: Int,
        textureTypes: Int
    ) -> [[[Crvs.FloatOp]]] {
        
        var complexitySpace = [[[Crvs.FloatOp]]](
            repeating: [[Crvs.FloatOp]](
                repeating: [Crvs.FloatOp](
                    repeating: { _ in 0.0 },
                    count: textureTypes
                ),
                count: variationLevels
            ),
            count: densityLevels
        )
        
        // Populate with increasingly complex rhythm functions
        for x in 0..<densityLevels {
            let density = Float(x) / Float(densityLevels - 1)
            
            for y in 0..<variationLevels {
                let variation = Float(y) / Float(variationLevels - 1)
                
                for z in 0..<textureTypes {
                    let texture = Float(z) / Float(textureTypes - 1)
                    
                    // Create rhythmic function with increasing complexity
                    complexitySpace[x][y][z] = createComplexRhythm(
                        density: density,
                        variation: variation,
                        texture: texture
                    )
                }
            }
        }
        
        return complexitySpace
    }
    
    /// Create a complex rhythm function with specific parameters
    private func createComplexRhythm(
        density: Float,
        variation: Float,
        texture: Float
    ) -> Crvs.FloatOp {
        
        // 1. Calculate rhythmic parameters
        
        // Density affects how many pulses/triggers occur
        let activeSteps = Int(density * 15) + 1  // 1 to 16 active steps
        
        // Variation affects regularity vs. syncopation
        let variationFactor = variation * 0.3   // How much to deviate from regular pattern
        
        // Texture affects the "feel" - from simple pulses to complex patterns
        let textureType = Int(texture * 4)      // 0-4 different texture types
        
        // 2. Create base rhythm using ops.waveform DSL
        let baseRhythm = ops.waveform {
            // Base rhythm using appropriate generators
            switch textureType {
            case 0:
                // Regular pulse pattern
                PulseDivider(divisions: activeSteps, pulseWidth: 0.3)
            case 1:
                // Euclidean rhythm
                EuclideanRhythm(pulses: activeSteps, steps: 16)
            case 2:
                // Polyrhythmic feel
                Polyrhythm(
                    rhythms: EuclideanRhythm(pulses: activeSteps / 2, steps: 16),
                    EuclideanRhythm(pulses: activeSteps / 3 + 1, steps: 16),
                    mixMode: .maximum
                )
            case 3:
                // Complex pattern with probabilistic elements
                Polyrhythm(
                    rhythms: EuclideanRhythm(pulses: activeSteps, steps: 16),
                    ProbabilisticTriggers(probability: density * 0.5),
                    mixMode: .sum
                )
            default:
                // Fallback to simple pulse
                PulseDivider(divisions: activeSteps, pulseWidth: 0.3)
            }
            
            // Apply variation/syncopation if needed
            if variation > 0.05 {
                // Add phase variation/swing
                Phase(
                    Triangle().rate(0.25).multiply(variationFactor)
                )
            }
        }
        
        // Get the function and apply additional processing if needed
        let rhythmFunc = baseRhythm
        
        // Apply additional texture-based processing
        return { [self] pos in
            let value = rhythmFunc(pos)
            
            // Apply additional processing based on texture parameter
            if texture > 0.75 {
                // High texture: Add dynamics/accents
                let accentLFO = ops.sine()(pos * 7.0) * 0.3 + 0.7
                return value * (value > 0.5 ? accentLFO : 0.0)
            } else if texture > 0.5 {
                // Medium-high texture: Add slight duration variation
                let durationMod = ops.tri()(pos * 3.0) * 0.2 + 0.8
                return value * durationMod
            } else {
                // Lower textures: Use value directly
                return value
            }
        }
    }
    
    // MARK: - Musical Application
    
    /// Generate a complete rhythmic pattern from the 3D rhythm space
    /// - Parameters:
    ///   - rhythmSpace: The 3D array of rhythm functions
    ///   - trajectory: Trajectory functions for navigating the space
    ///   - stepCount: Number of steps to generate
    ///   - timePosition: Current position in time (0-1)
    /// - Returns: Array of trigger values representing the pattern
    func generatePattern(
        rhythmSpace: [[[Crvs.FloatOp]]],
        trajectory: (x: Crvs.FloatOp, y: Crvs.FloatOp, z: Crvs.FloatOp),
        stepCount: Int,
        timePosition: Float
    ) -> [Float] {
        
        // Create the rhythm navigator
        let rhythmNavigator = navigateRhythmSpace(
            rhythmSpace: rhythmSpace,
            xTrajectory: trajectory.x,
            yTrajectory: trajectory.y,
            zTrajectory: trajectory.z
        )
        
        // Sample the rhythm at the given time position
        var pattern = [Float](repeating: 0, count: stepCount)
        
        for step in 0..<stepCount {
            // Calculate position for this step
            let stepPosition = Float(step) / Float(stepCount)
            
            // Get the rhythm function for the current position in 3D space
            let rhythmFuncAtTimePosition = rhythmNavigator(timePosition)
            
            // Evaluate the rhythm function at this step position
            pattern[step] = rhythmFuncAtTimePosition(stepPosition) > 0.5 ? 1.0 : 0.0
        }
        
        return pattern
    }
    
    /// Visualize the current position in rhythm space
    /// - Parameters:
    ///   - trajectory: Current trajectory functions
    ///   - timePosition: Current position in time
    /// - Returns: String representation of position and pattern
    func visualizeRhythmSpacePosition(
        trajectory: (x: Crvs.FloatOp, y: Crvs.FloatOp, z: Crvs.FloatOp),
        timePosition: Float
    ) -> String {
        // Get current position in each dimension
        let xPos = trajectory.x(timePosition)
        let yPos = trajectory.y(timePosition)
        let zPos = trajectory.z(timePosition)
        
        var visualization = "Rhythm Space Position:\n"
        visualization += "X (Density): \(String(format: "%.2f", xPos))\n"
        visualization += "Y (Variation): \(String(format: "%.2f", yPos))\n"
        visualization += "Z (Texture): \(String(format: "%.2f", zPos))\n"
        
        return visualization
    }
}

// MARK: - Usage Example

class RhythmSpaceExample {
    let generator = RhythmSpaceGenerator()
    let ops = Crvs.Ops()
    
    func runExample() {
        // 1. Create a 5x5x5 rhythm space (125 unique rhythm functions)
        let rhythmSpace = generator.createRhythmSpace(
            xDimension: 5,  // 5 density levels
            yDimension: 5,  // 5 syncopation levels
            zDimension: 5   // 5 subdivision types
        )
        
        // 2. Create a Lissajous trajectory through the space
        let trajectory = generator.createLissajousTrajectory(
            xFreq: 1.0,    // 1 cycle in x
            yFreq: 1.5,    // 1.5 cycles in y
            zFreq: 2.3,    // 2.3 cycles in z
            xPhase: 0.0,
            yPhase: 0.25,
            zPhase: 0.5
        )
        
        // 3. Visualize the rhythm at different time positions
        let timePositions: [Float] = [0.0, 0.1, 0.3, 0.5, 0.7, 0.9]
        
        for timePos in timePositions {
            // Generate a 16-step pattern at this time position
            let pattern = generator.generatePattern(
                rhythmSpace: rhythmSpace,
                trajectory: trajectory,
                stepCount: 16,
                timePosition: timePos
            )
            
            // Visualize position and pattern
            print("\nTime: \(String(format: "%.2f", timePos))")
            print(generator.visualizeRhythmSpacePosition(
                trajectory: trajectory,
                timePosition: timePos
            ))
            
            // Print pattern
            let patternString = pattern.map { $0 > 0.5 ? "X" : "." }.joined()
            print("Pattern: \(patternString)")
        }
    }
    
    /// Create a complete rhythm ensemble from various trajectories
    func createRhythmEnsemble() -> [String: Crvs.FloatOp] {
        // Create a larger, more complex rhythm space
        let complexSpace = generator.createComplexitySpace(
            densityLevels: 8,
            variationLevels: 8,
            textureTypes: 4
        )
        
        // Create different trajectories for different instruments
        
        // Kick drum: circular trajectory in low density, high stability region
        let kickTrajectory = generator.createCircularTrajectory(
            axis: 1,           // Circle in X-Z plane (fixed variation)
            axisValue: 0.2,    // Low variation
            radius: 0.2,       // Small circle
            speed: 0.25        // Slow movement
        )
        
        // Snare: point sequence visiting specific rhythmic regions
        let snareTrajectory = generator.createPointSequenceTrajectory(
            points: [
                (x: 0.3, y: 0.7, z: 0.2),  // Medium density, high variation, simple texture
                (x: 0.5, y: 0.9, z: 0.3),  // Higher density, very high variation
                (x: 0.2, y: 0.6, z: 0.1),  // Lower density, medium variation
                (x: 0.4, y: 0.8, z: 0.2)   // Medium density, high variation again
            ],
            transitionTime: 0.3
        )
        
        // Hi-hats: lissajous with faster movement, high density regions
        let hihatTrajectory = generator.createLissajousTrajectory(
            xFreq: 3.0,    // Fast x movement
            yFreq: 2.0,    // Medium y movement
            zFreq: 5.0,    // Very fast z movement
            xPhase: 0.5,   // Offset phases
            yPhase: 0.3,
            zPhase: 0.0
        )
        
        // Create the navigation functions
        let kickNavigator = generator.navigateRhythmSpace(
            rhythmSpace: complexSpace,
            xTrajectory: kickTrajectory.x,
            yTrajectory: kickTrajectory.y,
            zTrajectory: kickTrajectory.z
        )
        
        let snareNavigator = generator.navigateRhythmSpace(
            rhythmSpace: complexSpace,
            xTrajectory: snareTrajectory.x,
            yTrajectory: snareTrajectory.y,
            zTrajectory: snareTrajectory.z
        )
        
        let hihatNavigator = generator.navigateRhythmSpace(
            rhythmSpace: complexSpace,
            xTrajectory: hihatTrajectory.x,
            yTrajectory: hihatTrajectory.y,
            zTrajectory: hihatTrajectory.z
        )
        
        // Time position phasor (cycles through the rhythm space)
        let timePhasor = ops.timePhasor(cycleDurationSeconds: 64.0)
        
        // Create final rhythm generators that take a pattern position (0-1)
        // and output a rhythm value using the current position in rhythm space
        let kickRhythm: Crvs.FloatOp = { patternPos in
            let timePos = timePhasor(patternPos)
            let rhythmFunc = kickNavigator(timePos)
            return rhythmFunc(patternPos)
        }
        
        let snareRhythm: Crvs.FloatOp = { patternPos in
            let timePos = timePhasor(patternPos)
            let rhythmFunc = snareNavigator(timePos)
            return rhythmFunc(patternPos)
        }
        
        let hihatRhythm: Crvs.FloatOp = { patternPos in
            let timePos = timePhasor(patternPos)
            let rhythmFunc = hihatNavigator(timePos)
            return rhythmFunc(patternPos)
        }
        
        // Return complete rhythm ensemble
        return [
            "kick": kickRhythm,
            "snare": snareRhythm,
            "hihat": hihatRhythm
        ]
    }
}

// MARK: - Advanced DSL Components

extension WaveformNode {
    /// Apply a rhythmic "humanization" to this node
    public func humanize(amount: Float = 0.1) -> WaveformNode {
        return ChainNode(operations: [
            self,
            Phase(
                ProbabilisticTriggers(probability: 0.5, seed: 42)
                    .multiply(amount)
            )
        ])
    }
    
    /// Apply swing feel to this node
    public func swing(amount: Float = 0.1) -> WaveformNode {
        return ChainNode(operations: [
            self,
            Phase(
                Sine()
                    .rate(2.0)
                    .multiply(amount)
            )
        ])
    }
}

/// Extended PulseDivider with accent pattern
public struct AccentedPulseDivider: WaveformNode {
    let divisions: Int
    let pulseWidth: Float
    let accentPattern: [Bool]
    
    public init(divisions: Int = 4, pulseWidth: Float = 0.5, accentPattern: [Bool] = []) {
        self.divisions = max(1, divisions)
        self.pulseWidth = min(max(0.1, pulseWidth), 0.9)
        self.accentPattern = accentPattern
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        let baseOp = ops.pulse(
            ops.mult(ops.phasor(), Float(divisions)),
            pulseWidth
        )
        
        // If no accent pattern specified, return base operation
        guard !accentPattern.isEmpty else {
            return baseOp
        }
        
        // Apply accent pattern
        return { pos in
            let value = baseOp(pos)
            
            // Only apply accents to active steps
            if value > 0.5 {
                // Determine current division
                let divPos = pos * Float(divisions)
                let divIndex = Int(divPos) % accentPattern.count
                
                // Apply accent
                return accentPattern[divIndex] ? 1.0 : 0.7
            }
            
            return value
        }
    }
}

/// Perlin noise-based rhythm generator
public struct NoiseRhythm: WaveformNode {
    let speed: Float
    let threshold: Float
    let octaves: Int
    
    public init(speed: Float = 1.0, threshold: Float = 0.5, octaves: Int = 2) {
        self.speed = speed
        self.threshold = threshold
        self.octaves = octaves
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        // Create perlin noise with specified parameters
        let noiseOp = ops.perlin(
            ops.mult(ops.phasor(), speed),
            ops.c(0.3),
            nil,
            ops.c(0.5),
            ops.c(Float(octaves))
        )
        
        // Threshold the noise to create triggers
        return ops.greater(noiseOp, threshold)
    }
}


// MARK: - Usage Examples

class RhythmPatternExamples {
    let generator = RhythmPatternGenerator()
    let ops = Crvs.Ops()
    
    /// Basic example of using standard waveforms for rhythms
    func basicRhythmExample() {
        // TODO: Figure out how  these puluse rhythms were intended to be used
        // Create a simple pulse rhythm (quarter notes)
//        let quarterNote = generator.createRhythmGenerator(
//            type: "pulse", 
//            pulseWidth: 0.25, 
//            frequency: 1.0
//        )
        
        // Create eighth notes
//        let eighthNote = generator.createRhythmGenerator(
//            type: "pulse", 
//            pulseWidth: 0.25, 
//            frequency: 2.0
//        )
        
        // Create sixteenth notes
//        let sixteenthNote = generator.createRhythmGenerator(
//            type: "pulse", 
//            pulseWidth: 0.25, 
//            frequency: 4.0
//        )
        
        // Create a basic drum pattern (mix of different rhythms)
        let kickDrum = generator.createRhythmGenerator(
            type: "pulse", 
            pulseWidth: 0.4, 
            frequency: 1.0
        )
        
        let snareDrum = generator.createRhythmGenerator(
            type: "pulse", 
            pulseWidth: 0.4, 
            frequency: 0.5,
            phaseOffset: 0.5 // Offset to hit on beats 2 and 4
        )
        
        let hiHat = generator.createRhythmGenerator(
            type: "pulse", 
            pulseWidth: 0.2, 
            frequency: 2.0
        )
        
        // Generate 16-step patterns
        let kickPattern = generator.generateThresholdPattern(
            waveform: kickDrum, 
            threshold: 0.5, 
            stepCount: 16
        )
        
        let snarePattern = generator.generateThresholdPattern(
            waveform: snareDrum, 
            threshold: 0.5, 
            stepCount: 16
        )
        
        let hiHatPattern = generator.generateThresholdPattern(
            waveform: hiHat, 
            threshold: 0.5, 
            stepCount: 16
        )
        
        print("Kick Pattern: \(patternToString(kickPattern))")
        print("Snare Pattern: \(patternToString(snarePattern))")
        print("Hi-Hat Pattern: \(patternToString(hiHatPattern))")
    }
    
    /// Example using Euclidean rhythms
    func euclideanRhythmExample() {
        // 3 pulses over 8 steps (tresillo rhythm)
        let tresillo = generator.generateEuclideanRhythm(
            pulses: 3, 
            steps: 8
        )
        
        // 5 pulses over 16 steps
        let cincoPattern = generator.generateEuclideanRhythm(
            pulses: 5, 
            steps: 16
        )
        
        // Common African bell pattern (12/8 time)
        let bellPattern = generator.generateEuclideanRhythm(
            pulses: 7, 
            steps: 12, 
            rotation: 1
        )
        
        print("Tresillo (3,8): \(patternToString(tresillo))")
        print("Cinco (5,16): \(patternToString(cincoPattern))")
        print("Bell (7,12,1): \(patternToString(bellPattern))")
    }
    
    /// Example using polyrhythms
    func polyrhythmExample() {
        // Create 3 against 4 polyrhythm
        let rhythm3 = generator.createRhythmGenerator(
            type: "pulse", 
            pulseWidth: 0.25, 
            frequency: 3.0
        )
        
        let rhythm4 = generator.createRhythmGenerator(
            type: "pulse", 
            pulseWidth: 0.25, 
            frequency: 4.0
        )
        
        // Combine into a polyrhythm
        let poly34 = generator.createPolyrhythm(
            rhythms: [rhythm3, rhythm4]
        )
        
        // Generate a 12-step pattern (LCM of 3 and 4)
        let polyPattern = generator.generateThresholdPattern(
            waveform: poly34, 
            threshold: 0.25,  // Lower threshold to detect both rhythms
            stepCount: 12
        )
        
        print("3:4 Polyrhythm: \(patternToString(polyPattern))")
    }
    
    /// Example using advanced modulation techniques
    func modulatedRhythmExample() {
        // Base rhythm (quarter notes)
        let baseRhythm = generator.createRhythmGenerator(
            type: "pulse", 
            pulseWidth: 0.4, 
            frequency: 4.0
        )
        
        // Create a slow LFO for modulation
        let modulator = ops.sine(ops.c(0.0))
        let modulatedRhythm = generator.modulateRhythm(
            baseRhythm: baseRhythm,
            modulationOp: ops.rate(modulator, 0.25),
            modulationDepth: 0.2
        )
        
        // Generate a pattern with the modulated rhythm
        let modPattern = generator.generateThresholdPattern(
            waveform: modulatedRhythm, 
            threshold: 0.5, 
            stepCount: 32
        )
        
        print("Modulated Rhythm: \(patternToString(modPattern))")
    }
    
    /// Example using DSL for rhythm creation
    func dslRhythmExample() {
        // Create a complex rhythm using the DSL
        let complexRhythm = generator.rhythm { [self] in
            // Base pulse (4 pulses per measure)
            // TODO: figure out how this pulse was intended to be used
            // let pulse = ops.pulse(ops.mult(ops.phasor(), 4.0), 0.25)
            
            // Add some swing
            let swingLFO = ops.sine(ops.c(0.0))
            let swingMod = ops.bias(ops.mult(ops.rate(swingLFO, 2.0), 0.1), ops.phasor())
            
            // Apply swing to the pulse
            ops.pulse(swingMod, 0.25)
        }
        
        // Using the ops.waveform DSL
        let builderRhythm = ops.waveform {
            // Combine a Euclidean rhythm with some probabilistic accents
            Polyrhythm(
                rhythms: EuclideanRhythm(pulses: 5, steps: 16),
                ProbabilisticTriggers(probability: 0.3)
            )
        }
        
        // Generate patterns
        let complexPattern = generator.generateThresholdPattern(
            waveform: complexRhythm, 
            threshold: 0.5, 
            stepCount: 16
        )
        
        let builderPattern = generator.generateThresholdPattern(
            waveform: builderRhythm,
            threshold: 0.5, 
            stepCount: 16
        )
        
        print("Complex Rhythm: \(patternToString(complexPattern))")
        print("Builder Rhythm: \(patternToString(builderPattern))")
    }
    
    /// Generate a complete drum pattern
    func generateDrumPattern() -> [String: [Float]] {
        // Create individual drum parts
        let kickRhythm = ops.waveform {
            // Basic kick on beats 1 and 3
            EuclideanRhythm(pulses: 2, steps: 8, rotation: 0)
            
            // Add occasional extra kicks
            ProbabilisticTriggers(probability: 0.2)
                .bias(0.1) // Subtle bias
        }
        
        let snareRhythm = ops.waveform {
            // Snare on beats 2 and 4
            EuclideanRhythm(pulses: 2, steps: 8, rotation: 2)
            
            // Add occasional ghost notes
            ProbabilisticTriggers(probability: 0.15)
                .rate(2.0) // Faster variation
        }
        
        let hihatRhythm = ops.waveform {
            // Eighth note hi-hats
            PulseDivider(divisions: 8, pulseWidth: 0.3)
            
            // Add some swing
            Phase(0.1)
                .bias(0.02)
        }
        
        // Build the complete pattern
        var drumPattern: [String: [Float]] = [:]
        
        // Generate 32-step patterns
        drumPattern["kick"] = generator.generateThresholdPattern(
            waveform: kickRhythm,
            threshold: 0.5, 
            stepCount: 32
        )
        
        drumPattern["snare"] = generator.generateThresholdPattern(
            waveform: snareRhythm,
            threshold: 0.5, 
            stepCount: 32
        )
        
        drumPattern["hihat"] = generator.generateThresholdPattern(
            waveform: hihatRhythm,
            threshold: 0.5, 
            stepCount: 32
        )
        
        // Add cymbal crashes for accents
        drumPattern["cymbal"] = generator.generateThresholdPattern(
            waveform: ops.waveform {
                ProbabilisticTriggers(probability: 0.1, seed: 42)
            },
            threshold: 0.75,
            stepCount: 32
        )
        
        return drumPattern
    }
    
    // MARK: - Helper Functions
    
    /// Convert a pattern array to a visual string representation
    func patternToString(_ pattern: [Float]) -> String {
        return pattern.map { $0 > 0.5 ? "X" : "." }.joined()
    }
}

// MARK: - Advanced Applications

/// Advanced time signature and polymetric rhythm generator
class PolymetricRhythmGenerator {
    let ops = Crvs.Ops()
    let rhythmGen = RhythmPatternGenerator()
    
    /// Generate a rhythm in a specific time signature
    /// - Parameters:
    ///   - beatsPerBar: Number of beats per bar
    ///   - division: Division of each beat (usually 2, 3, or 4)
    ///   - accentFirst: Whether to accent the first beat of each bar
    ///   - pattern: Optional custom accent pattern
    func createTimeSignatureRhythm(beatsPerBar: Int, division: Int, 
                                accentFirst: Bool = true,
                                pattern: [Bool]? = nil) -> Crvs.FloatOp {
        
        let totalSteps = beatsPerBar * division
        
        // Generate accent pattern
        var accentPattern = [Float](repeating: 0.0, count: totalSteps)
        
        if let customPattern = pattern, customPattern.count == totalSteps {
            // Use custom pattern
            for i in 0..<totalSteps {
                accentPattern[i] = customPattern[i] ? 1.0 : 0.0
            }
        } else {
            // Default pattern with accents
            for i in 0..<totalSteps {
                // Accent the downbeat of each beat
                if i % division == 0 {
                    // Stronger accent on first beat if requested
                    accentPattern[i] = (i == 0 && accentFirst) ? 1.0 : 0.75
                } else {
                    accentPattern[i] = 0.25 // Non-accented beats
                }
            }
        }
        
        // Create rhythm function
        return { pos in
            let step = Int(pos * Float(totalSteps)) % totalSteps
            return accentPattern[step]
        }
    }
    
    /// Create polymetric rhythm (multiple time signatures simultaneously)
    /// - Parameters:
    ///   - timeSignatures: Array of (beatsPerBar, division) tuples
    ///   - weights: Optional weights for each time signature
    func createPolymetricRhythm(timeSignatures: [(beats: Int, division: Int)], 
                              weights: [Float]? = nil) -> Crvs.FloatOp {
        
        // Create individual rhythms
        let rhythms: [Crvs.FloatOp] = timeSignatures.map { sig in
            createTimeSignatureRhythm(beatsPerBar: sig.beats, division: sig.division)
        }
        
        // Combine with proper weights
        return rhythmGen.createPolyrhythm(rhythms: rhythms, weights: weights)
    }
    
    /// Create an evolving rhythm that changes over time
    /// - Parameters:
    ///   - phases: Array of rhythms to transition between
    ///   - transitionDuration: How long each transition takes (0-1 range)
    func createEvolvingRhythm(phases: [Crvs.FloatOp], 
                            transitionDuration: Float = 0.1) -> Crvs.FloatOp {
        
        guard !phases.isEmpty else { return { _ in 0.0 } }
        
        // If only one phase, return it directly
        if phases.count == 1 {
            return phases[0]
        }
        
        // Create a function that selects or interpolates between phases
        return { pos in
            // Determine which phase we're in
            let phaseCount = Float(phases.count)
            let phasePos = pos * phaseCount
            let currentPhaseIndex = Int(phasePos) % phases.count
            let nextPhaseIndex = (currentPhaseIndex + 1) % phases.count
            
            // Calculate position within this phase
            let phaseOffset = phasePos - Float(Int(phasePos))
            
            // Determine if we're in a transition
            if phaseOffset < transitionDuration {
                // In transition - blend between phases
                let blendFactor = phaseOffset / transitionDuration
                return (1.0 - blendFactor) * phases[currentPhaseIndex](pos) + 
                       blendFactor * phases[nextPhaseIndex](pos)
            } else {
                // Not in transition - use current phase
                return phases[currentPhaseIndex](pos)
            }
        }
    }
    
    /// Create a rhythm sequence with specified number of repetitions per pattern
    /// - Parameters:
    ///   - patterns: Array of rhythm patterns
    ///   - repetitions: Number of times to repeat each pattern
    func createRhythmSequence(patterns: [Crvs.FloatOp], 
                            repetitions: Int) -> Crvs.FloatOp {
        
        guard !patterns.isEmpty else { return { _ in 0.0 } }
        
        let totalPatterns = patterns.count
        let totalCycles = totalPatterns * repetitions
        
        return { pos in
            // Calculate which repetition we're in
            let cyclePos = pos * Float(totalCycles)
            let patternIndex = (Int(cyclePos) / repetitions) % totalPatterns
            
            // Get position within the pattern
            let patternPos = cyclePos.truncatingRemainder(dividingBy: 1.0)
            
            return patterns[patternIndex](patternPos)
        }
    }
}

// MARK: - Rhythm Utilities

/// Utility functions for rhythm pattern generation
class RhythmUtilities {
    
    /// Convert a rhythm pattern to MIDI note events
    /// - Parameters:
    ///   - pattern: The rhythm pattern (array of 0/1 values)
    ///   - noteNumber: MIDI note number to use
    ///   - velocity: MIDI velocity for triggered notes
    ///   - noteDuration: Duration of each note in beats
    ///   - bpm: Tempo in beats per minute
    /// - Returns: Array of (time, note, velocity, duration) tuples
    func patternToMIDINotes(pattern: [Float], 
                         noteNumber: Int, 
                         velocity: Int = 100, 
                         noteDuration: Float = 0.25, 
                         bpm: Float = 120.0) -> [(time: Double, note: Int, velocity: Int, duration: Double)] {
        
        var notes: [(time: Double, note: Int, velocity: Int, duration: Double)] = []
        
        // Calculate time per step
        let secondsPerBeat = 60.0 / Double(bpm)
        let secondsPerStep = secondsPerBeat * Double(noteDuration)
        
        // Convert pattern to MIDI events
        for (i, value) in pattern.enumerated() {
            if value > 0.5 {
                let time = Double(i) * secondsPerStep
                notes.append((
                    time: time,
                    note: noteNumber,
                    velocity: velocity,
                    duration: secondsPerStep
                ))
            }
        }
        
        return notes
    }
    
    /// Analyze a rhythm pattern for common metrics
    /// - Parameter pattern: The rhythm pattern to analyze
    /// - Returns: Dictionary of rhythm metrics
    func analyzeRhythm(pattern: [Float]) -> [String: Any] {
        var metrics: [String: Any] = [:]
        
        // Calculate density (percentage of active steps)
        let activeSteps = pattern.filter { $0 > 0.5 }.count
        let density = Float(activeSteps) / Float(pattern.count)
        metrics["density"] = density
        
        // Calculate syncopation (offbeat emphasis)
        var syncopation = 0.0
        for i in 0..<pattern.count {
            if pattern[i] > 0.5 && i % 2 == 1 {
                syncopation += 1.0
            }
        }
        metrics["syncopation"] = syncopation / Double(activeSteps)
        
        // Calculate evenness (how evenly distributed the notes are)
        if activeSteps > 1 {
            var intervals: [Int] = []
            var lastActive = -1
            
            for i in 0..<pattern.count {
                if pattern[i] > 0.5 {
                    if lastActive >= 0 {
                        intervals.append(i - lastActive)
                    }
                    lastActive = i
                }
            }
            
            // Add wraparound interval
            if lastActive >= 0 && pattern[0] > 0.5 {
                intervals.append(pattern.count - lastActive)
            }
            
            // Calculate standard deviation of intervals
            if !intervals.isEmpty {
                let mean = intervals.reduce(0, +) / intervals.count
                let variance = intervals.reduce(0) { $0 + pow(Double($1 - mean), 2) } / Double(intervals.count)
                let stdDev = sqrt(variance)
                metrics["evenness"] = 1.0 - (stdDev / Double(pattern.count))
            }
        }
        
        return metrics
    }
    
    /// Combine multiple rhythm patterns into a composite pattern
    /// - Parameters:
    ///   - patterns: Dictionary of named patterns
    ///   - rules: Combination rules (AND, OR, XOR, etc.)
    /// - Returns: Combined pattern
    func combinePatterns(patterns: [String: [Float]], rules: [String: String]) -> [Float] {
        // Make a mutable copy of the input dictionary.
        var mutablePatterns = patterns
        
        guard let firstPattern = mutablePatterns.first?.value else {
            return []
        }
        
        let length = firstPattern.count
        var result = [Float](repeating: 0.0, count: length)
        
        // Process each rule
        for (targetName, rule) in rules {
            let components = rule.components(separatedBy: " ")
            guard components.count >= 3, components.count % 2 == 1 else {
                continue // Invalid rule format
            }
            
            // Start with the first pattern
            guard let firstPatternName = components.first,
                  let firstPattern = mutablePatterns[firstPatternName] else {
                continue
            }
            
            // Initialize with first pattern
            var tempResult = firstPattern
            
            // Apply operations
            for i in stride(from: 1, to: components.count, by: 2) {
                guard i + 1 < components.count else { break }
                
                let operation = components[i]
                let patternName = components[i + 1]
                
                guard let pattern = mutablePatterns[patternName], pattern.count == length else {
                    continue
                }
                
                // Apply operation
                for j in 0..<length {
                    switch operation.lowercased() {
                    case "and":
                        tempResult[j] = (tempResult[j] > 0.5 && pattern[j] > 0.5) ? 1.0 : 0.0
                    case "or":
                        tempResult[j] = (tempResult[j] > 0.5 || pattern[j] > 0.5) ? 1.0 : 0.0
                    case "xor":
                        tempResult[j] = (tempResult[j] > 0.5) != (pattern[j] > 0.5) ? 1.0 : 0.0
                    case "not":
                        tempResult[j] = (pattern[j] <= 0.5) ? 1.0 : 0.0
                    default:
                        break
                    }
                }
            }
            
            // Update the mutable dictionary with the computed result.
            if mutablePatterns[targetName] != nil {
                mutablePatterns[targetName] = tempResult
            } else {
                result = tempResult
            }
        }
        
        return result
    }

}
