import Foundation
import SwiftUI

// Example usage of the Crvs Swift translation
// This showcases how you might use the library in a SwiftUI application

// First, let's create a simple SwiftUI view to visualize the waveforms

struct WaveformView: View {
    let operation: Crvs.Ops.FloatOp
    let color: Color
    
    var body: some View {
        Canvas { context, size in
            let path = createPath(in: size)
            context.stroke(
                path,
                with: .color(color),
                lineWidth: 2.0
            )
        }
        .aspectRatio(4/1, contentMode: .fit)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func createPath(in size: CGSize) -> Path {
        Path { path in
            let steps = 200
            let stepSize = size.width / CGFloat(steps)
            
            // Start at the first point
            let initialY = size.height * (1.0 - CGFloat(operation(0.0)))
            path.move(to: CGPoint(x: 0, y: initialY))
            
            // Add lines for the rest of the points
            for i in 1...steps {
                let x = CGFloat(i) * stepSize
                let pos = Float(i) / Float(steps)
                let y = size.height * (1.0 - CGFloat(operation(pos)))
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}

// A demo view that showcases different waveforms
struct WaveformDemoView: View {
    // Create an instance of our ops class
    let ops = Crvs.Ops()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Crvs Waveform Library")
                    .font(.largeTitle)
                    .padding(.bottom)
                
                Group {
                    sectionTitle("Basic Waveforms")
                    waveformRow("Sine", operation: ops.sine())
                    waveformRow("Triangle", operation: ops.tri())
                    waveformRow("Saw", operation: ops.saw())
                    waveformRow("Square", operation: ops.square())
                }
                
                Group {
                    sectionTitle("Modified Waveforms")
                    waveformRow("Phased Sine", operation: ops.phase(ops.sine(), 0.25))
                    waveformRow("Fast Sine", operation: ops.rate(ops.sine(), 2.0))
                    waveformRow("Sine with Feedback", operation: ops.sineFb(0.5))
                }
                
                Group {
                    sectionTitle("Combined Waveforms")
                    waveformRow("50% Sine + 50% Triangle", 
                                operation: ops.morph(ops.sine(), ops.tri(), ops.c(0.5)))
                    
                    waveformRow("Eased Triangle", 
                                operation: ops.chain([ops.tri(), ops.easeIn(2.0)]))
                }
                
                Group {
                    sectionTitle("Complex Waveforms")
                    
                    // Create a complex modulated waveform
                    let modulator = ops.sine(ops.c(0.2))
                    let carrier = ops.tri(modulator)
                    waveformRow("Modulated Triangle", operation: carrier)
                    
                    // Create a sequence of operations
                    let sequence = ops.chain([
                        ops.sine(),
                        ops.easeOut(3.0),
                        ops.phase(ops.c(0.2))
                    ])
                    waveformRow("Operation Chain", operation: sequence)
                    
                    // Amplitude modulation example
                    let am = { (pos: Float) -> Float in
                        let carrier = ops.sine()(pos * 8.0)
                        let modulator = ops.sine()(pos)
                        return carrier * modulator
                    }
                    waveformRow("Amplitude Modulation", operation: am)
                }
            }
            .padding()
        }
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 5)
    }
    
    private func waveformRow(_ title: String, operation: @escaping Crvs.Ops.FloatOp) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .fontWeight(.medium)
            WaveformView(operation: operation, color: randomColor())
        }
    }
    
    private func randomColor() -> Color {
        let colors: [Color] = [.blue, .green, .red, .orange, .purple, .pink]
        return colors.randomElement() ?? .blue
    }
}

// This is how you would use the library in your iOS/macOS app
// Simply create an instance of Crvs.Ops and call the various function generators

struct ContentView: View {
    var body: some View {
        WaveformDemoView()
    }
}

// Preview the UI for SwiftUI
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

// Additional examples showing how to use the library for audio synthesis

class AudioSynthExample {
    let ops = Crvs.Ops()
    let sampleRate: Double = 44100.0
    
    // Generate a buffer of audio samples using a waveform
    func generateSamples(waveform: @escaping Crvs.Ops.FloatOp, 
                        frequency: Float, 
                        duration: Float) -> [Float] {
        
        let numSamples = Int(Float(sampleRate) * duration)
        var samples = [Float](repeating: 0.0, count: numSamples)
        
        // Create a phasor that cycles at the requested frequency
        let cycleDuration = 1.0 / Double(frequency)
        let timePhasor = ops.timePhasor(cycleDurationSeconds: cycleDuration)
        
        // Generate samples
        for i in 0..<numSamples {
            let time = Float(i) / Float(sampleRate)
            // Convert unipolar (0-1) to bipolar (-1 to 1) for audio
            samples[i] = waveform(timePhasor(time)) * 2.0 - 1.0
        }
        
        return samples
    }
    
    // Example of creating an FM synthesis patch
    func createFMSynthPatch(carrierFreq: Float, modulatorFreq: Float, modulationIndex: Float) -> Crvs.Ops.FloatOp {
        // Carrier and modulator oscillators
        let carrier = ops.sine()
        let modulator = ops.sine()
        
        // Create the time-based phasors
        let carrierPhasor = ops.timePhasor(cycleDurationSeconds: 1.0 / Double(carrierFreq))
        let modulatorPhasor = ops.timePhasor(cycleDurationSeconds: 1.0 / Double(modulatorFreq))
        
        // Return the composite operation
        return { time in
            let modValue = modulator(modulatorPhasor(time))
            let modAmount = modulationIndex * modValue
            let modPos = carrierPhasor(time) + modAmount
            let adjustedPos = modPos.truncatingRemainder(dividingBy: 1.0) 
            return carrier(adjustedPos)
        }
    }
}

// Example showing animation with Crvs
class AnimationExample {
    let ops = Crvs.Ops()
    
    // Create an easing animation curve for UI transitions
    func createAnimationCurve(type: String) -> Crvs.Ops.FloatOp {
        switch type {
        case "easeIn":
            return ops.easeIn(2.5)
        case "easeOut":
            return ops.easeOut(2.5)
        case "easeInOut":
            return ops.easeInOut(2.5)
        case "elastic":
            // Create a custom "elastic" curve
            return { pos in
                let p = max(0.0, min(1.0, pos))
                let value = 1.0 - pow(1.0 - p, 3.0) // Base ease-out cubic
                let oscillation = sin(p * Float.pi * 8) * 0.1 * (1.0 - p) // Oscillation that diminishes
                return value + oscillation
            }
        default:
            return ops.phasor() // Linear
        }
    }
    
    // Apply animation curves to movement
    func animate(from start: CGPoint, to end: CGPoint, duration: TimeInterval, curve: Crvs.Ops.FloatOp, 
                update: @escaping (CGPoint) -> Void, completion: @escaping () -> Void) {
        
        let startTime = Date()
        
        // Create a timer that fires frequently
        let timer = Timer(timeInterval: 1.0/60.0, repeats: true) { timer in
            let elapsedTime = Date().timeIntervalSince(startTime)
            let progress = Float(min(elapsedTime / duration, 1.0))
            
            if progress >= 1.0 {
                timer.invalidate()
                update(end)
                completion()
                return
            }
            
            // Apply the animation curve to the linear progress
            let easedProgress = curve(progress)
            
            // Interpolate between start and end points
            let currentX = start.x + CGFloat(easedProgress) * (end.x - start.x)
            let currentY = start.y + CGFloat(easedProgress) * (end.y - start.y)
            
            // Update the position
            update(CGPoint(x: currentX, y: currentY))
        }
        
        // Add the timer to the run loop
        RunLoop.main.add(timer, forMode: .common)
    }
}
