/*
# Benefits of the Crvs Swift DSL

The result builder-based DSL offers numerous advantages over traditional API calls:

## 1. Improved Readability and Intent

Traditional API:
```swift
let op = ops.chain([
    ops.sine(),
    ops.easeOut(3.0),
    ops.phase(ops.c(0.2))
])
```

With DSL:
```swift
let op = WaveformBuilder {
    Sine()
    EaseOut(3.0)
    Phase(0.2)
}
```

The DSL makes it immediately clear that operations are being chained in sequence,
with each line representing a step in the processing chain.

## 2. Hierarchical Structure

The DSL naturally represents the hierarchical structure of complex operations,
making it easier to understand the relationship between components.

## 3. Conditional Logic

Result builders support if/else statements, enabling dynamic waveform creation:
```swift
let waveform = WaveformBuilder {
    if useDetune {
        Mix(Sine(), Sine().rate(1.01))
    } else {
        Sine()
    }
    EaseOut(2.0)
}
```

## 4. Composability

Components can be nested and reused, creating a more modular and maintainable codebase:
```swift
let modulationComponent = WaveformBuilder {
    Triangle()
    Rate(0.5)
}

let finalWaveform = WaveformBuilder {
    Sine()
    Ring(IdentityNode(), modulationComponent)
}
```

## 5. Extensibility

The DSL can be easily extended with new node types and combinators.
*/

// MARK: - Advanced Techniques

import Foundation

// MARK: Dynamic Component Creation

/// Example of building DSL components dynamically
class DynamicComponentExample {
    
    /// Create harmonics dynamically
    func createHarmonics(count: Int, falloff: Float = 0.5) -> Crvs.FloatOp {
        // Create an array of harmonic components
        var harmonics: [WaveformNode] = []
        var weights: [Float] = []
        
        for i in 1...count {
            let harmonic = Sine().rate(Float(i)).multiply(pow(falloff, Float(i-1)))
            harmonics.append(harmonic)
            weights.append(pow(falloff, Float(i-1)))
        }
        
        // Create waveform with dynamic components
        return WaveformBuilder {
            Mix(harmonics, weights: weights)
        }
    }
    
    /// Create a string of effect processors dynamically
    func createEffectChain(effects: [String], parameters: [String: Float]) -> WaveformNode {
        var chainComponents: [WaveformNode] = []
        
        // Add base oscillator
        chainComponents.append(Sine())
        
        // Add each effect in sequence
        for effect in effects {
            switch effect {
            case "phase":
                let amount = parameters["phaseAmount"] ?? 0.1
                chainComponents.append(Phase(amount))
            case "bias":
                let amount = parameters["biasAmount"] ?? 0.2
                chainComponents.append(Bias(amount))
            case "multiply":
                let amount = parameters["multiplyAmount"] ?? 0.5
                chainComponents.append(Multiply(amount))
            case "easeIn":
                let exponent = parameters["easeInExponent"] ?? 2.0
                chainComponents.append(EaseIn(exponent))
            case "easeOut":
                let exponent = parameters["easeOutExponent"] ?? 2.0
                chainComponents.append(EaseOut(exponent))
            default:
                break
            }
        }
        
        // Create chain node
        return ChainNode(operations: chainComponents)
    }
}

// MARK: Custom Modifiers

/// Example of extending the DSL with custom modifiers
extension WaveformNode {
    
    /// Add vibrato to a waveform
    public func vibrato(rate: Float = 5.0, depth: Float = 0.05) -> WaveformNode {
        return Ring(
            self,
            Sine().rate(rate).multiply(depth).bias(1.0 - depth)
        )
    }
    
    /// Add tremolo to a waveform
    public func tremolo(rate: Float = 4.0, depth: Float = 0.3) -> WaveformNode {
        return Ring(
            self,
            Sine().rate(rate).multiply(depth).bias(1.0 - depth)
        )
    }
    
    /// Add distortion to a waveform
    public func distort(amount: Float = 0.5) -> WaveformNode {
        return ChainNode(operations: [
            self,
            EaseIn(1.0 + amount * 3.0)
        ])
    }
    
    /// Add echo/delay to a waveform
    public func echo(delay: Float = 0.3, feedback: Float = 0.5) -> WaveformNode {
        return Mix([
            self,
            ChainNode(operations: [
                self,
                Phase(delay),
                Multiply(feedback)
            ])
        ])
    }
}

// MARK: Custom Waveform Types

/// Creating custom waveform types with the DSL
struct Noise: WaveformNode {
    public func createOperation() -> Crvs.FloatOp {
        return { _ in Float.random(in: 0...1) }
    }
}

/// Pink noise
struct PinkNoise: WaveformNode {
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        return ops.perlin(ops.phasor(), nil, nil, ops.c(0.5), ops.c(3))
    }
}

/// Custom waveform that combines multiple basic waveforms
struct FMWave: WaveformNode {
    let carrierFreq: Float
    let modulationIndex: Float
    let modulatorFreq: Float
    
    public init(
        carrierFreq: Float = 1.0,
        modulationIndex: Float = 0.5,
        modulatorFreq: Float = 5.0
    ) {
        self.carrierFreq = carrierFreq
        self.modulationIndex = modulationIndex
        self.modulatorFreq = modulatorFreq
    }
    
    public func createOperation() -> Crvs.FloatOp {
        let ops = Crvs.Ops()
        
        // FM synthesis
        let modulator = ops.sine(ops.c(0.0))
        let modulatedPhase = ops.bias(
            ops.mult(modulator, modulationIndex),
            ops.phasor()
        )
        
        return ops.chain([
            ops.rate(ops.phase(ops.sine(), modulatedPhase), carrierFreq)
        ])
    }
}

// MARK: - Integration with Other Swift Features

/// Example showing integration with modern Swift features
class ModernSwiftIntegration {
    
    /// Combine async/await with the DSL
    func generateWaveformAsync(type: String, parameters: [String: Float]) async -> [Float] {
        // Create a waveform based on parameters
        let waveform = createWaveform(type: type, parameters: parameters)
        
        // Generate samples (simulate work with async)
        return await withCheckedContinuation { continuation in
            // Simulate work on background thread
            DispatchQueue.global().async {
                let samples = generateSamples(waveform, count: 1000)
                continuation.resume(returning: samples)
            }
        }
    }
    
    /// Create a waveform using the DSL
    private func createWaveform(type: String, parameters: [String: Float]) -> Crvs.FloatOp {
        switch type {
        case "sine":
            return WaveformBuilder {
                Sine(feedback: parameters["feedback"] ?? 0.0)
                if let phase = parameters["phase"] {
                    Phase(phase)
                }
            }
            
        case "triangle":
            return WaveformBuilder {
                Triangle(symmetry: parameters["symmetry"] ?? 0.5)
                if let bias = parameters["bias"] {
                    Bias(bias)
                }
            }
            
        case "fm":
            return WaveformBuilder {
                FMWave(
                    carrierFreq: parameters["carrierFreq"] ?? 1.0,
                    modulationIndex: parameters["modulationIndex"] ?? 0.5,
                    modulatorFreq: parameters["modulatorFreq"] ?? 5.0
                )
            }
            
        default:
            return WaveformBuilder { Sine() }
        }
    }
    
    /// Generate samples from a waveform
    private func generateSamples(_ op: Crvs.FloatOp, count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        
        for i in 0..<count {
            let pos = Float(i) / Float(count)
            samples[i] = op(pos)
        }
        
        return samples
    }
    
    /// Using the DSL with SwiftUI view modifiers
    func createAnimatableModifier() -> some SwiftUI.ViewModifier {
        let animationCurve = WaveformBuilder {
            EaseInOut(2.5)
            Bias(0.1)
        }
        
        // Create a custom SwiftUI animation
        struct CustomAnimationModifier: ViewModifier {
            let animationCurve: Crvs.FloatOp
            let duration: Double
            @State private var progress: Double = 0.0
            
            func body(content: Content) -> some View {
                content
                    .scaleEffect(CGFloat(animationCurve(Float(progress))))
                    .onAppear {
                        withAnimation(.linear(duration: duration).repeatForever()) {
                            progress = 1.0
                        }
                    }
            }
        }
        
        return CustomAnimationModifier(animationCurve: animationCurve, duration: 2.0)
    }
}

// MARK: - DSL Type-Safety Benefits

/*
The Waveform DSL provides excellent type safety compared to using raw closures:

1. Parameter type validation at compile time
2. Clear distinction between node types
3. Self-documenting API with strongly-typed parameters

For example, with raw closures:
```swift
// Potentially error-prone - easy to get parameter order wrong
let op = ops.phase(ops.sine(), 0.5)
```

With the DSL:
```swift
// Clear, self-documenting code
let op = WaveformBuilder {
    Sine().phase(0.5)
}
```

Types ensure parameters are used correctly, and the fluent API
makes intent clear.
*/

// MARK: - Performance Considerations

/// Performance optimization for DSL usage
class DSLPerformanceOptimization {
    
    /// Pre-compile a frequently used waveform
    func precompileWaveform() -> Crvs.FloatOp {
        // Define the waveform once
        let waveformDef = WaveformBuilder {
            Sine()
            EaseOut(2.5)
            Phase(0.2)
        }
        
        // Pre-compile to optimal implementation
        // This avoids rebuilding the chain for each call
        return waveformDef
    }
    
    /// Factory method for efficient waveform creation
    func createOptimizedWaveform(type: String, parameters: [String: Float]) -> Crvs.FloatOp {
        // Use memoization pattern to cache common waveforms
        let cacheKey = "\(type)_\(parameters.hashValue)"
        
        if let cached = waveformCache[cacheKey] {
            return cached
        }
        
        // Create new waveform
        let waveform: Crvs.FloatOp
        
        switch type {
        case "sine":
            waveform = WaveformBuilder {
                Sine(feedback: parameters["feedback"] ?? 0.0)
                if let phase = parameters["phase"] {
                    Phase(phase)
                }
            }
            
        case "triangle":
            waveform = WaveformBuilder {
                Triangle(symmetry: parameters["symmetry"] ?? 0.5)
                EaseOut(parameters["ease"] ?? 2.0)
            }
            
        default:
            waveform = WaveformBuilder { Sine() }
        }
        
        // Cache for future use
        waveformCache[cacheKey] = waveform
        
        return waveform
    }
    
    // Waveform cache
    private var waveformCache: [String: Crvs.FloatOp] = [:]
}
