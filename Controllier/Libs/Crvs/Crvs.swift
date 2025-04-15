import Foundation
import CoreGraphics
import simd  // For advanced math operations
import Accelerate // For fast array operations
import GameplayKit // For GKNoise (Perlin noise equivalent)

/// The namespace for Crvs operations
public enum Crvs {
    /// Function type that takes a float position and returns a float value
    public typealias FloatOp = (Float) -> Float
    
    /// The main operations class, providing curve and waveform generation functions
    public class Ops {
        
        // Utility for visualizing waveforms on macOS/iOS
        public struct Visualization {
            /// Basic visualization of an operation as a UIBezierPath or NSBezierPath
            #if os(iOS) || os(tvOS)
            public static func createPath(from op: @escaping FloatOp, width: CGFloat, height: CGFloat, steps: Int = 100) -> UIBezierPath {
                let path = UIBezierPath()
                let stepSize = width / CGFloat(steps)
                
                path.move(to: CGPoint(x: 0, y: height * (1.0 - CGFloat(op(0.0)))))
                
                for i in 1...steps {
                    let x = CGFloat(i) * stepSize
                    let pos = Float(i) / Float(steps)
                    let y = height * (1.0 - CGFloat(op(pos)))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                return path
            }
            #elseif os(macOS)
            public static func createPath(from op: @escaping FloatOp, width: CGFloat, height: CGFloat, steps: Int = 100) -> NSBezierPath {
                let path = NSBezierPath()
                let stepSize = width / CGFloat(steps)
                
                path.move(to: NSPoint(x: 0, y: height * (1.0 - CGFloat(op(0.0)))))
                
                for i in 1...steps {
                    let x = CGFloat(i) * stepSize
                    let pos = Float(i) / Float(steps)
                    let y = height * (1.0 - CGFloat(op(pos)))
                    path.line(to: NSPoint(x: x, y: y))
                }
                
                return path
            }
            #endif
        }
        
        // MARK: - Constants and Conversion Utilities
        
        /// Converts a position (0.0 to 1.0) to radians (0 to 2π)
        public static func pos2Rad(_ pos: Float) -> Float {
            return Float.pi * 2.0 * Swift.max(0.0, Swift.min(1.0, pos))
        }
        
        // MARK: - Constants
        
        /// Returns a constant zero function
        public func zero() -> FloatOp {
            return { _ in 0.0 }
        }
        
        /// Returns a constant 0.25 function
        public func fourth() -> FloatOp {
            return { _ in 0.25 }
        }
        
        /// Returns a constant 1/3 function
        public func third() -> FloatOp {
            return { _ in 1.0 / 3.0 }
        }
        
        /// Returns a constant 0.5 function
        public func half() -> FloatOp {
            return { _ in 0.5 }
        }
        
        /// Returns a constant 1.0 function
        public func one() -> FloatOp {
            return { _ in 1.0 }
        }
        
        /// Returns a constant 2.0 function
        public func two() -> FloatOp {
            return { _ in 2.0 }
        }
        
        /// Returns a constant 3.0 function
        public func three() -> FloatOp {
            return { _ in 3.0 }
        }
        
        /// Returns a constant 4.0 function
        public func four() -> FloatOp {
            return { _ in 4.0 }
        }
        
        /// Returns a constant π/4 function
        public func quarterPi() -> FloatOp {
            return { _ in Float.pi / 4.0 }
        }
        
        /// Returns a constant π/3 function
        public func thirdPi() -> FloatOp {
            return { _ in Float.pi / 3.0 }
        }
        
        /// Returns a constant π/2 function
        public func halfPi() -> FloatOp {
            return { _ in Float.pi / 2.0 }
        }
        
        /// Returns a constant π function
        public func pi() -> FloatOp {
            return { _ in Float.pi }
        }
        
        /// Returns a constant 2π function
        public func twoPi() -> FloatOp {
            return { _ in Float.pi * 2.0 }
        }
        
        // MARK: - Signal Processing
        
        /// Converts a unipolar signal (0-1) to bipolar (-1 to 1)
        public func bipolarize(_ unipolarOp: @escaping FloatOp) -> FloatOp {
            return { pos in 2.0 * unipolarOp(pos) - 1.0 }
        }
        
        /// Converts a bipolar signal (-1 to 1) to unipolar (0-1)
        public func rectify(_ bipolarOp: @escaping FloatOp) -> FloatOp {
            return { pos in bipolarOp(pos) * 0.5 + 0.5 }
        }
        
        /// Creates a constant value function
        public func c(_ value: Float) -> FloatOp {
            return { _ in value }
        }
        
        // MARK: - Time-Based Functions
        
        /// Creates a phasor that cycles based on elapsed time with maximum precision
        public func timePhasor(cycleDurationSeconds: Double = 2.0) -> FloatOp {
            if cycleDurationSeconds <= 0.0 {
                fatalError("cycleDurationSeconds must be greater than 0")
            }
            
            // Use CACurrentMediaTime() for high precision timing with low overhead
            // This is based on mach_absolute_time() and is much more precise than Date()
            let startTime = CACurrentMediaTime()
            
            var lastTime = startTime
            var accumulatedPhase: Double = 0.0
            let phaseIncrement = 1.0 / cycleDurationSeconds
            
            return { _ in
                // Get current time with high precision
                let currentTime = CACurrentMediaTime()
                
                // Calculate time delta since last call
                let deltaTime = currentTime - lastTime
                lastTime = currentTime
                
                // Accumulate phase using precise time delta
                accumulatedPhase += deltaTime * phaseIncrement
                
                // Keep phase in [0.0, 1.0) range without using fmod (which can lose precision)
                while accumulatedPhase >= 1.0 {
                    accumulatedPhase -= 1.0
                }
                
                return Float(accumulatedPhase)
            }
        }
        
        /// Creates a phasor that cycles based on musical tempo with enhanced musical features
        public func tempoPhasor(
            barsPerCycle: Double = 1.0,
            bpm: Double = 120.0,
            timeSignatureNumerator: Int = 4,   // Added time signature support
            timeSignatureDenominator: Int = 4, // Added denominator for compound meters
            startOffset: Double = 0.0          // Allows starting at specific phase point
        ) -> FloatOp {
            if bpm <= 0.0 {
                fatalError("bpm must be greater than 0")
            }
            if barsPerCycle <= 0.0 {
                fatalError("barsPerCycle must be greater than 0")
            }
            if timeSignatureNumerator <= 0 {
                fatalError("timeSignatureNumerator must be greater than 0")
            }
            if ![1, 2, 4, 8, 16, 32].contains(timeSignatureDenominator) {
                fatalError("timeSignatureDenominator must be a power of 2 (1, 2, 4, 8, 16, or 32)")
            }
            
            // Calculate the duration of one beat in seconds based on time signature denominator
            let beatDurationSecs = 60.0 / bpm * (4.0 / Double(timeSignatureDenominator))
            
            // Calculate the duration of one bar
            let barDurationSecs = beatDurationSecs * Double(timeSignatureNumerator)
            
            // Calculate the duration of the entire cycle
            let cycleDurationSecs = barDurationSecs * barsPerCycle
            
            // Track musical context
            var currentBar = 0
            var lastPhase: Double = 0
            
            // Create modified phasor with musical context tracking
            let phasor = timePhasor(cycleDurationSeconds: cycleDurationSecs)
            
            return { pos in
                let rawPhase = Double(phasor(pos))
                let phaseWithOffset = (rawPhase + startOffset).truncatingRemainder(dividingBy: 1.0)
                
                // Track bar changes for possible beat events
                if phaseWithOffset < lastPhase {
                    currentBar = (currentBar + 1) % Int(barsPerCycle)
                }
                lastPhase = phaseWithOffset
                
                return Float(phaseWithOffset)
            }
        }
        
        /// Returns a quantized version of a phasor that snaps to musical divisions
        public func quantizePhasor(phasor: @escaping FloatOp, divisions: Int = 4) -> FloatOp {
            return { pos in
                let rawPhase = phasor(pos)
                let quantized = round(Float(divisions) * rawPhase) / Float(divisions)
                return quantized
            }
        }
        
        /// Gets the current musical position information from a tempo phasor
        public func musicalPosition(phasor: @escaping FloatOp,
                                    barsPerCycle: Double = 1.0,
                                    timeSignatureNumerator: Int = 4) -> (bar: Int, beat: Int, phase: Float) {
            let phase = phasor(0)
            // Convert timeSignatureNumerator to Double for multiplication with barsPerCycle
            let totalBeats = Double(timeSignatureNumerator) * barsPerCycle
            let normalizedPosition = Double(phase) * totalBeats
            
            let currentBar = Int(normalizedPosition / Double(timeSignatureNumerator))
            let currentBeat = Int(normalizedPosition) % timeSignatureNumerator
            
            return (currentBar, currentBeat, phase)
        }
        
        // MARK: - Basic Waveforms
        
        /// Phasor (ramp) wave from 0 to 1
        public func phasor() -> FloatOp {
            return { pos in pos }
        }
        
        /// Saw wave from 1 to 0
        public func saw() -> FloatOp {
            return { pos in 1.0 - pos }
        }
        
        /// Triangle wave with variable symmetry point
        public func tri(_ s: FloatOp? = nil) -> FloatOp {
            return { pos in
                var sValue: Float = 0.5
                if let s = s {
                    sValue = s(pos)
                }
                
                if pos < sValue {
                    return pos / sValue
                } else {
                    return 1.0 - ((pos - sValue) / (1.0 - sValue))
                }
            }
        }
        
        /// Triangle wave with fixed symmetry point
        public func tri(_ s: Float) -> FloatOp {
            return tri(c(s))
        }
        
        /// Sine wave with optional feedback
        public func sine(_ fb: FloatOp? = nil) -> FloatOp {
            return { pos in
                var modPos = pos
                if let fb = fb {
                    let fbScale = fb(modPos)
                    modPos += fbScale * (sin(Self.pos2Rad(modPos)) * 0.5 + 0.5)
                }
                return (sin(Self.pos2Rad(fmod(modPos, 1.0))) * 0.5) + 0.5
            }
        }
        
        /// Sine wave with fixed feedback amount
        public func sine(_ fb: Float) -> FloatOp {
            return sine(c(fb))
        }
        
        /// Sine wave with stateful feedback (memory effect)
        public func sineFb(_ fb: FloatOp? = nil) -> FloatOp {
            var lastFeedback: Float = 0.0
            
            return { pos in
                var modPos = pos
                
                // Calculate the current feedback scale
                let currentFeedback = fb?(pos) ?? 0.0
                
                // Apply the feedback to modPos
                modPos += lastFeedback
                
                // Compute the sine wave with modulated position
                let output = (sin(Self.pos2Rad(fmod(modPos, 1.0))) * 0.5) + 0.5
                
                // Update the lastFeedback for the next call
                lastFeedback = currentFeedback * output
                
                return output
            }
        }
        
        /// Sine wave with fixed stateful feedback
        public func sineFb(_ fb: Float) -> FloatOp {
            var lastFeedback: Float = 0.0
            
            return { pos in
                var modPos = pos
                
                // Apply the feedback to modPos
                modPos += lastFeedback
                
                // Compute the sine wave with modulated position
                let output = (sin(Self.pos2Rad(fmod(modPos, 1.0))) * 0.5) + 0.5
                
                // Update the lastFeedback for the next call
                lastFeedback = fb * output
                
                return output
            }
        }
        
        /// Arc sine function (normalized)
        public func asin() -> FloatOp {
            return { pos in
                let modPos = pos * 2.0 - 1.0
                return (_math.asin(modPos) + Float.pi/2) / Float.pi
            }
        }
        
        /// Cosine wave with optional feedback
        public func cos(_ fb: FloatOp? = nil) -> FloatOp {
            return { pos in
                var modPos = pos
                if let fb = fb {
                    let fbScale = fb(pos)
                    modPos += fbScale * (_math.cos(Self.pos2Rad(modPos)) * 0.5 + 0.5)
                }
                return (_math.cos(Self.pos2Rad(fmod(modPos, 1.0))) * 0.5) + 0.5
            }
        }
        
        /// Cosine wave with fixed feedback
        public func cos(_ fb: Float) -> FloatOp {
            return cos(c(fb))
        }
        
        /// Arc cosine function (normalized)
        public func acos() -> FloatOp {
            return { pos in
                let modPos = pos * 2.0 - 1.0
                return _math.acos(modPos) / Float.pi
            }
        }
        
        /// Tangent wave with optional feedback
        public func tan(_ fb: FloatOp? = nil) -> FloatOp {
            return { pos in
                var modPos = pos
                if let fb = fb {
                    let fbScale = fb(pos)
                    modPos += fbScale * (_math.tan(Self.pos2Rad(modPos)) * 0.5 + 0.5)
                }
                // Clamp the value to avoid extreme values
                let rawValue = _math.tan(Self.pos2Rad(fmod(modPos, 1.0)))
                let clampedValue = Swift.min(10.0, Swift.max(-10.0, rawValue)) // Avoid infinity
                return (clampedValue * 0.5) + 0.5
            }
        }
        
        /// Tangent wave with fixed feedback
        public func tan(_ fb: Float) -> FloatOp {
            return tan(c(fb))
        }
        
        // MARK: - Pulse and Square Waves
        
        /// Pulse wave with variable width
        public func pulse(_ w: FloatOp? = nil) -> FloatOp {
            return { pos in
                var wValue: Float = 0.5
                if let w = w {
                    wValue = w(pos)
                }
                return pos < wValue ? 0.0 : 1.0
            }
        }
        
        /// Pulse wave with fixed width
        public func pulse(_ w: Float) -> FloatOp {
            return pulse(c(w))
        }
        
        /// Pulse wave using a custom input signal and a fixed width threshold.
        public func pulse(_ input: @escaping FloatOp, _ width: Float) -> FloatOp {
            return { pos in
                // Evaluate the custom input signal.
                let signal = input(pos)
                // Return 0.0 if the signal is below the width threshold, else 1.0.
                return signal < width ? 0.0 : 1.0
            }
        }
        
        /// Pulse wave using a custom input signal and a variable width threshold.
        public func pulse(_ input: @escaping FloatOp, _ width: @escaping FloatOp) -> FloatOp {
            return { pos in
                // Evaluate the custom input signal.
                let signal = input(pos)
                // Evaluate the width threshold.
                let w = width(pos)
                // Return 0.0 if the signal is below the width threshold, else 1.0.
                return signal < w ? 0.0 : 1.0
            }
        }
        
        
        /// Square wave (50% duty cycle pulse)
        public func square() -> FloatOp {
            return pulse()
        }
        
        // MARK: - Easing Functions
        
        /// Easing in (accelerating) function
        public func easeIn(_ e: FloatOp? = nil) -> FloatOp {
            return { pos in
                var eValue: Float = 2.0
                if let e = e {
                    eValue = e(pos)
                }
                return pow(pos, eValue)
            }
        }
        
        /// Easing in with fixed exponent
        public func easeIn(_ e: Float) -> FloatOp {
            return easeIn(c(e))
        }
        
        /// Easing out (decelerating) function
        public func easeOut(_ e: FloatOp? = nil) -> FloatOp {
            return { pos in
                var eValue: Float = 3.0
                if let e = e {
                    eValue = e(pos)
                }
                return 1.0 - pow(1.0 - pos, eValue)
            }
        }
        
        /// Easing out with fixed exponent
        public func easeOut(_ e: Float) -> FloatOp {
            return easeOut(c(e))
        }
        
        /// Easing in and out (accelerate then decelerate)
        public func easeInOut(_ e: FloatOp? = nil) -> FloatOp {
            return { pos in
                let value = pos * 2.0
                var eValue: Float = 3.0
                if let e = e {
                    eValue = e(pos)
                }
                
                if value < 1.0 {
                    return 0.5 * pow(value, eValue)
                } else {
                    return 0.5 * (2.0 - pow(2.0 - value, eValue))
                }
            }
        }
        
        /// Easing in and out with fixed exponent
        public func easeInOut(_ e: Float) -> FloatOp {
            return easeInOut(c(e))
        }
        
        /// Easing out and in (decelerate then accelerate)
        public func easeOutIn(_ e: FloatOp? = nil) -> FloatOp {
            return { pos in
                var value = pos * 2.0
                var eValue: Float = 3.0
                if let e = e {
                    eValue = e(pos)
                }
                
                if value < 1.0 {
                    return (1.0 - pow(1.0 - value, eValue) * 0.5) - 0.5
                } else {
                    value = value - 1.0
                    return (pow(value, eValue) * 0.5) + 0.5
                }
            }
        }
        
        /// Easing out and in with fixed exponent
        public func easeOutIn(_ e: Float) -> FloatOp {
            return easeOutIn(c(e))
        }
        
        // MARK: - Envelope Functions
        
        /// ADSR (Attack, Decay, Sustain, Release) envelope generator
        public func env(attackLength: Float, attackLevel: Float, 
                        decayLength: Float, sustainLength: Float, 
                        sustainLevel: Float, releaseLength: Float) -> FloatOp {
            
            return { pos in
                if pos <= attackLength {
                    return attackLevel * (pos / attackLength)
                } else if pos <= attackLength + decayLength {
                    return attackLevel + ((pos - attackLength) / decayLength * (sustainLevel - attackLevel))
                } else if pos <= attackLength + decayLength + sustainLength {
                    return sustainLevel
                } else if pos <= attackLength + decayLength + sustainLength + releaseLength {
                    return sustainLevel - ((pos - (attackLength + decayLength + sustainLength)) / releaseLength * sustainLevel)
                } else {
                    return 0.0
                }
            }
        }
        
        /// Creates a function from breakpoints
        public func breakpoints(_ points: [[Float]]) -> FloatOp {
            return { pos in
                for i in 0..<points.count {
                    if pos < points[i][0] {
                        if i == 0 {
                            return points[i][1]
                        }
                        
                        let prevPos = points[i-1][0]
                        let prevVal = points[i-1][1]
                        let nextPos = points[i][0]
                        let nextVal = points[i][1]
                        let fraction = (pos - prevPos) / (nextPos - prevPos)
                        
                        return prevVal + (fraction * (nextVal - prevVal))
                    }
                }
                
                // If we get here, return the last value
                return points.last?[1] ?? 0.0
            }
        }
        
        /// Multi-stage envelope with arbitrary breakpoints
        public func multiStageEnv(_ stages: [(duration: Float, level: Float)],
                                  _ curve: Float = 2.0) -> FloatOp {
            return { pos in
                var totalDuration: Float = 0
                
                // Calculate total duration
                for stage in stages {
                    totalDuration += stage.duration
                }
                
                // Find current stage
                let currentTime: Float = pos * totalDuration
                var prevStage: (time: Float, level: Float) = (0, stages.first?.level ?? 0)
                
                for stage in stages {
                    let stageEnd = prevStage.time + stage.duration
                    
                    if currentTime <= stageEnd {
                        // Found the current stage
                        let stagePos = (currentTime - prevStage.time) / stage.duration
                        
                        // Apply curve
                        let curvedPos = curve > 1 ?
                        pow(stagePos, curve) :
                        1 - pow(1 - stagePos, 1/curve)
                        
                        // Interpolate
                        return prevStage.level + (stage.level - prevStage.level) * curvedPos
                    }
                    
                    // Move to next stage
                    prevStage = (stageEnd, stage.level)
                }
                
                // Past all stages
                return stages.last?.level ?? 0
            }
        }
        
        // MARK: - Utility Functions
        
        /// Maps a value from one range to another
        public func map(_ value: Float, _ inMin: Float, _ inMax: Float, _ outMin: Float, _ outMax: Float) -> Float {
            return outMin + (outMax - outMin) * ((value - inMin) / (inMax - inMin))
        }
        
        /// Returns a random Float between 0 and max
        public func random(_ max: Float = 1.0) -> Float {
            return Float.random(in: 0...max)
        }
        
        /// Returns a random Float in a range
        public func random(in range: ClosedRange<Float>) -> Float {
            return Float.random(in: range)
        }
        
        /// Linearly interpolates between two values
        public func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
            return a + (b - a) * t
        }
        
        // MARK: - Basic Modification Operations
        
        /// Takes the absolute value of an operation
        public func abs(_ op: @escaping FloatOp) -> FloatOp {
            return { pos in Swift.abs(op(pos)) }
        }
        
        /// Computes the difference between two operations
        public func diff(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp) -> FloatOp {
            return { pos in opA(pos) - opB(pos) }
        }
        
        /// Multiplies an operation by a scalar
        public func mult(_ op: @escaping FloatOp, _ scalar: Float) -> FloatOp {
            return { pos in op(pos) * scalar }
        }
        
        /// Adds an offset to an operation
        public func bias(_ op: @escaping FloatOp, _ offset: Float) -> FloatOp {
            return { pos in op(pos) + offset }
        }
        
        /// Adds a variable offset to an operation
        public func bias(_ op: @escaping FloatOp, _ offset: @escaping FloatOp) -> FloatOp {
            return { pos in op(pos) + offset(pos) }
        }
        
        /// Shifts the phase of an operation
        public func phase(_ op: @escaping FloatOp, _ phaseOffset: Float) -> FloatOp {
            return { pos in
                var modPos = pos + phaseOffset
                if modPos > 1.0 {
                    modPos = fmod(modPos, 1.0)
                }
                return op(modPos)
            }
        }
        
        /// Shifts the phase by a variable amount
        public func phase(_ op: @escaping FloatOp, _ phaseOffset: @escaping FloatOp) -> FloatOp {
            return { pos in
                var modPos = pos + phaseOffset(pos)
                if modPos > 1.0 {
                    modPos = fmod(modPos, 1.0)
                }
                return op(modPos)
            }
        }
        
        /// Modifies the rate of an operation
        public func rate(_ op: @escaping FloatOp, _ rateOffset: Float) -> FloatOp {
            var lastPos: Float = 0.0
            var accumulatedPos: Float = 0.0
            
            return { pos in
                var deltaPos = pos - lastPos
                lastPos = pos
                
                if deltaPos < 0.0 {
                    deltaPos += 1.0
                }
                
                let modDelta = deltaPos * rateOffset
                accumulatedPos += modDelta
                
                if accumulatedPos > 1.0 {
                    accumulatedPos = fmod(accumulatedPos, 1.0)
                }
                
                return op(accumulatedPos)
            }
        }
        
        /// Modifies the rate by a variable amount
        public func rate(_ op: @escaping FloatOp, _ rateOffset: @escaping FloatOp) -> FloatOp {
            var lastPos: Float = 0.0
            var accumulatedPos: Float = 0.0
            
            return { pos in
                var deltaPos = pos - lastPos
                lastPos = pos
                
                if deltaPos < 0.0 {
                    deltaPos += 1.0
                }
                
                let modDelta = deltaPos * rateOffset(pos)
                accumulatedPos += modDelta
                
                if accumulatedPos > 1.0 {
                    accumulatedPos = fmod(accumulatedPos, 1.0)
                }
                
                return op(accumulatedPos)
            }
        }
        
        /// Ring modulation (multiplication) of two operations
        public func ring(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp) -> FloatOp {
            return { pos in opA(pos) * opB(pos) }
        }
        
        // MARK: - Signal Processing
        
        /// Folds a signal when it exceeds a threshold
        public func fold(_ op: @escaping FloatOp, _ threshold: Float = 1.0) -> FloatOp {
            return { pos in
                var val = op(pos)
                while val > threshold {
                    val = threshold - (val - threshold)
                }
                return val
            }
        }
        
        /// Folds a signal when it exceeds a variable threshold
        public func fold(_ op: @escaping FloatOp, _ threshold: @escaping FloatOp) -> FloatOp {
            return { pos in
                var val = op(pos)
                let thresh = threshold(pos)
                while val > thresh {
                    val = thresh - (val - thresh)
                }
                return val
            }
        }
        
        /// Wraps a signal to stay between min and max
        public func wrap(_ op: @escaping FloatOp, _ min: Float, _ max: Float) -> FloatOp {
            return { pos in
                let val = op(pos)
                if val < min {
                    return max - (min - val)
                } else if val > max {
                    return min + (val - max)
                }
                return val
            }
        }
        
        /// Applies a low-pass filter to an operation
        public func lpf(_ inputOp: @escaping FloatOp, _ windowSize: Int) -> FloatOp {
            return { pos in
                var sum: Float = 0.0
                for i in 0..<windowSize {
                    let offsetPos = pos - (Float(i) / Float(windowSize))
                    let clampedPos = Swift.max(0.0, Swift.min(1.0, offsetPos))
                    sum += inputOp(clampedPos)
                }
                return sum / Float(windowSize)
            }
        }
        
        /// Low-pass filter with feedback and resonance
        public func lpFb(_ smoothing: Float, _ resonance: Float) -> FloatOp {
            var lastOutput: Float = 0.0
            
            return { input in
                // Calculate the feedback amount
                let feedback = resonance * lastOutput
                
                // Apply the low-pass filter formula with resonance
                lastOutput = smoothing * (input + feedback) + (1.0 - smoothing) * lastOutput
                
                // Ensure the output is bounded
                lastOutput = Swift.min(1.0, Swift.max(-1.0, lastOutput))
                
                return lastOutput
            }
        }
        
        /// Exponential moving average
        public func ema(_ smoothingFactor: Float) -> FloatOp {
            var lastOutput: Float = 0.0
            
            return { pos in
                lastOutput = smoothingFactor * pos + (1.0 - smoothingFactor) * lastOutput
                return lastOutput
            }
        }
        
        /// Exponential moving average with variable smoothing
        public func ema(_ smoothingFactor: @escaping FloatOp) -> FloatOp {
            var lastOutput: Float = 0.0
            
            return { pos in
                let smoothing = smoothingFactor(pos)
                lastOutput = smoothing * pos + (1.0 - smoothing) * lastOutput
                return lastOutput
            }
        }
        
        // MARK: - Lookup and Wavetable Operations
        
        /// Looks up values in a float table
        public func lookup(_ table: [Float]) -> FloatOp {
            return { pos in
                let index = Int(self.map(pos, 0.0, 1.0, 0.0, Float(table.count)))
                let safeIndex = Swift.min(Swift.max(0, index), table.count - 1)
                return table[safeIndex]
            }
        }
        
        /// Looks up values in a table of operations
        public func lookup(_ table: [FloatOp]) -> FloatOp {
            return { pos in
                let index = Int(self.map(pos, 0.0, 1.0, 0.0, Float(table.count)))
                let safeIndex = Swift.min(Swift.max(0, index), table.count - 1)
                return table[safeIndex](pos)
            }
        }
        
        /// 1D wavetable with float values
        public func wt(_ wTable: [Float]) -> FloatOp {
            return { pos in
                // Map pos to the range of the wavetable indices
                let exactPos = self.map(pos, 0.0, 1.0, 0.0, Float(wTable.count))
                
                // Determine the indices of the surrounding samples
                let index1 = Int(exactPos) % wTable.count
                let index2 = (index1 + 1) % wTable.count
                
                // Calculate the fractional part of the position
                let fraction = exactPos - Float(index1)
                
                // Linearly interpolate between the two samples
                return self.lerp(wTable[index1], wTable[index2], fraction)
            }
        }
        
        /// 1D wavetable with operation values
        public func wt(_ wTable: [FloatOp]) -> FloatOp {
            return { pos in
                // Map pos to the range of the wavetable indices
                let exactPos = self.map(pos, 0.0, 1.0, 0.0, Float(wTable.count))
                
                // Determine the indices of the surrounding samples
                let index1 = Int(exactPos) % wTable.count
                let index2 = (index1 + 1) % wTable.count
                
                // Calculate the fractional part of the position
                let fraction = exactPos - Float(index1)
                
                // Linearly interpolate between the two evaluated operations
                return self.lerp(wTable[index1](pos), wTable[index2](pos), fraction)
            }
        }
        
        /// 1D wavetable with float values and position modulation
        public func wt(_ wTable: [Float], _ xOp: @escaping FloatOp) -> FloatOp {
            return { pos in
                // Map xOp to the range of the wavetable
                let xPos = self.map(xOp(pos), 0.0, 1.0, 0.0, Float(wTable.count - 1))
                
                // Compute the lower index for the x axis
                let xIndex = Int(xPos)
                
                // Compute the fractional part for the x axis
                let xFrac = xPos - Float(xIndex)
                
                // Get next index with wrapping
                let xIndexNext = (xIndex + 1) % wTable.count
                
                // Linear interpolation
                return self.lerp(wTable[xIndex], wTable[xIndexNext], xFrac)
            }
        }
        
        /// 1D wavetable with operation values and position modulation
        public func wt(_ wTable: [FloatOp], _ xOp: @escaping FloatOp) -> FloatOp {
            return { pos in
                // Map xOp to the range of the wavetable
                let xPos = self.map(xOp(pos), 0.0, 1.0, 0.0, Float(wTable.count - 1))
                
                // Compute the lower index for the x axis
                let xIndex = Int(xPos)
                
                // Compute the fractional part for the x axis
                let xFrac = xPos - Float(xIndex)
                
                // Get next index with wrapping
                let xIndexNext = (xIndex + 1) % wTable.count
                
                // Linear interpolation
                return self.lerp(wTable[xIndex](pos), wTable[xIndexNext](pos), xFrac)
            }
        }
        
        /// 2D wavetable with float values
        public func wt2d(_ wTable: [[Float]], _ xOp: @escaping FloatOp, _ yOp: @escaping FloatOp) -> FloatOp {
            return { pos in
                // Map xOp and yOp to their respective ranges
                let xPos = self.map(xOp(pos), 0.0, 1.0, 0.0, Float(wTable.count - 1))
                let yPos = self.map(yOp(pos), 0.0, 1.0, 0.0, Float(wTable[0].count - 1))
                
                // Compute the lower indices for each axis
                let xIndex = Int(xPos)
                let yIndex = Int(yPos)
                
                // Compute the fractional part for each axis
                let xFrac = xPos - Float(xIndex)
                let yFrac = yPos - Float(yIndex)
                
                // Get next index with wrapping
                let xIndexNext = (xIndex + 1) % wTable.count
                let yIndexNext = (yIndex + 1) % wTable[0].count
                
                // Bilinear interpolation
                let v00 = wTable[xIndex][yIndex]
                let v10 = wTable[xIndexNext][yIndex]
                let v01 = wTable[xIndex][yIndexNext]
                let v11 = wTable[xIndexNext][yIndexNext]
                
                let c0 = self.lerp(v00, v10, xFrac)
                let c1 = self.lerp(v01, v11, xFrac)
                
                return self.lerp(c0, c1, yFrac)
            }
        }
        
        /// 2D wavetable with operation values
        public func wt2d(_ wTable: [[FloatOp]], _ xOp: @escaping FloatOp, _ yOp: @escaping FloatOp) -> FloatOp {
            return { pos in
                // Map xOp and yOp to their respective ranges
                let xPos = self.map(xOp(pos), 0.0, 1.0, 0.0, Float(wTable.count - 1))
                let yPos = self.map(yOp(pos), 0.0, 1.0, 0.0, Float(wTable[0].count - 1))
                
                // Compute the lower indices for each axis
                let xIndex = Int(xPos)
                let yIndex = Int(yPos)
                
                // Compute the fractional part for each axis
                let xFrac = xPos - Float(xIndex)
                let yFrac = yPos - Float(yIndex)
                
                // Get next index with wrapping
                let xIndexNext = (xIndex + 1) % wTable.count
                let yIndexNext = (yIndex + 1) % wTable[0].count
                
                // Bilinear interpolation
                let v00 = wTable[xIndex][yIndex](pos)
                let v10 = wTable[xIndexNext][yIndex](pos)
                let v01 = wTable[xIndex][yIndexNext](pos)
                let v11 = wTable[xIndexNext][yIndexNext](pos)
                
                let c0 = self.lerp(v00, v10, xFrac)
                let c1 = self.lerp(v01, v11, xFrac)
                
                return self.lerp(c0, c1, yFrac)
            }
        }
        
        /// 3D wavetable with float values
        public func wt3d(_ wTable: [[[Float]]], _ xOp: @escaping FloatOp, _ yOp: @escaping FloatOp, _ zOp: @escaping FloatOp) -> FloatOp {
            return { pos in
                // Get exact positions for each axis
                let xPos = self.map(xOp(pos), 0.0, 1.0, 0.0, Float(wTable.count - 1))
                let yPos = self.map(yOp(pos), 0.0, 1.0, 0.0, Float(wTable[0].count - 1))
                let zPos = self.map(zOp(pos), 0.0, 1.0, 0.0, Float(wTable[0][0].count - 1))
                
                // Compute the lower indices for each axis
                let xIndex = Int(xPos)
                let yIndex = Int(yPos)
                let zIndex = Int(zPos)
                
                // Compute the fractional part for each axis
                let xFrac = xPos - Float(xIndex)
                let yFrac = yPos - Float(yIndex)
                let zFrac = zPos - Float(zIndex)
                
                // Get next index with wrapping
                let xIndexNext = (xIndex + 1) % wTable.count
                let yIndexNext = (yIndex + 1) % wTable[0].count
                let zIndexNext = (zIndex + 1) % wTable[0][0].count
                
                // Trilinear interpolation
                let v000 = wTable[xIndex][yIndex][zIndex]
                let v100 = wTable[xIndexNext][yIndex][zIndex]
                let v010 = wTable[xIndex][yIndexNext][zIndex]
                let v001 = wTable[xIndex][yIndex][zIndexNext]
                let v101 = wTable[xIndexNext][yIndex][zIndexNext]
                let v011 = wTable[xIndex][yIndexNext][zIndexNext]
                let v110 = wTable[xIndexNext][yIndexNext][zIndex]
                let v111 = wTable[xIndexNext][yIndexNext][zIndexNext]
                
                let c00 = self.lerp(v000, v100, xFrac)
                let c01 = self.lerp(v001, v101, xFrac)
                let c10 = self.lerp(v010, v110, xFrac)
                let c11 = self.lerp(v011, v111, xFrac)
                
                let c0 = self.lerp(c00, c10, yFrac)
                let c1 = self.lerp(c01, c11, yFrac)
                
                return self.lerp(c0, c1, zFrac)
            }
        }
        
        /// 3D wavetable with operation values
        public func wt3d(_ wTable: [[[FloatOp]]], _ xOp: @escaping FloatOp, _ yOp: @escaping FloatOp, _ zOp: @escaping FloatOp) -> FloatOp {
            return { pos in
                // Get exact positions for each axis
                let xPos = self.map(xOp(pos), 0.0, 1.0, 0.0, Float(wTable.count - 1))
                let yPos = self.map(yOp(pos), 0.0, 1.0, 0.0, Float(wTable[0].count - 1))
                let zPos = self.map(zOp(pos), 0.0, 1.0, 0.0, Float(wTable[0][0].count - 1))
                
                // Compute the lower indices for each axis
                let xIndex = Int(xPos)
                let yIndex = Int(yPos)
                let zIndex = Int(zPos)
                
                // Compute the fractional part for each axis
                let xFrac = xPos - Float(xIndex)
                let yFrac = yPos - Float(yIndex)
                let zFrac = zPos - Float(zIndex)
                
                // Get next index with wrapping
                let xIndexNext = (xIndex + 1) % wTable.count
                let yIndexNext = (yIndex + 1) % wTable[0].count
                let zIndexNext = (zIndex + 1) % wTable[0][0].count
                
                // Trilinear interpolation with evaluated operations
                let v000 = wTable[xIndex][yIndex][zIndex](pos)
                let v100 = wTable[xIndexNext][yIndex][zIndex](pos)
                let v010 = wTable[xIndex][yIndexNext][zIndex](pos)
                let v001 = wTable[xIndex][yIndex][zIndexNext](pos)
                let v101 = wTable[xIndexNext][yIndex][zIndexNext](pos)
                let v011 = wTable[xIndex][yIndexNext][zIndexNext](pos)
                let v110 = wTable[xIndexNext][yIndexNext][zIndex](pos)
                let v111 = wTable[xIndexNext][yIndexNext][zIndexNext](pos)
                
                let c00 = self.lerp(v000, v100, xFrac)
                let c01 = self.lerp(v001, v101, xFrac)
                let c10 = self.lerp(v010, v110, xFrac)
                let c11 = self.lerp(v011, v111, xFrac)
                
                let c0 = self.lerp(c00, c10, yFrac)
                let c1 = self.lerp(c01, c11, yFrac)
                
                return self.lerp(c0, c1, zFrac)
            }
        }
        
        // MARK: - Random and Noise Operations
        
        /// Creates a gaussian distribution
        public func gaussian(_ lo: FloatOp? = nil, _ hi: FloatOp? = nil) -> FloatOp {
            return { pos in
                // Generate Gaussian random value centered around 0 with stddev 1
                let u1 = Float.random(in: 0.0..<1.0)
                let u2 = Float.random(in: 0.0..<1.0)
                var g = sqrt(-2.0 * log(u1)) * _math.cos(2.0 * Float.pi * u2)
                
                // Clamp to -1...1 range
                if g < -1.0 {
                    g = fmod(g, -1.0)
                } else if g > 1.0 {
                    g = fmod(g, 1.0)
                }
                
                // Map to 0...1 range
                g = (g + 1.0) * 0.5
                
                // Scale between lo and hi
                let loVal = lo?(pos) ?? 0.0
                let hiVal = hi?(pos) ?? 1.0
                
                return loVal + (g * (hiVal - loVal))
            }
        }
        
        /// Creates a gaussian distribution with fixed hi value
        public func gaussian(_ hi: @escaping FloatOp) -> FloatOp {
            return gaussian(nil, hi)
        }
        
        /// Creates a gaussian distribution with fixed hi value
        public func gaussian(_ hi: Float) -> FloatOp {
            return gaussian(nil, c(hi))
        }
        
        /// Creates a gaussian distribution with default range (0-1)
        public func gaussian() -> FloatOp {
            return gaussian(nil, nil)
        }
        
        /// Creates a triangular distribution
        public func random(_ lo: FloatOp? = nil, _ hi: FloatOp? = nil, _ mode: FloatOp? = nil) -> FloatOp {
            return { pos in
                let loVal = lo?(pos) ?? 0.0
                let hiVal = hi?(pos) ?? 1.0
                
                if let mode = mode {
                    let modeVal = mode(pos)
                    return self.triDist(lo: loVal, hi: hiVal, mode: modeVal)
                } else {
                    return loVal + Float.random(in: 0.0..<(hiVal - loVal))
                }
            }
        }
        
        /// Creates a random distribution with default low and mode
        public func random(_ hi: @escaping FloatOp) -> FloatOp {
            return random(nil, hi, nil)
        }
        
        /// Creates a random distribution with fixed hi value
        public func random(_ hi: Float) -> FloatOp {
            return random(c(hi))
        }
        
        /// Creates a random distribution with default range (0-1)
        public func random() -> FloatOp {
            return random(nil, nil, nil)
        }
        
        /// Adds random variation to a position
        public func fuzz(_ fuzzScale: Float) -> FloatOp {
            let noiseSource = GKNoise(GKPerlinNoiseSource())
            
            return { pos in
                // Generate Perlin noise and scale it by fuzzScale
                let noise = Float(noiseSource.value(atPosition: vector_float2(repeating: pos))) * fuzzScale
                
                // Add the scaled noise to the input position
                return pos + noise
            }
        }
        
        /// Helper function to generate noise values from any GKNoiseSource
        private func noiseHelper(source: GKNoiseSource,
                                 x: @escaping FloatOp,
                                 y: FloatOp? = nil,
                                 z: FloatOp? = nil) -> FloatOp {
            return { pos in
                let noise = GKNoise(source)
                
                let xVal = x(pos)
                
                if let y = y {
                    let yVal = y(pos)
                    
                    if let z = z {
                        // For 3D noise, we can create a composite by sampling at different 2D slices
                        let zVal = z(pos)
                        // Sample at xy plane with z offset
                        let sample1 = noise.value(atPosition: vector_float2(xVal, yVal))
                        let sample2 = noise.value(atPosition: vector_float2(xVal + zVal, yVal + zVal))
                        // Blend based on z
                        return Float(sample1 * (1.0 - zVal) + sample2 * zVal)
                    } else {
                        // 2D noise
                        return Float(noise.value(atPosition: vector_float2(xVal, yVal)))
                    }
                } else {
                    // 1D noise - use x for both coordinates with an offset
                    return Float(noise.value(atPosition: vector_float2(xVal, xVal * 0.5)))
                }
            }
        }
        
        /// Creates a Perlin noise function with all relevant parameters
        public func perlin(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                           _ frequency: FloatOp? = nil,      // Added frequency parameter
                           _ roughness: FloatOp? = nil,      // renamed from persistence
                           _ octaves: FloatOp? = nil,
                           _ scaleJump: FloatOp? = nil,      // renamed from lacunarity
                           _ seed: Int32 = 0) -> FloatOp {
            
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                
                let frequencyVal = frequency?(pos) ?? 1.0    // Default but not hardcoded
                let roughnessVal = roughness?(pos) ?? 0.5
                let octavesVal = octaves != nil ? Int(octaves!(pos)) : 1
                let scaleJumpVal = scaleJump?(pos) ?? 2.0
                
                let noiseSource = GKPerlinNoiseSource(
                    frequency: Double(frequencyVal),         // Use the parameter value
                    octaveCount: Swift.max(1, octavesVal),
                    persistence: Double(roughnessVal),
                    lacunarity: Double(scaleJumpVal),
                    seed: seed
                )
                
                return self.noiseHelper(source: noiseSource, x: x, y: y, z: z)(pos)
            }
        }
        
        /// Creates a Billow noise function (rounded shapes with clear transitions)
        public func billow(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                           _ frequency: FloatOp? = nil,      // Added frequency parameter
                           _ roughness: FloatOp? = nil,      // renamed from persistence
                           _ octaves: FloatOp? = nil,
                           _ scaleJump: FloatOp? = nil,      // renamed from lacunarity
                           _ seed: Int32 = 0) -> FloatOp {
            
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                
                let frequencyVal = frequency?(pos) ?? 1.0    // Default but configurable
                let roughnessVal = roughness?(pos) ?? 0.5
                let octavesVal = octaves != nil ? Int(octaves!(pos)) : 1
                let scaleJumpVal = scaleJump?(pos) ?? 2.0
                
                let noiseSource = GKBillowNoiseSource(
                    frequency: Double(frequencyVal),         // Use the parameter value
                    octaveCount: Swift.max(1, octavesVal),
                    persistence: Double(roughnessVal),
                    lacunarity: Double(scaleJumpVal),
                    seed: seed
                )
                
                return self.noiseHelper(source: noiseSource, x: x, y: y, z: z)(pos)
            }
        }
        
        /// Creates a Ridged noise function (sharp peaks)
        public func ridged(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                           _ frequency: FloatOp? = nil,      // Added frequency parameter
                           _ octaves: FloatOp? = nil,
                           _ scaleJump: FloatOp? = nil,      // renamed from lacunarity
                           _ seed: Int32 = 0) -> FloatOp {
            
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                
                let frequencyVal = frequency?(pos) ?? 1.0    // Default but configurable
                let octavesVal = octaves != nil ? Int(octaves!(pos)) : 1
                let scaleJumpVal = scaleJump?(pos) ?? 2.0
                
                let noiseSource = GKRidgedNoiseSource(
                    frequency: Double(frequencyVal),         // Use the parameter value
                    octaveCount: Swift.max(1, octavesVal),
                    lacunarity: Double(scaleJumpVal),
                    seed: seed
                )
                
                return self.noiseHelper(source: noiseSource, x: x, y: y, z: z)(pos)
            }
        }
        
        /// Creates a Voronoi noise function (cellular/crystal-like structures)
        public func voronoi(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                            _ frequency: FloatOp? = nil, _ displacement: FloatOp? = nil,
                            _ distanceEnabled: FloatOp? = nil, _ seed: Int32 = 0) -> FloatOp {
            
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                
                let frequencyVal = frequency?(pos) ?? 1.0
                let displacementVal = displacement?(pos) ?? 1.0
                let distanceEnabledVal = distanceEnabled?(pos) ?? 0.5 > 0.5 // Convert to Boolean
                
                let noiseSource = GKVoronoiNoiseSource(
                    frequency: Double(frequencyVal),
                    displacement: Double(displacementVal),
                    distanceEnabled: distanceEnabledVal,
                    seed: seed
                )
                
                return self.noiseHelper(source: noiseSource, x: x, y: y, z: z)(pos)
            }
        }
        
        /// Creates a Cylinders noise function
        public func cylinders(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                              _ frequency: FloatOp? = nil) -> FloatOp {
            
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                
                let frequencyVal = frequency?(pos) ?? 1.0
                let noiseSource = GKCylindersNoiseSource(frequency: Double(frequencyVal))
                
                return self.noiseHelper(source: noiseSource, x: x, y: y, z: z)(pos)
            }
        }
        
        /// Creates a Spheres noise function
        public func spheres(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                            _ frequency: FloatOp? = nil) -> FloatOp {
            
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                
                let frequencyVal = frequency?(pos) ?? 1.0
                let noiseSource = GKSpheresNoiseSource(frequency: Double(frequencyVal))
                
                return self.noiseHelper(source: noiseSource, x: x, y: y, z: z)(pos)
            }
        }
        
        /// Creates a Checkerboard noise function
        public func checkerboard(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                                 _ squareSize: FloatOp? = nil) -> FloatOp {
            
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                
                let squareSizeVal = squareSize?(pos) ?? 1.0
                let noiseSource = GKCheckerboardNoiseSource(squareSize: Double(squareSizeVal))
                
                return self.noiseHelper(source: noiseSource, x: x, y: y, z: z)(pos)
            }
        }
        
        // MARK: - Additional Signal Processing
        
        /// Amplifier with feedback
        public func ampFb(_ feedbackStrength: Float, _ damping: Float, _ inputOp: FloatOp? = nil) -> FloatOp {
            var lastOutput: Float = 0.0
            
            return { pos in
                // Get the current input value
                let input = inputOp?(pos) ?? pos
                
                // Apply feedback to the input
                let modulatedInput = input + lastOutput * feedbackStrength
                
                // Compute the output with damping to stabilize the feedback loop
                let output = modulatedInput * (1.0 - damping)
                
                // Update the last output for the next iteration
                lastOutput = output
                
                return output
            }
        }
        
        /// Smoothing function (cubic)
        public func smooth() -> FloatOp {
            return { pos in
                // Clamp x to the range [0, 1]
                let clampedX = Swift.min(1.0, Swift.max(0.0, pos))
                return clampedX * clampedX * (3 - 2 * clampedX)
            }
        }
        
        /// Smoother function (quintic)
        public func smoother() -> FloatOp {
            return { pos in
                // Clamp x to the range [0, 1]
                let clampedX = Swift.min(1.0, Swift.max(0.0, pos))
                return clampedX * clampedX * clampedX * (clampedX * (clampedX * 6 - 15) + 10)
            }
        }
        
        /// Chooses a random operation from the provided array
        public func choose(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                let index = Int.random(in: 0..<ops.count)
                return ops[index](pos)
            }
        }
        
        /// Normalizes an array of values to the range 0-1
        public func normalize(_ values: [Float]) -> [Float] {
            guard let min = values.min(), let max = values.max(), min != max else {
                return values.map { _ in 0.5 } // Return mid-values if there's no range
            }
            
            return values.map { (value) -> Float in
                return (value - min) / (max - min)
            }
        }
        
        /// Creates a function from a time series
        public func timeseries(_ yValues: [Float]) -> FloatOp {
            let normValues = normalize(yValues)
            
            return { pos in
                let index = Int(pos * Float(normValues.count - 1))
                let fraction = pos * Float(normValues.count - 1) - Float(index)
                
                // Ensure we don't go out of bounds
                let safeIndex = Swift.min(index, normValues.count - 2)
                
                return (normValues[safeIndex] * (1.0 - fraction)) +
                       (normValues[safeIndex + 1] * fraction)
            }
        }
        
        /// Generates an array of float values from an operation
        public func floatArray(_ op: @escaping FloatOp, _ numSamples: Int, _ mapOp: FloatOp? = nil) -> [Float] {
            let step = 1.0 / Float(numSamples)
            var localTable = [Float](repeating: 0.0, count: numSamples)
            
            for i in 0..<numSamples {
                let pos = Float(i) * step
                localTable[i] = op(pos / Float(numSamples))
            }
            
            if let mapOp = mapOp {
                var mappedTable = [Float](repeating: 0.0, count: numSamples)
                for i in 0..<numSamples {
                    mappedTable[i] = mapOp(localTable[i])
                }
                return mappedTable
            }
            
            return localTable
        }
        
        /// Triangular distribution helper function
        public func triDist(lo: Float, hi: Float, mode: Float) -> Float {
            let F = (mode - lo) / (hi - lo)
            let rand = Float.random(in: 0.0..<1.0)
            
            if rand < F {
                return lo + sqrt(rand * (hi - lo) * (mode - lo))
            } else {
                return hi - sqrt((1.0 - rand) * (hi - lo) * (hi - mode))
            }
        }
        
        // MARK: - Logical Operations
        
        /// Logical AND operation
        public func and_(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: Float = 0.5) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                return (a > threshold && b > threshold) ? 1.0 : 0.0
            }
        }
        
        /// Logical AND with variable threshold
        public func and_(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: @escaping FloatOp) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                let t = threshold(pos)
                return (a > t && b > t) ? 1.0 : 0.0
            }
        }
        
        /// Logical OR operation
        public func or_(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: Float = 0.5) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                return (a > threshold || b > threshold) ? 1.0 : 0.0
            }
        }
        
        /// Logical OR with variable threshold
        public func or_(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: @escaping FloatOp) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                let t = threshold(pos)
                return (a > t || b > t) ? 1.0 : 0.0
            }
        }
        
        /// Logical NOT operation
        public func not_(_ op: @escaping FloatOp) -> FloatOp {
            return { pos in
                return op(pos) == 0.0 ? 1.0 : 0.0
            }
        }
        
        /// Logical XOR operation
        public func xor_(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: Float = 0.5) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                return ((a > threshold && b <= threshold) || (a <= threshold && b > threshold)) ? 1.0 : 0.0
            }
        }
        
        /// Logical XOR with variable threshold
        public func xor_(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: @escaping FloatOp) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                let t = threshold(pos)
                return ((a > t && b <= t) || (a <= t && b > t)) ? 1.0 : 0.0
            }
        }
        
        /// Logical NAND operation
        public func nand(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: Float = 0.5) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                return (a > threshold && b > threshold) ? 0.0 : 1.0
            }
        }
        
        /// Logical NAND with variable threshold
        public func nand(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: @escaping FloatOp) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                let t = threshold(pos)
                return (a > t && b > t) ? 0.0 : 1.0
            }
        }
        
        /// Logical NOR operation
        public func nor(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: Float = 0.5) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                return (a > threshold || b > threshold) ? 0.0 : 1.0
            }
        }
        
        /// Logical NOR with variable threshold
        public func nor(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: @escaping FloatOp) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                let t = threshold(pos)
                return (a > t || b > t) ? 0.0 : 1.0
            }
        }
        
        /// Logical XNOR operation
        public func xnor(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: Float = 0.5) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                return ((a > threshold && b > threshold) || (a <= threshold && b <= threshold)) ? 1.0 : 0.0
            }
        }
        
        /// Logical XNOR with variable threshold
        public func xnor(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ threshold: @escaping FloatOp) -> FloatOp {
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                let t = threshold(pos)
                return ((a > t && b > t) || (a <= t && b <= t)) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is within a range
        public func in_(_ op: @escaping FloatOp, _ lo: Float, _ hi: Float) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val >= lo && val <= hi) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is within a dynamic range
        public func in_(_ op: @escaping FloatOp, _ lo: @escaping FloatOp, _ hi: @escaping FloatOp) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val >= lo(pos) && val <= hi(pos)) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is within a mixed range
        public func in_(_ op: @escaping FloatOp, _ lo: Float, _ hi: @escaping FloatOp) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val >= lo && val <= hi(pos)) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is within a mixed range
        public func in_(_ op: @escaping FloatOp, _ lo: @escaping FloatOp, _ hi: Float) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val >= lo(pos) && val <= hi) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is outside a range
        public func out(_ op: @escaping FloatOp, _ lo: Float, _ hi: Float) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val < lo || val > hi) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is outside a dynamic range
        public func out(_ op: @escaping FloatOp, _ lo: @escaping FloatOp, _ hi: @escaping FloatOp) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val < lo(pos) || val > hi(pos)) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is outside a mixed range
        public func out(_ op: @escaping FloatOp, _ lo: Float, _ hi: @escaping FloatOp) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val < lo || val > hi(pos)) ? 1.0 : 0.0
            }
        }
        
        /// Checks if a value is outside a mixed range
        public func out(_ op: @escaping FloatOp, _ lo: @escaping FloatOp, _ hi: Float) -> FloatOp {
            return { pos in
                let val = op(pos)
                return (val < lo(pos) || val > hi) ? 1.0 : 0.0
            }
        }
        
        // MARK: - Statistical Functions
        
        /// Returns the mean (average) of a collection of operations
        public func mean(_ ops: [FloatOp]) -> FloatOp {
            return mix(ops)
        }
        
        /// Returns the median value from a collection of operations
        public func median(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                var values = [Float]()
                for op in ops {
                    values.append(op(pos))
                }
                values.sort()
                return values[values.count / 2]
            }
        }
        
        /// Returns the variance of a collection of operations
        public func variance(_ ops: [FloatOp]) -> FloatOp {
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                let mn = self.mean(ops)(pos)
                var variance: Float = 0.0
                for op in ops {
                    let diff = op(pos) - mn
                    variance += diff * diff
                }
                variance /= Float(ops.count)
                return variance
            }
        }
        
        /// Returns the standard deviation of a collection of operations
        public func stdDev(_ ops: [FloatOp]) -> FloatOp {
            return { [weak self] pos in
                guard let self = self else { return 0.0 }
                return sqrt(self.variance(ops)(pos))
            }
        }
        
        // MARK: - Vector Operations
        
        /// Vector representation using CGPoint in 2D
        public typealias CGPoint2D = CGPoint
        
        /// Vector representation using vector_float3 in 3D
        public typealias Vector3D = SIMD3<Float>
        
        /// Generates a 2D point array from an operation
        public func point2DArray(_ curve: @escaping FloatOp, _ start: Float, _ end: Float, _ numPoints: Int, _ yScale: Float = 1.0) -> [CGPoint2D] {
            let step = (end - start) / Float(numPoints)
            let modEnd = end - (step - 1)
            var points = [CGPoint2D]()
            
            for i in 0..<numPoints {
                let x = start + (Float(i) * step)
                let y = curve(x / modEnd)
                points.append(CGPoint2D(x: CGFloat(x), y: CGFloat(y * yScale)))
            }
            
            return points
        }
        
        /// Generates a 3D vector array from an operation
        public func vector3DArray(_ curve: @escaping FloatOp, _ start: Float, _ end: Float, _ numPoints: Int, _ yScale: Float = 1.0) -> [Vector3D] {
            let step = (end - start) / Float(numPoints)
            let modEnd = end - (step - 1)
            var points = [Vector3D]()
            
            for i in 0..<numPoints {
                let x = start + (Float(i) * step)
                let y = curve(x / modEnd)
                points.append(Vector3D(x, y * yScale, 0.0))
            }
            
            return points
        }
        
        // MARK: - Combination Operations
        
        /// Morphs between two operations based on a parameter
        public func morph(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp, _ morphParam: @escaping FloatOp) -> FloatOp {
            return { pos in
                let blend = Swift.min(1.0, Swift.max(0.0, morphParam(pos)))
                return (1.0 - blend) * opA(pos) + blend * opB(pos)
            }
        }
        
        /// Morphs between a collection of operations based on a parameter
        public func morph(_ ops: [FloatOp], _ morphParam: @escaping FloatOp) -> FloatOp {
            return { [weak self] pos in
                guard let self = self, !ops.isEmpty else { return 0.0 }
                
                let blend = Swift.min(1.0, Swift.max(0.0, morphParam(pos)))
                
                // Map pos to the range of the op indices
                let exactPos = self.map(blend, 0.0, 1.0, 0.0, Float(ops.count))
                
                // Determine the indices of the surrounding ops
                let index1 = Int(exactPos) % ops.count
                let index2 = (index1 + 1) % ops.count
                
                // Calculate the fractional part of the position
                let fraction = exactPos - Float(index1)
                
                // Linearly interpolate between the two ops
                return self.lerp(ops[index1](pos), ops[index2](pos), fraction)
            }
        }
        
        /// Mixes a collection of operations with equal weight
        public func mix(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                var sum: Float = 0.0
                for op in ops {
                    sum += op(pos)
                }
                return sum / Float(ops.count)
            }
        }
        
        /// Mixes operations with fixed weights
        public func mix(_ ops: [FloatOp], _ levels: [Float]) -> FloatOp {
            return { pos in
                var sum: Float = 0.0
                for i in 0..<Swift.min(ops.count, levels.count) {
                    sum += ops[i](pos) * levels[i]
                }
                return sum / Float(ops.count)
            }
        }
        
        /// Mixes operations with dynamic weights
        public func mix(_ ops: [FloatOp], _ levels: [FloatOp]) -> FloatOp {
            return { pos in
                var sum: Float = 0.0
                for i in 0..<Swift.min(ops.count, levels.count) {
                    sum += ops[i](pos) * levels[i](pos)
                }
                return sum / Float(ops.count)
            }
        }
        
        /// Sums a collection of operations
        public func sum(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                var sum: Float = 0.0
                for op in ops {
                    sum += op(pos)
                }
                return sum
            }
        }
        
        /// Returns the product of a collection of operations
        public func product(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                var product: Float = 1.0
                for op in ops {
                    product *= op(pos)
                }
                return product
            }
        }
        
        /// Returns the minimum value from a collection of operations
        public func min(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                var minValue = Float.greatestFiniteMagnitude
                for op in ops {
                    let val = op(pos)
                    if val < minValue {
                        minValue = val
                    }
                }
                return minValue
            }
        }
        
        /// Returns the maximum value from a collection of operations
        public func max(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                var maxValue = -Float.greatestFiniteMagnitude
                for op in ops {
                    let val = op(pos)
                    if val > maxValue {
                        maxValue = val
                    }
                }
                return maxValue
            }
        }
        
        /// Chains operations sequentially
        public func chain(_ ops: [FloatOp]) -> FloatOp {
            return { pos in
                var val = pos
                for op in ops {
                    val = op(val)
                }
                return val
            }
        }
        
        // MARK: - Comparison Operations
        
        /// Returns 1.0 if the first operation is greater than the second, else 0.0
        public func greater(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp) -> FloatOp {
            return { pos in opA(pos) > opB(pos) ? 1.0 : 0.0 }
        }
        
        /// Returns 1.0 if the operation is greater than a threshold, else 0.0
        public func greater(_ opA: @escaping FloatOp, _ threshold: Float) -> FloatOp {
            return { pos in opA(pos) > threshold ? 1.0 : 0.0 }
        }
        
        /// Returns 1.0 if the first operation is less than the second, else 0.0
        public func less(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp) -> FloatOp {
            return { pos in opA(pos) < opB(pos) ? 1.0 : 0.0 }
        }
        
        /// Returns 1.0 if the operation is less than a threshold, else 0.0
        public func less(_ opA: @escaping FloatOp, _ threshold: Float) -> FloatOp {
            return { pos in opA(pos) < threshold ? 1.0 : 0.0 }
        }
        
        /// Detects when two signals cross each other
        public func crossed(_ opA: @escaping FloatOp, _ opB: @escaping FloatOp) -> FloatOp {
            var lastComparison: Bool?
            
            return { pos in
                let a = opA(pos)
                let b = opB(pos)
                let aGreaterThanB = a > b
                
                if lastComparison == nil {
                    // Initialize the state during the first call
                    lastComparison = aGreaterThanB
                    return 0.0
                }
                
                if aGreaterThanB != lastComparison {
                    // A crossing has occurred
                    lastComparison = aGreaterThanB
                    return 1.0
                }
                
                return 0.0 // No crossing
            }
        }
        
        /// Detects when a signal changes trend (from increasing to decreasing or vice versa)
        public func trendFlip(_ inputOp: @escaping FloatOp) -> FloatOp {
            var lastValue: Float?
            var lastDirection: Bool?
            
            return { pos in
                // Get the current value
                let currentValue = inputOp(pos)
                
                // Check if lastValue has been initialized
                guard let lastVal = lastValue else {
                    lastValue = currentValue
                    return 0.0 // No direction change can be detected on the first call
                }
                
                // Determine the current direction (true for increasing, false for decreasing)
                let currentDirection = currentValue > lastVal
                
                // Check if lastDirection has been initialized
                guard let lastDir = lastDirection else {
                    lastDirection = currentDirection
                    lastValue = currentValue
                    return 0.0 // No direction change on the first valid comparison
                }
                
                // Check for a change in direction
                if currentDirection != lastDir {
                    lastDirection = currentDirection
                    lastValue = currentValue
                    return 1.0 // Direction change detected
                }
                
                // Update lastValue for the next call
                lastValue = currentValue
                return 0.0 // No change in direction
            }
        }
        
        // MARK: - Pitch Utilities
        
        /// Quantizes a value to specific musical scale
        public func quantizeToScale(_ op: @escaping FloatOp,
                                    _ scale: [Int] = [0,2,4,5,7,9,11]) -> FloatOp {
            return { pos in
                let value = op(pos)
                // Map 0-1 to 0-12 (chromatic scale)
                let rawNote = value * 12
                // Find scale degree
                let octave = Int(floor(rawNote / 12))
                let noteInOctave = rawNote.truncatingRemainder(dividingBy: 12)
                
                // Find closest scale tone
                var closestDegree = scale[0]
                var minDistance: Float = 12
                
                for scaleDegree in scale {
                    let distance = Swift.abs(Float(scaleDegree) - noteInOctave)
                    if distance < minDistance {
                        minDistance = distance
                        closestDegree = scaleDegree
                    }
                }
                
                // Return normalized value
                return (Float(octave * 12 + closestDegree) / 12)
            }
        }
        
        /// Converts normalized value to frequency in Hz with 0.5 = middle C (261.63Hz)
        public func toFrequency(_ op: @escaping FloatOp,
                                _ baseNote: Float = 60) -> FloatOp {
            return { pos in
                let noteNumber = baseNote + (op(pos) * 12)
                // A4 (69) = 440Hz standard tuning
                return 440.0 * pow(2, (noteNumber - 69) / 12)
            }
        }
        
        // MARK: - Rhthym Utilities
        
        /// Creates groove patterns with swing/humanization
        public func groove(_ basePhasor: @escaping FloatOp,
                           _ swingAmount: Float = 0.0,
                           _ humanize: Float = 0.0) -> FloatOp {
            
            return { pos in
                let phase = basePhasor(pos)
                
                // Apply swing (delay even 8th notes)
                var swungPhase = phase
                let isEvenEighth = (floor(phase * 8).truncatingRemainder(dividingBy: 2)) == 0
                if isEvenEighth {
                    // Delay even eighth notes by swingAmount
                    swungPhase += swingAmount * 0.125 // 0.125 = 1/8 note
                }
                
                // Apply humanization (random timing variation)
                let humanized = swungPhase + (Float.random(in: -humanize...humanize) * 0.01)
                
                // Keep in 0-1 range
                return humanized.truncatingRemainder(dividingBy: 1.0)
            }
        }
        
        /// Generates rhythmic patterns from binary patterns
        public func rhythmicPattern(_ patterns: [[Int]],
                                    _ density: @escaping FloatOp) -> FloatOp {
            var lastPattern = [1, 0, 0, 0]
            var lastTrigger = false
            var patternPosition: Float = 0
            var lastPos: Float = 0
            
            return { pos in
                // Create one-shot trigger at start of pos
                let deltaPosWrapped = pos < lastPos ? pos + 1.0 - lastPos : pos - lastPos
                patternPosition = (patternPosition + deltaPosWrapped).truncatingRemainder(dividingBy: 1.0)
                lastPos = pos
                
                // Select pattern based on density
                let densityValue = density(pos)
                let patternIndex = Swift.min(Int(densityValue * Float(patterns.count)), patterns.count - 1)
                let currentPattern = patterns[patternIndex]
                
                // Get step in pattern
                let step = Int(patternPosition * Float(currentPattern.count))
                let trigger = currentPattern[step] > 0
                
                // Generate one-shot triggers
                let output: Float = (trigger && !lastTrigger) ? 1.0 : 0.0
                lastTrigger = trigger
                
                return output
            }
        }
        
        /// Helper function to generate Euclidean rhythms (define this BEFORE the main function)
        private func generateEuclideanRhythm(steps: Int, pulses: Int, rotation: Int) -> [Bool] {
            // Edge cases
            if pulses >= steps {
                return [Bool](repeating: true, count: steps)
            }
            if pulses == 0 {
                return [Bool](repeating: false, count: steps)
            }
            
            // Bjorklund's algorithm
            var pattern = [Bool](repeating: false, count: steps)
            let divisor = steps / pulses
            let remainder = steps % pulses
            
            for i in 0..<pulses {
                let index = i * divisor + Swift.min(i, remainder)
                pattern[index] = true
            }
            
            // Apply rotation
            if rotation > 0 {
                let rotatedPattern = (0..<steps).map { i in
                    pattern[(i + steps - rotation) % steps]
                }
                pattern = rotatedPattern
            }
            
            return pattern
        }
        
        // MARK: - Delay Effects
        
        /// Creates a delay/echo effect with feedback
        public func delay(_ inputOp: @escaping FloatOp,
                          _ delayTimeSeconds: @escaping FloatOp,
                          _ feedback: @escaping FloatOp,
                          _ mix: @escaping FloatOp) -> FloatOp {
            // Constants
            let maxDelaySecs = 10.0
            let bufferSize = 12000  // Large enough for reasonable quality
            
            // Initialize buffer and state
            var buffer = [Float](repeating: 0, count: bufferSize)
            var writeIndex = 0
            
            return { pos in
                // Get input value
                let inputValue = inputOp(pos)
                
                // Get parameter values
                let delayTimeSecs = Swift.max(0.01, Swift.min(maxDelaySecs, Double(delayTimeSeconds(pos))))
                let feedbackValue = Swift.max(0.0, Swift.min(0.99, feedback(pos)))  // Limit feedback to prevent runaway
                let mixValue = Swift.max(0.0, Swift.min(1.0, mix(pos)))
                
                // Calculate read index with proper fractional position for interpolation
                let delayInSamples = delayTimeSecs * Double(bufferSize) / maxDelaySecs
                let readFloat = Double(writeIndex) - delayInSamples
                
                // Ensure the read index wraps correctly with modulo arithmetic
                var readFloatWrapped = readFloat
                while readFloatWrapped < 0 {
                    readFloatWrapped += Double(bufferSize)
                }
                readFloatWrapped = readFloatWrapped.truncatingRemainder(dividingBy: Double(bufferSize))
                
                // Get integer and fractional parts for interpolation
                let readIndex1 = Int(readFloatWrapped) % bufferSize
                let readIndex2 = (readIndex1 + 1) % bufferSize
                let fraction = readFloatWrapped - Double(Int(readFloatWrapped))
                
                // Linear interpolation between the two sample points
                let delayedValue = buffer[readIndex1] * Float(1.0 - fraction) + buffer[readIndex2] * Float(fraction)
                
                // Apply feedback
                buffer[writeIndex] = inputValue + delayedValue * feedbackValue
                
                // Move write index forward
                writeIndex = (writeIndex + 1) % bufferSize
                
                // Mix dry and wet signals
                return inputValue * (1.0 - mixValue) + delayedValue * mixValue
            }
        }
        
        /// Creates a tempo-synced delay effect with feedback
        public func tempoDelay(_ inputOp: @escaping FloatOp,
                               _ noteDivision: @escaping FloatOp, // 0.25 = quarter note, 0.5 = half note, etc.
                               _ bpm: @escaping FloatOp,
                               _ feedback: @escaping FloatOp,
                               _ mix: @escaping FloatOp) -> FloatOp {
            
            // Create a wrapper function that calculates delay time from tempo
            let delayTimeOp: FloatOp = { pos in
                // Calculate delay time in seconds based on tempo and note division
                let bpmValue = Swift.max(20.0, Swift.min(300.0, bpm(pos)))  // Reasonable BPM range
                let divisionValue = Swift.max(0.0625, Swift.min(4.0, noteDivision(pos)))  // From 1/16 to whole note
                
                // Convert BPM and division to seconds
                // Formula: (60 / BPM) * division
                return (60.0 / bpmValue) * divisionValue
            }
            
            // Use the standard delay with calculated delay time
            return delay(inputOp, delayTimeOp, feedback, mix)
        }
        
        /// Creates a multi-tap delay with variable spacing between taps
        public func multiTapDelay(_ inputOp: @escaping FloatOp,
                                  _ baseDelaySeconds: @escaping FloatOp,
                                  _ tapCount: Int = 3,
                                  _ tapSpacing: @escaping FloatOp, // Spacing multiplier between taps
                                  _ tapDecay: @escaping FloatOp,   // How much each tap decreases in volume
                                  _ mix: @escaping FloatOp) -> FloatOp {
            
            // Constants
            let maxDelaySecs = 10.0
            let bufferSize = 12000
            
            // Initialize buffer and state
            var buffer = [Float](repeating: 0, count: bufferSize)
            var writeIndex = 0
            
            return { pos in
                // Get input value
                let inputValue = inputOp(pos)
                let baseDelay = baseDelaySeconds(pos)
                let spacing = tapSpacing(pos)
                let decay = tapDecay(pos)
                let mixValue = mix(pos)
                
                // Write input to buffer
                buffer[writeIndex] = inputValue
                
                // Calculate and mix all tap outputs
                var tapsSum: Float = 0.0
                
                for tap in 0..<tapCount {
                    // Calculate delay time for this tap
                    let tapDelayTime = baseDelay * (1.0 + Float(tap) * spacing)
                    let delayInSamples = Double(tapDelayTime) * Double(bufferSize) / maxDelaySecs
                    
                    // Calculate read position
                    let readFloat = Double(writeIndex) - delayInSamples
                    var readFloatWrapped = readFloat
                    while readFloatWrapped < 0 {
                        readFloatWrapped += Double(bufferSize)
                    }
                    readFloatWrapped = readFloatWrapped.truncatingRemainder(dividingBy: Double(bufferSize))
                    
                    // Interpolate between samples
                    let readIndex1 = Int(readFloatWrapped) % bufferSize
                    let readIndex2 = (readIndex1 + 1) % bufferSize
                    let fraction = readFloatWrapped - Double(Int(readFloatWrapped))
                    
                    let delayedValue = buffer[readIndex1] * Float(1.0 - fraction) + buffer[readIndex2] * Float(fraction)
                    
                    // Apply tap-specific gain (decay)
                    let tapGain = pow(1.0 - decay, Float(tap))
                    tapsSum += delayedValue * tapGain
                }
                
                // Normalize taps sum based on tap count to avoid clipping
                let normalizedTapsSum = tapsSum / Float(tapCount)
                
                // Move write index forward
                writeIndex = (writeIndex + 1) % bufferSize
                
                // Mix dry and wet signals
                return inputValue * (1.0 - mixValue) + normalizedTapsSum * mixValue
            }
        }
        
        /// Creates a filter delay effect with feedback filter
        public func filterDelay(_ inputOp: @escaping FloatOp,
                                _ delayTimeSeconds: @escaping FloatOp,
                                _ feedback: @escaping FloatOp,
                                _ filterAmount: @escaping FloatOp, // 0-1, controls filter intensity
                                _ mix: @escaping FloatOp) -> FloatOp {
            
            // Constants
            let maxDelaySecs = 10.0
            let bufferSize = 12000
            
            // Initialize buffer and state
            var buffer = [Float](repeating: 0, count: bufferSize)
            var writeIndex = 0
            
            // Filter state (simple one-pole lowpass)
            var lastFilterOutput: Float = 0.0
            
            return { pos in
                // Get input value
                let inputValue = inputOp(pos)
                
                // Get parameter values
                let delayTimeSecs = delayTimeSeconds(pos)
                let feedbackValue = feedback(pos)
                let filterValue = filterAmount(pos)
                let mixValue = mix(pos)
                
                // Calculate filter coefficient based on filterAmount (0=no filtering, 1=heavy filtering)
                let filterCoeff = 0.05 + filterValue * 0.9 // Range from slight to heavy filtering
                
                // Calculate read position for delay
                let delayInSamples = Double(delayTimeSecs) * Double(bufferSize) / maxDelaySecs
                let readFloat = Double(writeIndex) - delayInSamples
                var readFloatWrapped = readFloat
                while readFloatWrapped < 0 {
                    readFloatWrapped += Double(bufferSize)
                }
                readFloatWrapped = readFloatWrapped.truncatingRemainder(dividingBy: Double(bufferSize))
                
                // Interpolate delay value
                let readIndex1 = Int(readFloatWrapped) % bufferSize
                let readIndex2 = (readIndex1 + 1) % bufferSize
                let fraction = readFloatWrapped - Double(Int(readFloatWrapped))
                
                let delayedValue = buffer[readIndex1] * Float(1.0 - fraction) + buffer[readIndex2] * Float(fraction)
                
                // Apply lowpass filter to feedback signal
                lastFilterOutput = lastFilterOutput + (delayedValue - lastFilterOutput) * filterCoeff
                
                // Apply feedback with filtering
                buffer[writeIndex] = inputValue + lastFilterOutput * feedbackValue
                
                // Move write index forward
                writeIndex = (writeIndex + 1) % bufferSize
                
                // Mix dry and wet signals
                return inputValue * (1.0 - mixValue) + delayedValue * mixValue
            }
        }
        
        /// Creates a trigger delay that works with binary trigger signals (0.0 or 1.0)
        public func triggerDelay(_ triggerOp: @escaping FloatOp,
                                 _ delayTimeSeconds: @escaping FloatOp,
                                 _ feedback: Int = 1) -> FloatOp {
            // Store timestamp history of triggers
            var triggerTimes: [Double] = []
            var lastProcessTime: Double = CACurrentMediaTime()
            var lastTriggerState: Bool = false
            
            return { pos in
                let currentTime = CACurrentMediaTime()
                let elapsedTime = currentTime - lastProcessTime
                lastProcessTime = currentTime
                
                // Get current trigger state (consider values > 0.5 as "on")
                let currentTriggerState = triggerOp(pos) > 0.5
                
                // Detect rising edge (new trigger)
                if currentTriggerState && !lastTriggerState {
                    // Add new trigger to the history
                    triggerTimes.append(currentTime)
                }
                
                // Update last trigger state
                lastTriggerState = currentTriggerState
                
                // Calculate delay time in seconds
                let delaySecs = delayTimeSeconds(pos)
                
                // Remove old triggers that are no longer needed
                // (keeping those that might still produce echoes based on feedback)
                let oldestAllowedTime = currentTime - (Double(delaySecs) * Double(feedback) + 0.1)
                triggerTimes = triggerTimes.filter { $0 > oldestAllowedTime }
                
                // Check if any delayed trigger is active right now
                for i in 0..<Swift.min(feedback, triggerTimes.count) {
                    let triggerTime = triggerTimes[triggerTimes.count - 1 - i]
                    let delayedTime = triggerTime + (Double(delaySecs) * Double(i + 1))
                    
                    // Trigger is active if we're within 10ms of the delayed time
                    // This creates a short pulse rather than a continuous signal
                    if currentTime >= delayedTime && currentTime < delayedTime + 0.01 {
                        return 1.0
                    }
                }
                
                // No delayed trigger is currently active
                return 0.0
            }
        }
        
        /// Creates rhythmic pattern delay with subdivision and probability controls
        public func rhythmicTriggerDelay(_ triggerOp: @escaping FloatOp,
                                         _ division: Int = 4,           // Subdivisions (e.g., 4 = 16th notes from quarter)
                                         _ probability: @escaping FloatOp, // Probability of each subdivision triggering
                                         _ bpm: @escaping FloatOp,      // Tempo in BPM
                                         _ swing: Float = 0.0) -> FloatOp {
            var lastTriggerState: Bool = false
            var patternActive: Bool = false
            var patternStartTime: Double = 0
            var patternTriggers: [Bool] = []
            
            return { pos in
                // Get current trigger and parameter values
                let currentTrigger = triggerOp(pos) > 0.5
                let currentBPM = bpm(pos)
                let currentProb = probability(pos)
                
                // Calculate timing variables
                let beatDurationSecs = 60.0 / currentBPM
                let patternDurationSecs = beatDurationSecs
                let stepDurationSecs = Double(patternDurationSecs) / Double(division)
                let currentTime = CACurrentMediaTime()
                
                // Detect rising edge (new trigger)
                if currentTrigger && !lastTriggerState {
                    // Start a new pattern
                    patternActive = true
                    patternStartTime = currentTime
                    
                    // Generate the subdivision pattern with probability
                    patternTriggers = (0..<division).map { step in
                        // Apply swing to even-numbered subdivisions
                        if step % 2 == 1 && swing > 0 {
                            return Float.random(in: 0...1) < currentProb
                        } else {
                            return Float.random(in: 0...1) < currentProb
                        }
                    }
                }
                
                // Update last trigger state
                lastTriggerState = currentTrigger
                
                // If pattern is active, check if we're on a subdivision hit
                if patternActive {
                    // Calculate elapsed time in pattern
                    let elapsedTime = currentTime - patternStartTime
                    
                    // Check if pattern is still active
                    if elapsedTime > Double(patternDurationSecs) {
                        patternActive = false
                        return 0.0
                    }
                    
                    // Calculate which step we're on
                    var stepIndex = Int(elapsedTime / stepDurationSecs)
                    
                    // Apply swing to even-numbered subdivisions
                    if stepIndex % 2 == 1 && swing > 0 {
                        let swingOffset = stepDurationSecs * Double(swing)
                        if elapsedTime < (Double(stepIndex) * stepDurationSecs + swingOffset) {
                            stepIndex -= 1 // Still on previous step due to swing
                        }
                    }
                    
                    // Bound check
                    if stepIndex >= 0 && stepIndex < division && stepIndex < patternTriggers.count {
                        // Return 1.0 for a brief moment at the start of a subdivision hit
                        var stepStartTime = Double(stepIndex) * stepDurationSecs
                        // Apply swing
                        if stepIndex % 2 == 1 && swing > 0 {
                            stepStartTime += stepDurationSecs * Double(swing)
                        }
                        
                        // Create a short 10ms pulse
                        if elapsedTime >= stepStartTime &&
                            elapsedTime < stepStartTime + 0.01 &&
                            patternTriggers[stepIndex] {
                            return 1.0
                        }
                    }
                }
                
                return 0.0
            }
        }
        
        /// Creates Euclidean rhythm patterns from trigger inputs
        public func euclideanTriggerDelay(_ triggerOp: @escaping FloatOp,
                                          _ stepsParam: Int = 16,
                                          _ pulsesOp: @escaping FloatOp,
                                          _ rotationOp: @escaping FloatOp,
                                          _ bpmOp: @escaping FloatOp) -> FloatOp {
            
            // Define these variables outside of the closure
            var lastTrigger = false
            var isActive = false
            var startTime: Double = 0.0
            var currentPattern: [Bool] = []
            
            // Directly implement the Euclidean algorithm instead of calling a helper
            func euclidean(steps: Int, pulses: Int, rotate: Int) -> [Bool] {
                if pulses >= steps { return [Bool](repeating: true, count: steps) }
                if pulses <= 0 { return [Bool](repeating: false, count: steps) }
                
                var pattern = [Bool](repeating: false, count: steps)
                let div = steps / pulses
                let rem = steps % pulses
                
                for i in 0..<pulses {
                    pattern[i * div + Swift.min(i, rem)] = true
                }
                
                // Rotate pattern
                if rotate > 0 {
                    let r = rotate % steps
                    return Array(pattern[r..<steps] + pattern[0..<r])
                }
                
                return pattern
            }
            
            // Return the basic FloatOp without type annotation
            return { pos in
                let now = CACurrentMediaTime()
                let trigger = triggerOp(pos) > 0.5
                let bpm = bpmOp(pos)
                
                // Trigger edge detection
                if trigger && !lastTrigger {
                    isActive = true
                    startTime = now
                    
                    // Generate pattern
                    let p = Swift.min(Swift.max(Int(pulsesOp(pos) * Float(stepsParam)), 1), stepsParam)
                    let r = Int(rotationOp(pos) * Float(stepsParam)) % stepsParam
                    currentPattern = euclidean(steps: stepsParam, pulses: p, rotate: r)
                }
                lastTrigger = trigger
                
                if !isActive { return 0.0 }
                
                // Calculate timing
                let barDuration = 240.0 / bpm  // 4 beats at current tempo
                let stepDuration = Double(barDuration) / Double(stepsParam)
                let elapsed = now - startTime
                
                // Check if pattern is still active
                if elapsed > Double(barDuration) {
                    isActive = false
                    return 0.0
                }
                
                // Determine current step and check pattern
                let step = Int(elapsed / stepDuration) % stepsParam
                if step < currentPattern.count && currentPattern[step] {
                    // Return pulse only at the beginning of the step
                    return elapsed.truncatingRemainder(dividingBy: stepDuration) < 0.01 ? 1.0 : 0.0
                }
                
                return 0.0
            }
        }
        
        /// Creates Euclidean rhythm patterns from trigger inputs
//        public func euclideanTriggerDelay(_ triggerOp: @escaping FloatOp,
//                                          _ steps: Int = 16,
//                                          _ pulses: @escaping FloatOp,
//                                          _ rotation: @escaping FloatOp,
//                                          _ bpm: @escaping FloatOp) -> FloatOp {
//            // Explicitly create the FloatOp we'll return
//            let resultOp: FloatOp = { (pos: Float) -> Float in
//                // Static state variables to keep state across function calls
//                struct State {
//                    static var lastTriggerState: Bool = false
//                    static var patternActive: Bool = false
//                    static var patternStartTime: Double = 0
//                    static var euclideanPattern: [Bool] = []
//                }
//                
//                // Get current trigger and parameter values
//                let currentTrigger = triggerOp(pos) > 0.5
//                let currentBPM = bpm(pos)
//                let currentPulses = Int(max(1, min(Float(steps), pulses(pos) * Float(steps))))
//                let currentRotation = Int(rotation(pos) * Float(steps)) % steps
//                
//                // Calculate timing variables
//                let barDurationSecs = 240.0 / currentBPM // Assuming 4/4 time
//                let stepDurationSecs = barDurationSecs / Double(steps)
//                let currentTime = CACurrentMediaTime()
//                
//                // Detect rising edge (new trigger)
//                if currentTrigger && !State.lastTriggerState {
//                    // Start a new pattern
//                    State.patternActive = true
//                    State.patternStartTime = currentTime
//                    
//                    // Generate Euclidean rhythm (Bjorklund's algorithm)
//                    State.euclideanPattern = generateEuclideanRhythm(steps: steps,
//                                                                     pulses: currentPulses,
//                                                                     rotation: currentRotation)
//                }
//                
//                // Update last trigger state
//                State.lastTriggerState = currentTrigger
//                
//                // If pattern is active, check if we're on a hit
//                if State.patternActive {
//                    // Calculate elapsed time in pattern
//                    let elapsedTime = currentTime - State.patternStartTime
//                    
//                    // Check if pattern is still active (one bar)
//                    if elapsedTime > barDurationSecs {
//                        State.patternActive = false
//                        return 0.0
//                    }
//                    
//                    // Calculate which step we're on
//                    let stepIndex = Int(elapsedTime / stepDurationSecs) % steps
//                    
//                    // Return 1.0 for a brief moment at the start of a hit
//                    if stepIndex >= 0 && stepIndex < State.euclideanPattern.count &&
//                        State.euclideanPattern[stepIndex] {
//                        // Only output on the first 10ms of the step for a trigger pulse
//                        let stepStartTime = Double(stepIndex) * stepDurationSecs
//                        if elapsedTime >= stepStartTime && elapsedTime < stepStartTime + 0.01 {
//                            return 1.0
//                        }
//                    }
//                }
//                
//                return 0.0
//            }
//            
//            return resultOp
//        }
        
        /// Creates a polyrhythmic trigger generator from a single input
        public func polyTriggerDelay(_ triggerOp: @escaping FloatOp,
                                     _ rhythms: [Int] = [3, 4, 5],    // Array of different subdivisions
                                     _ bpm: @escaping FloatOp) -> [(Int, FloatOp)] {  // Returns tuples of (rhythm, op)
            var outputs: [(Int, FloatOp)] = []
            
            // Create a separate trigger output for each rhythm
            for rhythm in rhythms {
                let triggerOutput: FloatOp = { pos in
                    // Implementation for each rhythm stream goes here
                    let currentTrigger = triggerOp(pos)
                    let currentBPM = bpm(pos)
                    
                    // Static variables for this closure
                    struct State {
                        static var lastTriggerState: [Int: Bool] = [:]
                        static var patternActive: [Int: Bool] = [:]
                        static var patternStartTime: [Int: Double] = [:]
                    }
                    
                    // Initialize state for this rhythm if needed
                    if State.lastTriggerState[rhythm] == nil {
                        State.lastTriggerState[rhythm] = false
                        State.patternActive[rhythm] = false
                        State.patternStartTime[rhythm] = 0
                    }
                    
                    // Get current trigger state
                    let isTrigger = currentTrigger > 0.5
                    
                    // Detect rising edge (new trigger)
                    if isTrigger && !(State.lastTriggerState[rhythm] ?? false) {
                        State.patternActive[rhythm] = true
                        State.patternStartTime[rhythm] = CACurrentMediaTime()
                    }
                    
                    // Update last trigger state
                    State.lastTriggerState[rhythm] = isTrigger
                    
                    // If pattern is active, check if we're at a subdivision point
                    if State.patternActive[rhythm] ?? false {
                        let currentTime = CACurrentMediaTime()
                        let elapsed = currentTime - (State.patternStartTime[rhythm] ?? 0)
                        
                        // Calculate bar duration (4 beats)
                        let barDuration = 240.0 / currentBPM
                        
                        // Calculate step duration for this rhythm
                        let stepDuration = Double(barDuration) / Double(rhythm)
                        
                        // Check if we're still within the pattern
                        if elapsed > Double(barDuration) {
                            State.patternActive[rhythm] = false
                            return 0.0
                        }
                        
                        // Calculate current step
                        let step = Int(elapsed / stepDuration)
                        
                        // Output trigger at the start of each step
                        let stepStartTime = Double(step) * stepDuration
                        if elapsed >= stepStartTime && elapsed < stepStartTime + 0.01 {
                            return 1.0
                        }
                    }
                    
                    return 0.0
                }
                
                outputs.append((rhythm, triggerOutput))
            }
            
            return outputs
        }
        
        // MARK: - Experimental
        
        /// Markov chain for generating sequences
        public func markovSequence(_ transitionMatrix: [[Float]],
                                   _ triggerOp: @escaping FloatOp) -> FloatOp {
            var currentState = 0
            var lastTriggerState = false
            
            return { pos in
                let trigger = triggerOp(pos) > 0.5
                
                // On new trigger, transition to next state
                if trigger && !lastTriggerState {
                    // Get probabilities for current state
                    let probs = transitionMatrix[currentState]
                    
                    // Generate random value
                    let rand = Float.random(in: 0..<1)
                    
                    // Find next state based on cumulative probability
                    var cumProb: Float = 0
                    for (nextState, prob) in probs.enumerated() {
                        cumProb += prob
                        if rand < cumProb {
                            currentState = nextState
                            break
                        }
                    }
                }
                
                lastTriggerState = trigger
                return Float(currentState) / Float(transitionMatrix.count - 1)
            }
        }
        
        /// Pattern memory system to record and replay sequences
        public func patternRecorder(_ inputOp: @escaping FloatOp,
                                    _ recordTrigger: @escaping FloatOp,
                                    _ patternLength: Float = 1.0) -> FloatOp {
            var pattern: [Float] = []
            var isRecording = false
            var playbackPos: Float = 0
            var lastRecordTrigger = false
            
            return { pos in
                let record = recordTrigger(pos) > 0.5
                
                // Toggle recording state on trigger edge
                if record && !lastRecordTrigger {
                    isRecording = !isRecording
                    if isRecording {
                        pattern = [] // Clear pattern when starting recording
                    }
                }
                lastRecordTrigger = record
                
                if isRecording {
                    // Record value
                    pattern.append(inputOp(pos))
                    return inputOp(pos) // Pass through while recording
                } else {
                    // Playback mode
                    if pattern.isEmpty {
                        return inputOp(pos) // No pattern recorded yet
                    }
                    
                    // Calculate playback position
                    playbackPos = (pos / patternLength).truncatingRemainder(dividingBy: 1.0)
                    let index = Int(playbackPos * Float(pattern.count)) % pattern.count
                    
                    return pattern[index]
                }
            }
        }
        
        /// TuringMachine-inspired pattern locker with variable stability
        public func patternLocker(_ sourceOp: @escaping FloatOp,
                                  _ stabilityOp: @escaping FloatOp,
                                  _ clockOp: @escaping FloatOp,
                                  _ patternLength: Int = 16) -> FloatOp {
            var pattern = [Float](repeating: 0, count: patternLength)
            var lockStatus = [Bool](repeating: false, count: patternLength)
            var position = 0
            var lastClock = false
            
            return { pos in
                // Check for clock pulse
                let clock = clockOp(pos) > 0.5
                let stability = stabilityOp(pos)
                
                // Advance on rising edge of clock
                if clock && !lastClock {
                    position = (position + 1) % patternLength
                    
                    // For each step, decide whether to lock it based on stability
                    // Higher stability = more likely to stay locked
                    for i in 0..<patternLength {
                        if Float.random(in: 0...1) < stability {
                            lockStatus[i] = true // Lock this step
                        } else {
                            lockStatus[i] = false // Unlock this step
                        }
                    }
                    
                    // Update pattern with new values for unlocked positions
                    for i in 0..<patternLength {
                        if !lockStatus[i] {
                            pattern[i] = sourceOp(pos)
                        }
                    }
                }
                lastClock = clock
                
                // Return the current value from the pattern
                return pattern[position]
            }
        }
        
        /// ShiftRegister with feedback and probability control
        public func shiftRegister(_ inputOp: @escaping FloatOp,
                                  _ clockOp: @escaping FloatOp,
                                  _ feedbackProb: @escaping FloatOp,
                                  _ mutation: @escaping FloatOp,
                                  _ registerLength: Int = 8) -> FloatOp {
            var register = [Float](repeating: 0, count: registerLength)
            var lastClock = false
            
            return { pos in
                let input = inputOp(pos)
                let clock = clockOp(pos) > 0.5
                let feedback = feedbackProb(pos)
                let mutationAmt = mutation(pos)
                
                // On clock trigger
                if clock && !lastClock {
                    // Decide whether to use feedback or new input
                    let newValue: Float
                    if Float.random(in: 0...1) < feedback {
                        // Use feedback from last value with possible mutation
                        newValue = register.last! + (Float.random(in: -1...1) * mutationAmt)
                    } else {
                        // Use new input
                        newValue = input
                    }
                    
                    // Shift register
                    for i in (1..<registerLength).reversed() {
                        register[i] = register[i-1]
                    }
                    register[0] = newValue
                }
                lastClock = clock
                
                // Output current value from register
                return register[0]
            }
        }
        
        /// Captures and transforms patterns with various operations
        public func patternCapture(_ sourceOp: @escaping FloatOp,
                                   _ captureOp: @escaping FloatOp,
                                   _ rateOp: @escaping FloatOp,
                                   _ transformOp: @escaping FloatOp,
                                   _ resolution: Int = 32) -> FloatOp {
            var buffer = [Float](repeating: 0, count: resolution)
            var isCapturing = false
            var lastCapture = false
            var playbackPos: Float = 0
            var lastPlaybackPos: Float = 0
            
            // Transform types: 0=normal, 1=reverse, 2=half-speed, 3=double-speed, 4=random-jump
            
            return { pos in
                let capture = captureOp(pos) > 0.5
                let rate = rateOp(pos)
                let transform = transformOp(pos)
                
                // Toggle capture state on trigger
                if capture && !lastCapture {
                    isCapturing = !isCapturing
                    
                    // Reset position when starting new capture
                    if isCapturing {
                        playbackPos = 0
                        lastPlaybackPos = 0
                    }
                }
                lastCapture = capture
                
                // Update position based on rate
                let delta = (pos - lastPlaybackPos).truncatingRemainder(dividingBy: 1.0)
                lastPlaybackPos = pos
                
                // Calculate new position
                playbackPos = (playbackPos + delta * rate).truncatingRemainder(dividingBy: 1.0)
                
                // If capturing, record the current input
                if isCapturing {
                    let index = Int(playbackPos * Float(resolution)) % resolution
                    buffer[index] = sourceOp(pos)
                    return sourceOp(pos) // Pass through while recording
                }
                
                // Apply transform based on transformOp
                let transformType = Int(transform * 5) % 5
                
                // Calculate read position based on transform
                var readPos: Int
                switch transformType {
                case 1: // Reverse
                    readPos = resolution - 1 - Int(playbackPos * Float(resolution)) % resolution
                case 2: // Half-speed
                    readPos = Int(playbackPos * Float(resolution) * 0.5) % resolution
                case 3: // Double-speed
                    readPos = Int(playbackPos * Float(resolution) * 2) % resolution
                case 4: // Random jump (quantized)
                    if delta > 0 && Float.random(in: 0...1) < 0.1 {
                        readPos = Int.random(in: 0..<resolution)
                    } else {
                        readPos = Int(playbackPos * Float(resolution)) % resolution
                    }
                default: // Normal
                    readPos = Int(playbackPos * Float(resolution)) % resolution
                }
                
                // Return the value from the buffer
                return buffer[readPos]
            }
        }
        
        /// Detects and captures interesting/repeating patterns
        public func emergentPatternDetector(_ sourceOp: @escaping FloatOp,
                                            _ sensitivityOp: @escaping FloatOp,
                                            _ windowLength: Int = 32) -> FloatOp {
            var recentValues = [Float](repeating: 0, count: windowLength * 2)
            var capturedPattern = [Float](repeating: 0, count: windowLength)
            var patternConfidence: Float = 0.0
            var position = 0
            var useCapture = false
            
            return { pos in
                let currentValue = sourceOp(pos)
                let sensitivity = sensitivityOp(pos)
                
                // Shift recent values
                for i in (1..<recentValues.count).reversed() {
                    recentValues[i] = recentValues[i-1]
                }
                recentValues[0] = currentValue
                
                // Check if the first half of recent values resembles the second half
                // This would indicate a repeating pattern
                var similarity: Float = 0
                for i in 0..<windowLength {
                    similarity += 1.0 - Swift.abs(recentValues[i] - recentValues[i + windowLength])
                }
                similarity /= Float(windowLength)
                
                // If similarity exceeds threshold, capture the pattern
                if similarity > sensitivity && similarity > patternConfidence {
                    patternConfidence = similarity
                    for i in 0..<windowLength {
                        capturedPattern[i] = recentValues[i]
                    }
                    
                    // Start using captured pattern if confidence is high enough
                    useCapture = true
                }
                
                // If using captured pattern, cycle through it
                if useCapture {
                    position = (position + 1) % windowLength
                    return capturedPattern[position]
                } else {
                    return currentValue
                }
            }
        }
    }
}
