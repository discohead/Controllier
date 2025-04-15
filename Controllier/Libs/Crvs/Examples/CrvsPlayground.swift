import Foundation
import SwiftUI
import PlaygroundSupport

// MARK: - Playground Support Framework

/// Main framework for Playground integration with Crvs
public class CrvsPlayground {
    
    // MARK: - Core Setup
    
    /// Initialize a playground with standard setup
    public static func setup() {
        // Set playground to continue running indefinitely
        PlaygroundPage.current.needsIndefiniteExecution = true
        
        // Display welcome message
        print("Crvs Playground Ready!")
        print("Create waveforms with the ops object:")
        print("let sine = ops.sine()")
        print("visualize(sine, \"Sine Wave\")")
    }
    
    /// Shared ops instance
    public static let ops = Crvs.Ops()
    
    /// Shared factory instances
    public static let opFactory = OpFactory()
    public static let rhythmFactory = RhythmFactory()
    public static let patternFactory = PatternFactory()
    
    // MARK: - Visualization Functions
    
    /// Visualize a waveform in the playground
    public static func visualize(_ op: Crvs.FloatOp, 
                              _ title: String = "Waveform", 
                              sampleCount: Int = 200) {
        let view = WaveformView(operation: op, title: title, sampleCount: sampleCount)
        PlaygroundPage.current.setLiveView(view)
    }
    
    /// Visualize multiple waveforms together in the playground
    public static func visualizeMultiple(_ ops: [(op: Crvs.FloatOp, title: String, color: Color)],
                                      overallTitle: String = "Waveforms",
                                      sampleCount: Int = 200) {
        let view = MultiWaveformView(operations: ops, title: overallTitle, sampleCount: sampleCount)
        PlaygroundPage.current.setLiveView(view)
    }
    
    /// Visualize a rhythm pattern in the playground
    public static func visualizeRhythm(_ op: Crvs.FloatOp,
                                    _ title: String = "Rhythm Pattern",
                                    steps: Int = 16) {
        let view = RhythmPatternView(rhythmOp: op, title: title, steps: steps)
        PlaygroundPage.current.setLiveView(view)
    }
    
    /// Visualize multiple rhythm patterns together
    public static func visualizeRhythms(_ ops: [(op: Crvs.FloatOp, title: String, color: Color)],
                                     overallTitle: String = "Rhythm Patterns",
                                     steps: Int = 16) {
        let view = MultiRhythmView(rhythms: ops, title: overallTitle, steps: steps)
        PlaygroundPage.current.setLiveView(view)
    }
    
    // MARK: - Audio Playback
    
    /// Play a waveform as audio
    public static func play(_ op: Crvs.FloatOp, 
                         duration: TimeInterval = 2.0,
                         frequency: Float = 440.0) {
        // Configure audio engine
        let audioEngine = AudioPlaybackEngine()
        
        // Start playback
        audioEngine.playWaveform(op, frequency: frequency, duration: duration)
        
        // Ensure playback completes before playground stops
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
            audioEngine.stop()
        }
    }
    
    /// Play a rhythm pattern as audio
    public static func playRhythm(_ op: Crvs.FloatOp,
                               tempo: Float = 120.0,
                               duration: TimeInterval = 4.0,
                               sampleName: String = "click") {
        // Configure audio engine
        let audioEngine = AudioPlaybackEngine()
        
        // Start rhythm playback
        audioEngine.playRhythm(op, tempo: tempo, duration: duration, sampleName: sampleName)
        
        // Ensure playback completes before playground stops
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
            audioEngine.stop()
        }
    }
    
    // MARK: - Interactive Components
    
    /// Create an interactive waveform playground with parameter sliders
    public static func interactiveWaveform(baseOp: @escaping (Float, Float, Float) -> Crvs.FloatOp,
                                        param1Name: String = "Parameter 1",
                                        param2Name: String = "Parameter 2",
                                        param3Name: String = "Parameter 3",
                                        param1Range: ClosedRange<Float> = 0...1,
                                        param2Range: ClosedRange<Float> = 0...1,
                                        param3Range: ClosedRange<Float> = 0...1,
                                        title: String = "Interactive Waveform") {
        let view = InteractiveWaveformView(
            baseOp: baseOp,
            param1Name: param1Name,
            param2Name: param2Name,
            param3Name: param3Name,
            param1Range: param1Range,
            param2Range: param2Range,
            param3Range: param3Range,
            title: title
        )
        PlaygroundPage.current.setLiveView(view)
    }
    
    /// Create an interactive rhythm playground
    public static func interactiveRhythm(baseOp: @escaping (Float, Float, String) -> Crvs.FloatOp,
                                      styles: [String] = ["straight", "swing", "euclidean", "broken"],
                                      title: String = "Interactive Rhythm") {
        let view = InteractiveRhythmView(
            baseOp: baseOp,
            styles: styles,
            title: title
        )
        PlaygroundPage.current.setLiveView(view)
    }
    
    /// Create a waveform explorer playground using the factory system
    public static func factoryExplorer(title: String = "Waveform Factory Explorer") {
        let view = FactoryExplorerView(title: title)
        PlaygroundPage.current.setLiveView(view)
    }
}

// MARK: - Visualization Views

/// Basic waveform visualization view
struct WaveformView: View {
    let operation: Crvs.FloatOp
    let title: String
    let sampleCount: Int
    let color: Color
    
    init(operation: Crvs.FloatOp, title: String, sampleCount: Int = 200, color: Color = .blue) {
        self.operation = operation
        self.title = title
        self.sampleCount = sampleCount
        self.color = color
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            WaveformGraph(operation: operation, sampleCount: sampleCount, color: color)
                .frame(minHeight: 300)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
        }
        .frame(maxWidth: 800, maxHeight: 400)
    }
}

/// Multiple waveform visualization view
struct MultiWaveformView: View {
    let operations: [(op: Crvs.FloatOp, title: String, color: Color)]
    let title: String
    let sampleCount: Int
    
    init(operations: [(op: Crvs.FloatOp, title: String, color: Color)], 
         title: String, sampleCount: Int = 200) {
        self.operations = operations
        self.title = title
        self.sampleCount = sampleCount
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            VStack(spacing: 20) {
                ForEach(0..<operations.count, id: \.self) { i in
                    VStack {
                        Text(operations[i].title)
                            .font(.headline)
                        
                        WaveformGraph(
                            operation: operations[i].op,
                            sampleCount: sampleCount,
                            color: operations[i].color
                        )
                        .frame(height: 150)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: 800, maxHeight: 600)
    }
}

/// Waveform graph component
struct WaveformGraph: View {
    let operation: Crvs.FloatOp
    let sampleCount: Int
    let color: Color
    
    private var samples: [CGPoint] {
        (0..<sampleCount).map { i in
            let x = CGFloat(i) / CGFloat(sampleCount - 1)
            let pos = Float(i) / Float(sampleCount - 1)
            let y = CGFloat(operation(pos))
            return CGPoint(x: x, y: y)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                GridBackground()
                
                // Waveform
                Path { path in
                    guard let firstPoint = samples.first else { return }
                    
                    let scaled = scalePoints(samples, to: geometry.size)
                    
                    path.move(to: scaled[0])
                    for point in scaled.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, lineWidth: 3)
            }
        }
    }
    
    private func scalePoints(_ points: [CGPoint], to size: CGSize) -> [CGPoint] {
        points.map { point in
            CGPoint(
                x: point.x * size.width,
                y: size.height - (point.y * size.height)
            )
        }
    }
}

/// Grid background for graphs
struct GridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Horizontal lines
                for i in 0...4 {
                    let y = CGFloat(i) / 4.0 * geometry.size.height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                
                // Vertical lines
                for i in 0...4 {
                    let x = CGFloat(i) / 4.0 * geometry.size.width
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        }
    }
}

/// Rhythm pattern visualization
struct RhythmPatternView: View {
    let rhythmOp: Crvs.FloatOp
    let title: String
    let steps: Int
    
    private var pattern: [Bool] {
        (0..<steps).map { i in
            let pos = Float(i) / Float(steps)
            return rhythmOp(pos) > 0.5
        }
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            HStack(spacing: 4) {
                ForEach(0..<steps, id: \.self) { step in
                    RhythmStep(active: pattern[step], stepNumber: step)
                }
            }
            .padding()
            
            // Text representation
            Text(pattern.map { $0 ? "X" : "." }.joined())
                .font(.system(.headline, design: .monospaced))
                .padding()
        }
        .frame(maxWidth: 800, maxHeight: 200)
    }
}

/// Multiple rhythm pattern visualization
struct MultiRhythmView: View {
    let rhythms: [(op: Crvs.FloatOp, title: String, color: Color)]
    let title: String
    let steps: Int
    
    init(rhythms: [(op: Crvs.FloatOp, title: String, color: Color)],
         title: String, steps: Int = 16) {
        self.rhythms = rhythms
        self.title = title
        self.steps = steps
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            VStack(spacing: 20) {
                ForEach(0..<rhythms.count, id: \.self) { i in
                    VStack(alignment: .leading) {
                        Text(rhythms[i].title)
                            .font(.headline)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<steps, id: \.self) { step in
                                let active = isStepActive(rhythm: rhythms[i].op, step: step)
                                RhythmStep(active: active, stepNumber: step, color: rhythms[i].color)
                            }
                        }
                        
                        // Text representation
                        Text((0..<steps).map { step in
                            isStepActive(rhythm: rhythms[i].op, step: step) ? "X" : "."
                        }.joined())
                        .font(.system(.subheadline, design: .monospaced))
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .frame(maxWidth: 800, maxHeight: 600)
    }
    
    private func isStepActive(rhythm: Crvs.FloatOp, step: Int) -> Bool {
        let pos = Float(step) / Float(steps)
        return rhythm(pos) > 0.5
    }
}

/// Single rhythm step visualization
struct RhythmStep: View {
    let active: Bool
    let stepNumber: Int
    let color: Color
    
    init(active: Bool, stepNumber: Int, color: Color = .blue) {
        self.active = active
        self.stepNumber = stepNumber
        self.color = color
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(active ? color : Color.gray.opacity(0.2))
                .frame(width: 30, height: 60)
                .cornerRadius(4)
            
            if stepNumber % 4 == 0 {
                Text("\(stepNumber + 1)")
                    .font(.caption)
                    .foregroundColor(active ? .white : .black)
            }
        }
    }
}

// MARK: - Interactive Views

/// Interactive waveform view with parameter sliders
struct InteractiveWaveformView: View {
    let baseOp: (Float, Float, Float) -> Crvs.FloatOp
    let param1Name: String
    let param2Name: String
    let param3Name: String
    let param1Range: ClosedRange<Float>
    let param2Range: ClosedRange<Float>
    let param3Range: ClosedRange<Float>
    let title: String
    
    @State private var param1Value: Float
    @State private var param2Value: Float
    @State private var param3Value: Float
    
    init(baseOp: @escaping (Float, Float, Float) -> Crvs.FloatOp,
         param1Name: String = "Parameter 1",
         param2Name: String = "Parameter 2",
         param3Name: String = "Parameter 3",
         param1Range: ClosedRange<Float> = 0...1,
         param2Range: ClosedRange<Float> = 0...1,
         param3Range: ClosedRange<Float> = 0...1,
         title: String = "Interactive Waveform") {
        
        self.baseOp = baseOp
        self.param1Name = param1Name
        self.param2Name = param2Name
        self.param3Name = param3Name
        self.param1Range = param1Range
        self.param2Range = param2Range
        self.param3Range = param3Range
        self.title = title
        
        // Initialize with midpoint values
        self._param1Value = State(initialValue: (param1Range.lowerBound + param1Range.upperBound) / 2)
        self._param2Value = State(initialValue: (param2Range.lowerBound + param2Range.upperBound) / 2)
        self._param3Value = State(initialValue: (param3Range.lowerBound + param3Range.upperBound) / 2)
    }
    
    var currentOperation: Crvs.FloatOp {
        baseOp(param1Value, param2Value, param3Value)
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            WaveformGraph(operation: currentOperation, sampleCount: 200, color: .blue)
                .frame(height: 200)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
            
            VStack(spacing: 20) {
                ParameterSlider(
                    name: param1Name,
                    value: $param1Value,
                    range: param1Range
                )
                
                ParameterSlider(
                    name: param2Name,
                    value: $param2Value,
                    range: param2Range
                )
                
                ParameterSlider(
                    name: param3Name,
                    value: $param3Value,
                    range: param3Range
                )
            }
            .padding()
            
            Button("Play") {
                CrvsPlayground.play(currentOperation)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
        }
        .frame(maxWidth: 800, maxHeight: 600)
    }
}

/// Parameter slider component
struct ParameterSlider: View {
    let name: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(name): \(String(format: "%.2f", value))")
                .font(.headline)
            
            HStack {
                Text("\(String(format: "%.2f", range.lowerBound))")
                    .font(.caption)
                
                Slider(value: $value, in: range)
                
                Text("\(String(format: "%.2f", range.upperBound))")
                    .font(.caption)
            }
        }
    }
}

/// Interactive rhythm view
struct InteractiveRhythmView: View {
    let baseOp: (Float, Float, String) -> Crvs.FloatOp
    let styles: [String]
    let title: String
    
    @State private var density: Float = 0.5
    @State private var complexity: Float = 0.5
    @State private var selectedStyle: String
    
    init(baseOp: @escaping (Float, Float, String) -> Crvs.FloatOp,
         styles: [String] = ["straight", "swing", "euclidean", "broken"],
         title: String = "Interactive Rhythm") {
        
        self.baseOp = baseOp
        self.styles = styles
        self.title = title
        self._selectedStyle = State(initialValue: styles.first ?? "straight")
    }
    
    var currentRhythm: Crvs.FloatOp {
        baseOp(density, complexity, selectedStyle)
    }
    
    private var pattern: [Bool] {
        (0..<16).map { i in
            let pos = Float(i) / 16.0
            return currentRhythm(pos) > 0.5
        }
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { step in
                    RhythmStep(active: pattern[step], stepNumber: step)
                }
            }
            .padding()
            
            VStack(spacing: 20) {
                ParameterSlider(
                    name: "Density",
                    value: $density,
                    range: 0...1
                )
                
                ParameterSlider(
                    name: "Complexity",
                    value: $complexity,
                    range: 0...1
                )
                
                HStack {
                    Text("Style:")
                        .font(.headline)
                    
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(styles, id: \.self) { style in
                            Text(style.capitalized).tag(style)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding()
            
            HStack(spacing: 20) {
                Button("Play") {
                    CrvsPlayground.playRhythm(currentRhythm)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Generate New") {
                    density = Float.random(in: 0.2...0.8)
                    complexity = Float.random(in: 0.2...0.8)
                    selectedStyle = styles.randomElement() ?? styles.first!
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
        .frame(maxWidth: 800, maxHeight: 600)
    }
}

/// Factory explorer view
struct FactoryExplorerView: View {
    let title: String
    
    @State private var currentWaveform: Crvs.FloatOp = CrvsPlayground.ops.sine()
    @State private var complexity: Float = 0.5
    @State private var seed: UInt64 = UInt64.random(in: 1...1000000)
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            WaveformGraph(operation: currentWaveform, sampleCount: 200, color: .blue)
                .frame(height: 200)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
            
            VStack(spacing: 20) {
                ParameterSlider(
                    name: "Complexity",
                    value: $complexity,
                    range: 0...1
                )
                
                HStack {
                    Text("Seed: \(seed)")
                        .font(.headline)
                    
                    Button("Randomize") {
                        seed = UInt64.random(in: 1...1000000)
                        generateNewWaveform()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
            
            HStack(spacing: 20) {
                Button("Generate New") {
                    generateNewWaveform()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Play") {
                    CrvsPlayground.play(currentWaveform)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
        .frame(maxWidth: 800, maxHeight: 600)
        .onAppear {
            generateNewWaveform()
        }
    }
    
    private func generateNewWaveform() {
        let factory = OpFactory(seed: seed)
        currentWaveform = factory.generateOp(complexity: complexity)
    }
}

// MARK: - Audio Playback Engine

/// Simple audio playback engine for Crvs functions
class AudioPlaybackEngine {
    // This is a placeholder for audio functionality
    // In a real implementation, this would interface with AVAudioEngine
    // or another audio system to play the waveforms
    
    func playWaveform(_ op: Crvs.FloatOp, frequency: Float, duration: TimeInterval) {
        print("Playing waveform at \(frequency)Hz for \(duration) seconds")
        // Actual audio implementation would go here
    }
    
    func playRhythm(_ op: Crvs.FloatOp, tempo: Float, duration: TimeInterval, sampleName: String) {
        print("Playing rhythm at \(tempo)BPM for \(duration) seconds using '\(sampleName)' sample")
        // Actual audio implementation would go here
    }
    
    func stop() {
        print("Stopping audio playback")
        // Actual stop implementation would go here
    }
}

// MARK: - Playground Example Presets

/// Collection of preset examples for Playgrounds
public class PlaygroundExamples {
    
    // MARK: - Basic Waveform Examples
    
    /// Simple sine wave example
    public static func sineWaveExample() {
        let ops = Crvs.Ops()
        let sine = ops.sine()
        
        CrvsPlayground.visualize(sine, "Sine Wave")
    }
    
    /// Multiple waveform types example
    public static func basicWaveformsExample() {
        let ops = Crvs.Ops()
        
        CrvsPlayground.visualizeMultiple([
            (op: ops.sine(), title: "Sine Wave", color: .blue),
            (op: ops.tri(), title: "Triangle Wave", color: .green),
            (op: ops.saw(), title: "Saw Wave", color: .red),
            (op: ops.square(), title: "Square Wave", color: .purple)
        ], overallTitle: "Basic Waveforms")
    }
    
    /// Modulation example
    public static func modulationExample() {
        let ops = Crvs.Ops()
        
        // Create modulated sine wave
        let modulatedSine = ops.phase(
            ops.sine(),
            ops.mult(
                ops.sine(ops.c(0.0)),
                0.2
            )
        )
        
        CrvsPlayground.visualize(modulatedSine, "Phase-Modulated Sine Wave")
    }
    
    // MARK: - Rhythm Examples
    
    /// Basic rhythm patterns example
    public static func rhythmPatternsExample() {
        let factory = RhythmFactory()
        
        let straightRhythm = factory.generate(
            density: 0.4,
            complexity: 0.3,
            style: "straight"
        )
        
        let swingRhythm = factory.generate(
            density: 0.4,
            complexity: 0.5,
            style: "swing"
        )
        
        let euclideanRhythm = factory.generate(
            density: 0.5,
            complexity: 0.7,
            style: "euclidean"
        )
        
        CrvsPlayground.visualizeRhythms([
            (op: straightRhythm, title: "Straight Rhythm", color: .blue),
            (op: swingRhythm, title: "Swing Rhythm", color: .green),
            (op: euclideanRhythm, title: "Euclidean Rhythm", color: .orange)
        ], overallTitle: "Rhythm Patterns")
    }
    
    /// Interactive rhythm generator example
    public static func interactiveRhythmExample() {
        CrvsPlayground.interactiveRhythm(
            baseOp: { density, complexity, style in
                let factory = RhythmFactory()
                return factory.generate(
                    density: density,
                    complexity: complexity,
                    style: style
                )
            },
            styles: ["straight", "swing", "euclidean", "broken", "syncopated"]
        )
    }
    
    // MARK: - Factory System Examples
    
    /// Waveform factory explorer example
    public static func factoryExplorerExample() {
        CrvsPlayground.factoryExplorer(title: "Generative Waveform Explorer")
    }
    
    /// Interactive sine wave customization
    public static func interactiveSineExample() {
        CrvsPlayground.interactiveWaveform(
            baseOp: { frequency, feedback, phase in
                let ops = Crvs.Ops()
                return ops.phase(
                    ops.rate(
                        ops.sine(feedback),
                        frequency
                    ),
                    phase
                )
            },
            param1Name: "Frequency",
            param2Name: "Feedback",
            param3Name: "Phase",
            param1Range: 0.5...4.0,
            param2Range: 0.0...0.5,
            param3Range: 0.0...1.0,
            title: "Interactive Sine Wave"
        )
    }
}
