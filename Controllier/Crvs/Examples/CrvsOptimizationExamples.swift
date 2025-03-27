/*
# Performance Optimization Strategy Guide for Crvs

This guide provides recommendations for which optimization strategy to apply
based on different real-world use cases for the Crvs library.
*/

// MARK: - Use Case 1: Real-time Audio Synthesis

/*
When using Crvs for real-time audio synthesis, performance is critical
to avoid dropouts and maintain low latency.

Sample count: 512-4096 samples per buffer
Sampling rate: 44.1kHz or 48kHz
Update rate: 86-374 times per second (based on buffer size)
Waveforms per frame: 1-128 (depending on polyphony)

Recommended strategy:
- For 1-8 voices: Use Accelerate-optimized waveform generation
- For 8-32 voices: Use precomputed wavetables with caching
- For 32+ voices: Use Metal for batch waveform generation
*/

class AudioSynthesisExample {
    let optimizedProcessor = OptimizedWaveformProcessor()
    let preferredStrategy: OptimizedWaveformProcessor.OptimizationStrategy
    let sampleRate: Float = 44100.0
    let bufferSize = 1024
    var voices: [Voice] = []
    
    init(voiceCount: Int) {
        // Select strategy based on voice count
        if voiceCount <= 8 {
            preferredStrategy = .accelerate
        } else if voiceCount <= 32 {
            preferredStrategy = .cache
        } else {
            preferredStrategy = .metal
        }
        
        // Create voices
        for i in 0..<voiceCount {
            let frequency = 220.0 * pow(2.0, Float(i % 12) / 12.0)
            voices.append(Voice(waveformType: "sine", frequency: frequency))
        }
    }
    
    func renderAudioBuffer() -> [Float] {
        var mixBuffer = [Float](repeating: 0, count: bufferSize)
        
        // Process all voices
        for voice in voices {
            let voiceBuffer = generateVoiceBuffer(voice)
            
            // Mix voice into main buffer
            for i in 0..<bufferSize {
                mixBuffer[i] += voiceBuffer[i] * voice.amplitude
            }
        }
        
        return mixBuffer
    }
    
    private func generateVoiceBuffer(_ voice: Voice) -> [Float] {
        // Calculate frequency as fraction of sample rate
        let normalizedFreq = voice.frequency / sampleRate
        
        // Generate waveform with preferred strategy
        return optimizedProcessor.generateWaveform(
            type: voice.waveformType,
            params: [
                "frequency": normalizedFreq * Float(bufferSize),
                "phase": voice.phase
            ],
            count: bufferSize,
            forceStrategy: preferredStrategy
        )
    }
    
    // Voice representation
    struct Voice {
        let waveformType: String
        let frequency: Float
        var phase: Float = 0.0
        var amplitude: Float = 0.2
    }
}

// MARK: - Use Case 2: Animation Curves and UI

/*
When using Crvs for UI animations and easing functions, the primary
considerations are:
- Responsiveness to parameter changes
- Smooth transitions between states
- Low CPU usage to avoid impacting UI thread

Sample count: 30-120 samples per curve (matching display refresh rate)
Update rate: 60-120 times per second
Parameter changes: Frequent but predictable

Recommended strategy:
- For basic curves: Use caching with memoization
- For parameter-driven animations: Use hybrid approach, favoring caching
- For complex multi-curve animations: Batch generate with Metal
*/

class AnimationCurveExample {
    let ops = Crvs.Ops()
    
    // Create a bezier-like curve with cached operations
    func createBezierCurve(controlPoints: [CGPoint]) -> Crvs.FloatOp {
        // Create polynomial approximation of bezier curve
        let bezierOp: Crvs.FloatOp = { pos in
            // Simplified bezier approximation
            let p0 = Float(controlPoints[0].y)
            let p1 = Float(controlPoints[1].y)
            let p2 = Float(controlPoints[2].y)
            let p3 = Float(controlPoints[3].y)
            
            let t = pos
            let u = 1.0 - t
            
            // Cubic bezier formula
            return p0 * u * u * u +
                   3.0 * p1 * u * u * t +
                   3.0 * p2 * u * t * t +
                   p3 * t * t * t
        }
        
        // Cache the bezier operation for better performance
        return ops.cached(bezierOp, precision: 0.001)
    }
    
    // Create a specialized spring animation curve
    func createSpringCurve(tension: Float, friction: Float, mass: Float) -> Crvs.FloatOp {
        // Precompute the spring behavior
        let springOp = ops.precomputed({ pos in
            // Spring simulation approximation
            let b = friction / (2.0 * mass)
            let omega = sqrt(tension / mass - b * b)
            
            if pos == 0 {
                return 0
            } else if pos >= 1.0 {
                return 1.0
            }
            
            // Calculate exponential decay with oscillation
            let envelope = 1.0 - exp(-b * 6.0 * pos)
            let oscillation = sin(omega * 6.0 * pos)
            let dampedOscillation = oscillation * exp(-b * 6.0 * pos) * (1.0 / omega)
            
            return min(1.0, max(0.0, envelope - dampedOscillation * friction))
        }, tableSize: 1000)
        
        return springOp
    }
    
    // Apply animation curve to UI transition over time
    func animateProperty(from startValue: Float, to endValue: Float,
                        duration: TimeInterval, curve: Crvs.FloatOp,
                        update: @escaping (Float) -> Void) {
        let startTime = Date()
        
        func updateAnimation() {
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(Float(elapsed / duration), 1.0)
            
            // Apply the animation curve to get the eased progress
            let easedProgress = curve(progress)
            
            // Calculate the interpolated value
            let currentValue = startValue + (endValue - startValue) * easedProgress
            
            // Update the property
            update(currentValue)
            
            // Continue the animation if not complete
            if progress < 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
                    updateAnimation()
                }
            }
        }
        
        // Start the animation
        updateAnimation()
    }
}

// MARK: - Use Case 3: Data Visualization and Procedural Graphics

/*
When using Crvs for data visualization and procedural graphics, the key
considerations are:
- Handling large datasets with many data points
- Responsiveness to user interactions (pan, zoom, etc.)
- Smooth rendering of complex curves

Sample count: 1,000-1,000,000+ points
Update rate: Variable (1-60 fps depending on interaction)
Waveform complexity: Often high with many combined operations

Recommended strategy:
- For static visualizations: Precompute with Metal, then cache
- For interactive visualizations with <10K points: Use Accelerate
- For very large datasets with >100K points: Use Metal exclusively
- For intermediate cases: Use the hybrid approach
*/

class DataVisualizationExample {
    let ops = Crvs.Ops()
    let optimizedProcessor = OptimizedWaveformProcessor()
    
    // Generate smooth curve data for a line chart
    func generateSmoothCurve(dataPoints: [Float], smoothness: Float, 
                          pointCount: Int) -> [CGPoint] {
        
        // Create a smooth interpolation op
        let smoothingOp: Crvs.FloatOp = { pos in
            // Find the position in the data array
            let dataIndex = pos * Float(dataPoints.count - 1)
            let index0 = max(0, min(dataPoints.count - 1, Int(floor(dataIndex))))
            let index1 = max(0, min(dataPoints.count - 1, index0 + 1))
            
            let fraction = dataIndex - Float(index0)
            
            // Simple linear interpolation for the base points
            let baseValue = dataPoints[index0] * (1.0 - fraction) + dataPoints[index1] * fraction
            
            // Apply smoothing if requested
            if smoothness > 0 {
                // Get adjacent points for smoothing
                let indexMinus1 = max(0, index0 - 1)
                let indexPlus1 = min(dataPoints.count - 1, index1 + 1)
                
                // Apply a cubic interpolation for smoothness
                let p0 = dataPoints[indexMinus1]
                let p1 = dataPoints[index0]
                let p2 = dataPoints[index1]
                let p3 = dataPoints[indexPlus1]
                
                // Cubic Hermite spline formula
                let t = fraction
                let t2 = t * t
                let t3 = t2 * t
                
                let smoothValue = 0.5 * ((2.0 * p1) +
                                      (-p0 + p2) * t +
                                      (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
                                      (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
                
                // Blend between linear and smooth based on smoothness parameter
                return baseValue * (1.0 - smoothness) + smoothValue * smoothness
            }
            
            return baseValue
        }
        
        // Choose the optimal strategy based on point count
        let strategy: OptimizedWaveformProcessor.OptimizationStrategy
        if pointCount > 100_000 {
            strategy = .metal
        } else if pointCount > 10_000 {
            strategy = .accelerate
        } else {
            strategy = .cache
        }
        
        // Generate smooth curve with the optimal strategy
        let yValues = optimizedProcessor.generateWaveform(
            type: "custom", 
            params: ["smoothness": smoothness],
            count: pointCount,
            forceStrategy: strategy
        )
        
        // Convert to CGPoints
        var points = [CGPoint]()
        points.reserveCapacity(pointCount)
        
        for i in 0..<pointCount {
            let x = CGFloat(i) / CGFloat(pointCount - 1)
            let y = CGFloat(yValues[i])
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
    
    // Generate a complex procedural background pattern
    func generateProceduralPattern(width: Int, height: Int) -> [UInt8] {
        // For large images, use Metal to generate the pattern
        let noise1 = optimizedProcessor.generateWaveform(
            type: "perlin",
            params: ["frequency": 5.0, "octaves": 4.0],
            count: width * height,
            forceStrategy: .metal
        )
        
        let noise2 = optimizedProcessor.generateWaveform(
            type: "perlin",
            params: ["frequency": 10.0, "octaves": 2.0],
            count: width * height,
            forceStrategy: .metal
        )
        
        // Create a placeholder result array
        var result = [UInt8](repeating: 0, count: width * height * 4) // RGBA
        
        // Fill in pixel data
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixelIndex = index * 4
                
                let noiseVal1 = noise1[index]
                let noiseVal2 = noise2[index]
                let combinedValue = min(1.0, max(0.0, noiseVal1 * 0.7 + noiseVal2 * 0.3))
                
                // Create a color gradient based on noise
                result[pixelIndex] = UInt8(combinedValue * 255) // R
                result[pixelIndex + 1] = UInt8((1.0 - combinedValue) * 200) // G
                result[pixelIndex + 2] = UInt8(combinedValue * combinedValue * 255) // B
                result[pixelIndex + 3] = 255 // Alpha
            }
        }
        
        return result
    }
}

// MARK: - Use Case 4: Real-time Generative Art

/*
When using Crvs for generative art applications, you need a balance
of performance and flexibility, with considerations for:
- Interactive performance at reasonable frame rates (30-60fps)
- Complex layering of multiple waveforms and effects
- Frequent parameter changes through user interaction or automation

Sample count: Variable (1,000 - 100,000 per frame)
Waveforms per frame: 10-100+
Update rate: 30-60 fps

Recommended strategy:
- For parameter-driven animations: Use hybrid approach with caching priority
- For complex layered effects: Use Metal for batch generation
- For high-resolution outputs: Precompute with Metal, render incrementally
*/

class GenerativeArtExample {
    let ops = Crvs.Ops()
    let optimizedProcessor = OptimizedWaveformProcessor()
    
    struct Layer {
        var waveformType: String
        var frequency: Float
        var phase: Float
        var amplitude: Float
        var color: (r: Float, g: Float, b: Float, a: Float)
    }
    
    // Create a multi-layered generative artwork
    func renderFrame(width: Int, height: Int, time: Float, layers: [Layer]) -> [UInt8] {
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        
        // For interactive performance with many layers, batch process with Metal
        if layers.count > 20 {
            // Create batched parameters for Metal processing
            var types = [String]()
            var params = [[String: Float]]()
            
            for layer in layers {
                types.append(layer.waveformType)
                params.append([
                    "frequency": layer.frequency,
                    "phase": layer.phase + time // Animate phase with time
                ])
            }
            
            // Generate all waveforms in one GPU pass
            let waveforms = optimizedProcessor.generateWaveform(
                type: "multiWaveform",
                params: ["batchSize": Float(layers.count)],
                count: width,
                forceStrategy: .metal
            )
            
            // Combine layers for the final image
            for y in 0..<height {
                let heightPosition = Float(y) / Float(height)
                
                for x in 0..<width {
                    let pixelIndex = (y * width + x) * 4
                    var r: Float = 0.0
                    var g: Float = 0.0
                    var b: Float = 0.0
                    var a: Float = 0.0
                    
                    // Combine all layers for this pixel
                    for (i, layer) in layers.enumerated() {
                        let waveformValue = waveforms[i * width + x]
                        
                        // Modulate value by vertical position
                        let modulator = sin(heightPosition * Float.pi * layer.frequency)
                        let value = waveformValue * modulator * layer.amplitude
                        
                        // Additive blending of color
                        r += value * layer.color.r
                        g += value * layer.color.g
                        b += value * layer.color.b
                        a += value * layer.color.a
                    }
                    
                    // Clamp and convert to bytes
                    pixelData[pixelIndex] = UInt8(min(255, max(0, r * 255)))
                    pixelData[pixelIndex + 1] = UInt8(min(255, max(0, g * 255)))
                    pixelData[pixelIndex + 2] = UInt8(min(255, max(0, b * 255)))
                    pixelData[pixelIndex + 3] = UInt8(min(255, max(0, a * 255)))
                }
            }
        } else {
            // For fewer layers, process individually with caching
            for y in 0..<height {
                let heightPosition = Float(y) / Float(height)
                
                for x in 0..<width {
                    let pixelIndex = (y * width + x) * 4
                    var r: Float = 0.0
                    var g: Float = 0.0
                    var b: Float = 0.0
                    var a: Float = 0.0
                    
                    // Process each layer
                    for layer in layers {
                        // Generate waveform value for this position
                        let xPosition = Float(x) / Float(width)
                        
                        let params: [String: Float] = [
                            "frequency": layer.frequency,
                            "phase": layer.phase + time
                        ]
                        
                        // Get one sample at the x position
                        let sample = optimizedProcessor.generateWaveform(
                            type: layer.waveformType,
                            params: params,
                            count: 1,
                            forceStrategy: .cache
                        )[0]
                        
                        // Modulate by vertical position
                        let modulator = sin(heightPosition * Float.pi * layer.frequency)
                        let value = sample * modulator * layer.amplitude
                        
                        // Additive blending
                        r += value * layer.color.r
                        g += value * layer.color.g
                        b += value * layer.color.b
                        a += value * layer.color.a
                    }
                    
                    // Clamp and convert to bytes
                    pixelData[pixelIndex] = UInt8(min(255, max(0, r * 255)))
                    pixelData[pixelIndex + 1] = UInt8(min(255, max(0, g * 255)))
                    pixelData[pixelIndex + 2] = UInt8(min(255, max(0, b * 255)))
                    pixelData[pixelIndex + 3] = UInt8(min(255, max(0, a * 255)))
                }
            }
        }
        
        return pixelData
    }
}
