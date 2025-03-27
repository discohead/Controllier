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
        
        /// Creates a phasor that cycles based on elapsed time
        public func timePhasor(cycleDurationSeconds: Double = 2.0) -> FloatOp {
            if cycleDurationSeconds <= 0.0 {
                fatalError("cycleDurationSeconds must be greater than 0")
            }
            
            let cycleDurationMicros = cycleDurationSeconds * 1_000_000.0
            let startTime = Date()
            
            return { _ in
                let elapsedMicros = Date().timeIntervalSince(startTime) * 1_000_000
                return Float(fmod(elapsedMicros, cycleDurationMicros) / cycleDurationMicros)
            }
        }
        
        /// Creates a phasor that cycles based on musical tempo
        public func tempoPhasor(barsPerCycle: Double = 1.0, bpm: Double = 120.0) -> FloatOp {
            if bpm <= 0.0 {
                fatalError("bpm must be greater than 0")
            }
            if barsPerCycle <= 0.0 {
                fatalError("barsPerCycle must be greater than 0")
            }
            
            // Calculate the duration of one beat in seconds
            let beatDurationSecs = 60.0 / bpm
            
            // Assuming a 4/4 time signature, calculate the duration of one bar
            let barDurationSecs = beatDurationSecs * 4
            
            // Calculate the duration of the entire cycle (in seconds)
            let cycleDurationSecs = barDurationSecs * barsPerCycle
            
            // Convert to time phasor
            return timePhasor(cycleDurationSeconds: cycleDurationSecs)
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
                
                // Ensure index is within bounds
                let xIndexNext = Swift.min(xIndex + 1, wTable.count - 1)
                
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
                
                // Ensure index is within bounds
                let xIndexNext = Swift.min(xIndex + 1, wTable.count - 1)
                
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
                
                // Ensure indices are within bounds
                let xIndexNext = Swift.min(xIndex + 1, wTable.count - 1)
                let yIndexNext = Swift.min(yIndex + 1, wTable[0].count - 1)
                
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
                
                // Ensure indices are within bounds
                let xIndexNext = Swift.min(xIndex + 1, wTable.count - 1)
                let yIndexNext = Swift.min(yIndex + 1, wTable[0].count - 1)
                
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
                
                // Ensure indices are within bounds
                let xIndexNext = Swift.min(xIndex + 1, wTable.count - 1)
                let yIndexNext = Swift.min(yIndex + 1, wTable[0].count - 1)
                let zIndexNext = Swift.min(zIndex + 1, wTable[0][0].count - 1)
                
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
                
                // Ensure indices are within bounds
                let xIndexNext = Swift.min(xIndex + 1, wTable.count - 1)
                let yIndexNext = Swift.min(yIndex + 1, wTable[0].count - 1)
                let zIndexNext = Swift.min(zIndex + 1, wTable[0][0].count - 1)
                
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
        
        /// Creates a Perlin noise function
        public func perlin(_ x: @escaping FloatOp, _ y: FloatOp? = nil, _ z: FloatOp? = nil,
                           _ falloff: FloatOp? = nil, _ octaves: FloatOp? = nil) -> FloatOp {
            let noiseSource = GKPerlinNoiseSource()
            
            return { pos in
                // Fixed line - directly convert to Int if octaves exists, otherwise use 1
                let lod = octaves != nil ? Int(octaves!(pos)) : 1
                let fof = falloff?(pos) ?? 1.0
                
                noiseSource.persistence = Double(fof)
                noiseSource.octaveCount = Swift.max(1, lod)
                
                let noise = GKNoise(noiseSource)
                
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
    }
}
