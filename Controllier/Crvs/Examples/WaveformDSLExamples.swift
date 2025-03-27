import Foundation
import SwiftUI

// MARK: - Basic DSL Usage Examples

class WaveformDSLExamples {
    
    let ops = Crvs.Ops()
    
    // MARK: Simple Composition
    
    /// Example of basic operation chaining
    func basicExample() {
        // Create a sequence of operations using the DSL
        let sequence = WaveformBuilder {
            Sine()
            EaseOut(3.0)
            Phase(0.2)
        }
        
        // Traditional equivalent without DSL
        let traditional = ops.chain([
            ops.sine(),
            ops.easeOut(3.0),
            ops.phase(ops.c(0.2))
        ])
        
        // Use the operation
        for i in 0..<10 {
            let pos = Float(i) / 10.0
            print("Position \(pos): \(sequence(pos))")
        }
    }
    
    // MARK: Complex Composition
    
    /// Create a complex FM synthesizer patch
    func fmSynthesizerExample() {
        // Create an FM synthesis patch using the DSL
        let fmSynth = WaveformBuilder {
            // Modulator (vibrato)
            Ring(
                // Carrier wave
                Sine(),
                // Modulator wave with slower frequency
                Sine().rate(0.25).multiply(0.5).bias(0.5)
            )
            // Apply envelope
            Envelope(
                attack: 0.1,
                decay: 0.2,
                sustain: 0.5,
                sustainLevel: 0.7,
                release: 0.3
            )
        }
        
        // Traditional equivalent without DSL
        let modulator = ops.bias(
            ops.mult(
                ops.rate(ops.sine(), 0.25),
                0.5
            ),
            0.5
        )
        
        let carrier = ops.sine()
        let ring = ops.ring(carrier, modulator)
        
        let traditionalFM = ops.chain([
            ring,
            ops.env(
                attackLength: 0.1,
                attackLevel: 1.0,
                decayLength: 0.2,
                sustainLength: 0.5,
                sustainLevel: 0.7,
                releaseLength: 0.3
            )
        ])
        
        // Both operations produce identical results
        // but the DSL version is much more readable
    }
    
    // MARK: Conditional Logic
    
    /// Example using conditional logic in the builder
    func conditionalExample(useComplicatedWaveform: Bool) {
        let waveform = WaveformBuilder {
            // Base waveform
            if useComplicatedWaveform {
                // Complex modulation
                Ring(
                    Sine(feedback: 0.3),
                    Triangle(symmetry: 0.7)
                )
            } else {
                // Simple sine wave
                Sine()
            }
            
            // Apply effects either way
            EaseOut(2.5)
            Phase(0.1)
        }
        
        // Use the waveform
        let samples = generateSamples(waveform, count: 1000)
        // Do something with samples...
    }
    
    // MARK: Additive Synthesis
    
    /// Create an additive synthesizer using the DSL
    func additiveExample(harmonics: Int) {
        // Create a series of harmonics
        let additiveSynth = WaveformBuilder {
            Mix(
                Sine().multiply(1.0),                        // Fundamental
                Sine().rate(2.0).multiply(0.5),             // 2nd harmonic
                Sine().rate(3.0).multiply(0.25),            // 3rd harmonic
                Sine().rate(4.0).multiply(0.125),           // 4th harmonic
                Sine().rate(5.0).multiply(0.0625),          // 5th harmonic
                weights: [1.0, 0.5, 0.33, 0.25, 0.2]        // Weights
            )
        }
        
        // Generate samples
        let samples = generateSamples(additiveSynth, count: 1000)
        // Do something with samples...
    }
    
    // MARK: Animation Curves
    
    /// Create animation curves for UI transitions
    func animationCurvesExample() {
        // Define common animation curves
        let animationCurves = [
            "linear": WaveformBuilder { IdentityNode() },
            "easeIn": WaveformBuilder { EaseIn(2.5) },
            "easeOut": WaveformBuilder { EaseOut(2.5) },
            "easeInOut": WaveformBuilder { EaseInOut(2.5) },
            "bounce": WaveformBuilder {
                EaseOut(2.0)
                Ring(
                    IdentityNode(),
                    Sine().rate(8.0).multiply(0.2).bias(0.9)
                )
            },
            "elastic": WaveformBuilder {
                EaseOut(1.5)
                Ring(
                    IdentityNode(),
                    Sine().rate(12.0).multiply(0.3).phase(0.25)
                )
            }
        ]
        
        // Generate curve samples for visualization
        var curveSamples: [String: [Float]] = [:]
        
        for (name, curve) in animationCurves {
            curveSamples[name] = generateSamples(curve, count: 100)
        }
        
        // Use the curves for animations
        animateView(
            curve: animationCurves["elastic"]!,
            duration: 0.5,
            animations: { /* view animations */ }
        )
    }
    
    // MARK: Nested Composition
    
    /// Example with nested composition
    func nestedExample() {
        // Create a complex modulation using nested components
        let modulatedWave = WaveformBuilder {
            // Base carrier wave
            Sine()
            
            // Apply amplitude modulation
            Ring(
                // This is our carrier
                IdentityNode(),
                
                // This is our modulator with its own chain
                WaveformBuilder {
                    Triangle()
                    EaseIn(2.0)
                    Rate(0.25)
                }
            )
            
            // Apply filter effect
            WaveformBuilder {
                EaseOut(1.5)
                Bias(0.2)
            }
        }
        
        // Generate samples
        let samples = generateSamples(modulatedWave, count: 1000)
        // Do something with samples...
    }
    
    // MARK: Helper Methods
    
    /// Helper to generate samples from a waveform
    private func generateSamples(_ op: Crvs.FloatOp, count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        
        for i in 0..<count {
            let pos = Float(i) / Float(count)
            samples[i] = op(pos)
        }
        
        return samples
    }
    
    /// Helper to animate a view using a waveform curve
    private func animateView(curve: Crvs.FloatOp, duration: TimeInterval, animations: @escaping () -> Void) {
        // Start animation
        let startTime = Date()
        
        // Set up a timer or CADisplayLink to drive the animation
        let timer = Timer(timeInterval: 1/60, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            
            if elapsed >= duration {
                // Animation complete
                animations()
                timer.invalidate()
                return
            }
            
            // Calculate progress
            let progress = Float(elapsed / duration)
            
            // Apply the curve
            let easedProgress = curve(progress)
            
            // Apply to animation parameters
            // (would set view properties based on easedProgress)
        }
        
        RunLoop.main.add(timer, forMode: .common)
    }
}

// MARK: - SwiftUI Integration Example

struct WaveformDSLSwiftUIExample: View {
    
    // Waveform operations
    let ops = Crvs.Ops()
    
    // Animation properties
    @State private var animationProgress: Double = 0.0
    let animationDuration: Double = 2.0
    
    // Create animation curves using DSL
    let animationCurves: [String: Crvs.FloatOp] = [
        "Linear": WaveformBuilder { IdentityNode() },
        "EaseIn": WaveformBuilder { EaseIn(2.5) },
        "EaseOut": WaveformBuilder { EaseOut(2.5) },
        "EaseInOut": WaveformBuilder { EaseInOut(2.5) },
        "Bounce": WaveformBuilder {
            EaseOut(2.0)
            Ring(
                IdentityNode(),
                Sine().rate(8.0).multiply(0.2).bias(0.9)
            )
        },
        "Elastic": WaveformBuilder {
            EaseOut(1.5)
            Ring(
                IdentityNode(),
                Sine().rate(12.0).multiply(0.3).phase(0.25)
            )
        }
    ]
    
    // Currently selected curve
    @State private var selectedCurve: String = "EaseInOut"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Animation Curve Visualizer")
                .font(.largeTitle)
                .padding(.top, 20)
            
            // Select animation curve
            Picker("Animation Curve", selection: $selectedCurve) {
                ForEach(Array(animationCurves.keys).sorted(), id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Visualize the curve
            CurveVisualizerView(curve: animationCurves[selectedCurve]!)
                .frame(height: 200)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            // Show an animated box
            AnimatedBoxView(progress: animationProgress)
                .padding(.vertical, 40)
            
            // Animation controls
            Button(action: {
                withAnimation(.linear(duration: animationDuration)) {
                    animationProgress = animationProgress >= 0.99 ? 0.0 : 1.0
                }
            }) {
                Text(animationProgress >= 0.99 ? "Reset" : "Animate")
                    .font(.headline)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - SwiftUI Supporting Views

/// Visualizes an animation curve
struct CurveVisualizerView: View {
    let curve: Crvs.FloatOp
    let pointCount = 100
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Draw the curve
            Path { path in
                // Start at the beginning of the curve
                path.move(to: CGPoint(x: 0, y: height))
                
                // Draw points along the curve
                for i in 0..<pointCount {
                    let x = width * CGFloat(i) / CGFloat(pointCount - 1)
                    let pos = Float(i) / Float(pointCount - 1)
                    let value = curve(pos)
                    let y = height - height * CGFloat(value)
                    
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.blue, lineWidth: 3)
            
            // Draw the grid
            Path { path in
                // Horizontal lines
                for i in 0...4 {
                    let y = height * CGFloat(i) / 4.0
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                
                // Vertical lines
                for i in 0...4 {
                    let x = width * CGFloat(i) / 4.0
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        }
    }
}

/// An animated box that moves based on the animation progress
struct AnimatedBoxView: View {
    let progress: Double
    
    // Get actual animation curves using DSL
    let curve: Crvs.FloatOp = WaveformBuilder {
        EaseInOut(2.5)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            // Apply our custom curve to the progress
            let easedProgress = curve(Float(progress))
            let xPosition = CGFloat(easedProgress) * (width - 100)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue)
                .frame(width: 100, height: 50)
                .offset(x: xPosition)
        }
        .frame(height: 50)
    }
}

// MARK: - Audio Example

/// Example class showing DSL usage for audio synthesis
class AudioSynthesizerExample {
    
    // Ops instance
    let ops = Crvs.Ops()
    
    // Create a synthesizer voice using the DSL
    func createSynthVoice(frequency: Float) -> Crvs.FloatOp {
        return WaveformBuilder {
            // Oscillator stack with custom mix
            Mix(
                // Main oscillator
                Sine().rate(frequency / 440.0),
                
                // Detuned oscillator
                Sine().rate(frequency * 1.01 / 440.0).multiply(0.4),
                
                // Sub oscillator
                Square(width: 0.3).rate(frequency * 0.5 / 440.0).multiply(0.3),
                
                weights: [1.0, 0.4, 0.3]
            )
            
            // Apply envelope
            Envelope(
                attack: 0.1,
                decay: 0.2,
                sustain: 0.5,
                sustainLevel: 0.7,
                release: 0.3
            )
            
            // Apply filter effect
            EaseOut(1.8)
            Bias(0.1)
        }
    }
    
    // Create a multi-voice synthesizer
    func createMultiVoiceSynth(frequencies: [Float]) -> [Crvs.FloatOp] {
        return frequencies.map { createSynthVoice(frequency: $0) }
    }
    
    // Generate a chord
    func generateChord() -> Crvs.FloatOp {
        // C major chord (C4, E4, G4)
        let frequencies: [Float] = [261.63, 329.63, 392.0]
        
        let voices = frequencies.map { frequency in
            WaveformBuilder {
                Sine().rate(frequency / 440.0)
                EaseIn(1.5)
                Multiply(0.3)
            }
        }
        
        return WaveformBuilder {
            Mix(voices)
            EaseOut(2.0)
        }
    }
    
    // Generate LFO for modulation
    func createLFO(rate: Float, depth: Float) -> Crvs.FloatOp {
        return WaveformBuilder {
            // Triangle wave LFO
            Triangle()
            
            // Apply rate
            Rate(rate)
            
            // Scale to desired depth
            Multiply(depth)
            
            // Center around 0.5
            Bias(0.5)
        }
    }
    
    // Generate filter modulation
    func createFilterModulation() -> Crvs.FloatOp {
        return WaveformBuilder {
            // Slow LFO
            Sine().rate(0.2)
            
            // Fast vibrato with diminishing effect
            Ring(
                IdentityNode(),
                Sine().rate(5.0).multiply(0.1).bias(0.9)
            )
            
            // Scale and center
            Multiply(0.4)
            Bias(0.3)
        }
    }
}
