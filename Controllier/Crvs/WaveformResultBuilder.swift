import Foundation

// MARK: - WaveformBuilder Result Builder

/// Result builder for creating waveform operation chains
@resultBuilder
public struct WaveformBuilder {
    
    // Build a single component (required)
    public static func buildBlock(_ component: WaveformNode) -> WaveformNode {
        return component
    }
    
    // Build from multiple components (required)
    public static func buildBlock(_ components: WaveformNode...) -> WaveformNode {
        return ChainNode(operations: components)
    }
    
    // Handle optionals (optional)
    public static func buildOptional(_ component: WaveformNode?) -> WaveformNode {
        return component ?? IdentityNode()
    }
    
    // Handle if statements (optional)
    public static func buildEither(first component: WaveformNode) -> WaveformNode {
        return component
    }
    
    // Handle else statements (optional)
    public static func buildEither(second component: WaveformNode) -> WaveformNode {
        return component
    }
    
    // Handle arrays (optional)
    public static func buildArray(_ components: [WaveformNode]) -> WaveformNode {
        return ChainNode(operations: components)
    }
    
    // Final result transformation (optional)
    public static func buildFinalResult(_ component: WaveformNode) -> Crvs.FloatOp {
        return component.createOperation()
    }
}

// MARK: - Waveform Builder Convenience Wrapper

public struct Waveform {
    public let operation: Crvs.FloatOp
    
    public init(@WaveformBuilder _ content: () -> Crvs.FloatOp) {
        self.operation = content()
    }
}


// MARK: - Waveform Node Protocol

/// Protocol for all waveform operations in the DSL
public protocol WaveformNode {
    /// Create the actual operation
    func createOperation() -> Crvs.FloatOp
}

// MARK: - Basic Node Types

/// Node that passes through the input (identity operation)
public struct IdentityNode: WaveformNode {
    public init() {}
    
    public func createOperation() -> Crvs.FloatOp {
        return { pos in pos }
    }
}

/// Node that chains multiple operations together
public struct ChainNode: WaveformNode {
    let operations: [WaveformNode]
    
    public init(operations: [WaveformNode]) {
        self.operations = operations
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        // Create array of operations
        let floatOps = operations.map { $0.createOperation() }
        
        // Chain them together
        return ops.chain(floatOps)
    }
}

// MARK: - Basic Waveform Nodes

/// Sine wave node
public struct Sine: WaveformNode {
    let feedback: Float
    
    public init(feedback: Float = 0.0) {
        self.feedback = feedback
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.sine(feedback)
    }
}

/// Triangle wave node
public struct Triangle: WaveformNode {
    let symmetry: Float
    
    public init(symmetry: Float = 0.5) {
        self.symmetry = symmetry
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.tri(symmetry)
    }
}

/// Sawtooth wave node
public struct Saw: WaveformNode {
    public init() {}
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.saw()
    }
}

/// Square/Pulse wave node
public struct Square: WaveformNode {
    let width: Float
    
    public init(width: Float = 0.5) {
        self.width = width
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.pulse(width)
    }
}

/// Alias for Square with different name
public typealias Pulse = Square

// MARK: - Modifiers

/// Phase modifier node
public struct Phase: WaveformNode {
    let phaseOffsetValue: Float?
    let phaseOffsetNode: WaveformNode?
    let input: WaveformNode?
    
    // Constructor for constant phase offset
    public init(_ phaseOffset: Float, input: WaveformNode? = nil) {
        self.phaseOffsetValue = phaseOffset
        self.phaseOffsetNode = nil
        self.input = input
    }
    
    // New constructor for dynamic phase modulation
    public init(_ phaseOffsetNode: WaveformNode, input: WaveformNode? = nil) {
        self.phaseOffsetValue = nil
        self.phaseOffsetNode = phaseOffsetNode
        self.input = input
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        let baseOp = input?.createOperation() ?? ops.phasor()
        
        if let phaseOffsetNode = phaseOffsetNode {
            // Dynamic phase modulation
            let phaseModOp = phaseOffsetNode.createOperation()
            
            return { pos in
                // Calculate modulated position
                let phaseOffset = phaseModOp(pos)
                let modPos = fmod(pos + phaseOffset, 1.0)
                
                // Apply base operation at modulated position
                return baseOp(modPos)
            }
        } else if let phaseOffsetValue = phaseOffsetValue {
            // Constant phase offset
            return ops.phase(baseOp, phaseOffsetValue)
        } else {
            // Default case (should not happen)
            return baseOp
        }
    }
}

/// Rate modifier node
public struct Rate: WaveformNode {
    let rateOffset: Float
    let input: WaveformNode?
    
    public init(_ rateOffset: Float, input: WaveformNode? = nil) {
        self.rateOffset = rateOffset
        self.input = input
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        if let input = input {
            return ops.rate(input.createOperation(), rateOffset)
        } else {
            return ops.rate(ops.phasor(), rateOffset)
        }
    }
}

/// Bias (offset) modifier node
public struct Bias: WaveformNode {
    let offset: Float
    let input: WaveformNode?
    
    public init(_ offset: Float, input: WaveformNode? = nil) {
        self.offset = offset
        self.input = input
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        if let input = input {
            return ops.bias(input.createOperation(), offset)
        } else {
            return ops.bias(ops.phasor(), offset)
        }
    }
}

/// Multiply modifier node
public struct Multiply: WaveformNode {
    let scalar: Float
    let input: WaveformNode?
    
    public init(_ scalar: Float, input: WaveformNode? = nil) {
        self.scalar = scalar
        self.input = input
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        if let input = input {
            return ops.mult(input.createOperation(), scalar)
        } else {
            return ops.mult(ops.phasor(), scalar)
        }
    }
}

// MARK: - Easing Nodes

/// EaseIn function node
public struct EaseIn: WaveformNode {
    let exponent: Float
    
    public init(_ exponent: Float = 2.0) {
        self.exponent = exponent
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.easeIn(exponent)
    }
}

/// EaseOut function node
public struct EaseOut: WaveformNode {
    let exponent: Float
    
    public init(_ exponent: Float = 2.0) {
        self.exponent = exponent
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.easeOut(exponent)
    }
}

/// EaseInOut function node
public struct EaseInOut: WaveformNode {
    let exponent: Float
    
    public init(_ exponent: Float = 2.0) {
        self.exponent = exponent
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.easeInOut(exponent)
    }
}

/// EaseOutIn function node
public struct EaseOutIn: WaveformNode {
    let exponent: Float
    
    public init(_ exponent: Float = 2.0) {
        self.exponent = exponent
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.easeOutIn(exponent)
    }
}

// MARK: - Envelope Nodes

/// ADSR Envelope node
public struct Envelope: WaveformNode {
    let attackLength: Float
    let attackLevel: Float
    let decayLength: Float
    let sustainLength: Float
    let sustainLevel: Float
    let releaseLength: Float
    
    public init(
        attack: Float,
        attackLevel: Float = 1.0,
        decay: Float,
        sustain: Float,
        sustainLevel: Float,
        release: Float
    ) {
        self.attackLength = attack
        self.attackLevel = attackLevel
        self.decayLength = decay
        self.sustainLength = sustain
        self.sustainLevel = sustainLevel
        self.releaseLength = release
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.env(attackLength: attackLength,
                      attackLevel: attackLevel,
                      decayLength: decayLength,
                      sustainLength: sustainLength,
                      sustainLevel: sustainLevel,
                      releaseLength: releaseLength)
    }
}

// MARK: - Combination Nodes

/// Mix multiple waveforms
public struct Mix: WaveformNode {
    let operations: [WaveformNode]
    let weights: [Float]?
    
    public init(_ operations: [WaveformNode], weights: [Float]? = nil) {
        self.operations = operations
        self.weights = weights
    }
    
    public init(_ operations: WaveformNode..., weights: [Float]? = nil) {
        self.operations = operations
        self.weights = weights
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        let floatOps = operations.map { $0.createOperation() }
        
        if let weights = weights {
            return ops.mix(floatOps, weights)
        } else {
            return ops.mix(floatOps)
        }
    }
}

/// Morph between two waveforms
public struct Morph: WaveformNode {
    let fromOp: WaveformNode
    let toOp: WaveformNode
    let amount: Float
    
    public init(from: WaveformNode, to: WaveformNode, amount: Float) {
        self.fromOp = from
        self.toOp = to
        self.amount = amount
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.morph(fromOp.createOperation(), toOp.createOperation(), ops.c(amount))
    }
}

/// Ring modulation between waveforms
public struct Ring: WaveformNode {
    let opA: WaveformNode
    let opB: WaveformNode
    
    public init(_ opA: WaveformNode, _ opB: WaveformNode) {
        self.opA = opA
        self.opB = opB
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.ring(opA.createOperation(), opB.createOperation())
    }
}

// MARK: - Time-based Nodes

/// Time-based phasor node
public struct TimePhasor: WaveformNode {
    let cycleDuration: Double
    
    public init(seconds: Double) {
        self.cycleDuration = seconds
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.timePhasor(cycleDurationSeconds: cycleDuration)
    }
}

/// Tempo-based phasor node
public struct TempoPhasor: WaveformNode {
    let barsPerCycle: Double
    let bpm: Double
    
    public init(bars: Double = 1.0, bpm: Double = 120.0) {
        self.barsPerCycle = bars
        self.bpm = bpm
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.tempoPhasor(barsPerCycle: barsPerCycle, bpm: bpm)
    }
}

// MARK: - Mathematical Nodes

/// Smooth function node (cubic smoothstep)
public struct Smooth: WaveformNode {
    public init() {}
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.smooth()
    }
}

/// Smoother function node (quintic smoothstep)
public struct Smoother: WaveformNode {
    public init() {}
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.smoother()
    }
}

/// Absolute value node
public struct Abs: WaveformNode {
    let input: WaveformNode
    
    public init(_ input: WaveformNode) {
        self.input = input
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.abs(input.createOperation())
    }
}

/// Fold node
public struct Fold: WaveformNode {
    let input: WaveformNode
    let threshold: Float
    
    public init(_ input: WaveformNode, threshold: Float = 1.0) {
        self.input = input
        self.threshold = threshold
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.fold(input.createOperation(), threshold)
    }
}

/// Wrap node
public struct Wrap: WaveformNode {
    let input: WaveformNode
    let min: Float
    let max: Float
    
    public init(_ input: WaveformNode, min: Float, max: Float) {
        self.input = input
        self.min = min
        self.max = max
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.wrap(input.createOperation(), min, max)
    }
}

// MARK: - Convenience Extensions

/// Extension to create a Waveform from a DSL block
extension Crvs.Ops {
    /// Create a waveform operation using the DSL
    public func waveform(@WaveformBuilder _ content: () -> Crvs.FloatOp) -> Crvs.FloatOp {
        return content()
    }
}

/// Extension to apply modifiers to any WaveformNode
extension WaveformNode {
    /// Apply a phase offset to this waveform
    public func phase(_ offset: Float) -> WaveformNode {
        return Phase(offset, input: self)
    }
    
    /// Apply a rate multiplier to this waveform
    public func rate(_ rate: Float) -> WaveformNode {
        return Rate(rate, input: self)
    }
    
    /// Apply a bias (offset) to this waveform
    public func bias(_ offset: Float) -> WaveformNode {
        return Bias(offset, input: self)
    }
    
    /// Multiply this waveform by a scalar
    public func multiply(_ scalar: Float) -> WaveformNode {
        return Multiply(scalar, input: self)
    }
    
    /// Apply absolute value to this waveform
    public func abs() -> WaveformNode {
        return Abs(self)
    }
    
    /// Apply folding to this waveform
    public func fold(threshold: Float = 1.0) -> WaveformNode {
        return Fold(self, threshold: threshold)
    }
    
    /// Apply wrapping to this waveform
    public func wrap(min: Float, max: Float) -> WaveformNode {
        return Wrap(self, min: min, max: max)
    }
    
    /// Ring modulate with another waveform
    public func ring(with other: WaveformNode) -> WaveformNode {
        return Ring(self, other)
    }
}
