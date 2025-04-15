import Accelerate

extension Crvs.Ops {
    
    // MARK: - Vectorized Operations
    
    /// Generate multiple samples at once for any FloatOp
    public func generateSamples(_ op: Crvs.FloatOp, count: Int) -> [Float] {
        // Create position array (0 to 1)
        var positions = [Float](repeating: 0, count: count)
        var start: Float = 0.0
        var step = 1.0 / Float(count - 1)
        vDSP_vramp(&start, &step, &positions, 1, vDSP_Length(count))
        
        // Apply the operation to each position
        return positions.map(op)
    }
    
    /// Optimized mix operation using Accelerate for pre-calculated sample arrays
    public func mixVectorized(_ sampleArrays: [[Float]]) -> [Float] {
        guard let firstArray = sampleArrays.first, !sampleArrays.isEmpty else { 
            return [] 
        }
        
        let count = firstArray.count
        var result = [Float](repeating: 0, count: count)
        
        // Sum all arrays
        for samples in sampleArrays {
            guard samples.count == count else { continue }
            vDSP_vadd(result, 1, samples, 1, &result, 1, vDSP_Length(count))
        }
        
        // Divide by count to get average
        var divisor = Float(sampleArrays.count)
        vDSP_vsdiv(result, 1, &divisor, &result, 1, vDSP_Length(count))
        
        return result
    }
    
    /// Optimized multiplication
    public func multVectorized(_ samples: [Float], _ scalar: Float) -> [Float] {
        var result = [Float](repeating: 0, count: samples.count)
        vDSP_vsmul(samples, 1, [scalar], &result, 1, vDSP_Length(samples.count))
        return result
    }
    
    /// Optimized addition of offset
    public func biasVectorized(_ samples: [Float], _ offset: Float) -> [Float] {
        var result = [Float](repeating: 0, count: samples.count)
        vDSP_vsadd(samples, 1, [offset], &result, 1, vDSP_Length(samples.count))
        return result
    }
    
    /// Low-pass filter implementation using vDSP
    public func lpfVectorized(_ samples: [Float], _ cutoffFreq: Float, _ sampleRate: Float = 44100) -> [Float] {
        let nyquist = sampleRate / 2
        let normalizedCutoff = cutoffFreq / nyquist
        
        // Create a single-pole low-pass filter
        let alpha = 1.0 / (1.0 + (2.0 * Float.pi * normalizedCutoff))
        let a0 = 1.0 - alpha
        let a1 = 0.0
        let b1 = alpha
        
        var result = [Float](repeating: 0.0, count: samples.count)
        var sections: [Double] = [Double(a0), Double(a1), 0, 0, Double(b1), 0]
        
        // Convert to double precision for the filter
        var doubleSamples = samples.map { Double($0) }
        var doubleResults = [Double](repeating: 0.0, count: samples.count)
        
        // Apply the filter
        vDSP_deq22D(&doubleSamples, 1, &sections, &doubleResults, 1, vDSP_Length(samples.count))
        
        // Convert back to single precision
        result = doubleResults.map { Float($0) }
        
        return result
    }
    
    /// Optimized envelope follower
    public func envelopeVectorized(_ samples: [Float], _ attackTime: Float, _ releaseTime: Float, _ sampleRate: Float = 44100) -> [Float] {
        let attackCoeff = exp(-1.0 / (attackTime * sampleRate))
        let releaseCoeff = exp(-1.0 / (releaseTime * sampleRate))
        
        var envelope = [Float](repeating: 0, count: samples.count)
        var lastEnv: Float = 0.0
        
        // Apply envelope detection
        for i in 0..<samples.count {
            let absValue = Swift.abs(samples[i])
            let coeff = absValue > lastEnv ? attackCoeff : releaseCoeff
            envelope[i] = absValue + coeff * (lastEnv - absValue)
            lastEnv = envelope[i]
        }
        
        return envelope
    }
    
    /// Fast waveform data normalization
    public func normalizeVectorized(_ samples: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: samples.count)
        
        // Find min and max
        var min: Float = 0
        var max: Float = 0
        vDSP_minv(samples, 1, &min, vDSP_Length(samples.count))
        vDSP_maxv(samples, 1, &max, vDSP_Length(samples.count))
        
        // Calculate normalization factors
        let range = max - min
        if range > 0 {
            // Normalize to 0-1 range
            var negMin = -min
            vDSP_vsadd(samples, 1, &negMin, &result, 1, vDSP_Length(samples.count))
            var invRange = 1.0 / range
            vDSP_vsmul(result, 1, &invRange, &result, 1, vDSP_Length(samples.count))
        } else {
            // If no range, set all values to 0.5
            var halfValue: Float = 0.5
            vDSP_vfill(&halfValue, &result, 1, vDSP_Length(samples.count))
        }
        
        return result
    }
    
    /// Fast RMS calculation
    public func rmsVectorized(_ samples: [Float]) -> Float {
        var result: Float = 0
        vDSP_rmsqv(samples, 1, &result, vDSP_Length(samples.count))
        return result
    }
    
    /// Optimized FFT-based spectral processing using Accelerate's vectorized operations
    ///
    /// - Parameters:
    ///   - samples: The input audio samples.
    ///   - sampleRate: The sample rate of the audio (default is 44100 Hz).
    /// - Returns: The calculated spectral centroid as a Float.
    public func spectralCentroidVectorized(_ samples: [Float], _ sampleRate: Float = 44100) -> Float {
        // Determine FFT length as the next power of 2 greater than or equal to samples.count
        let log2n = vDSP_Length(log2(Double(samples.count)).rounded(.up))
        let n = vDSP_Length(1 << log2n)
        
        // Create FFT setup (destroyed in defer)
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return 0
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Prepare input data padded with zeros if needed
        var paddedSamples = samples
        if samples.count < Int(n) {
            paddedSamples.append(contentsOf: [Float](repeating: 0, count: Int(n) - samples.count))
        }
        
        // The half-length is used for split complex representation
        let halfN = Int(n / 2)
        // Create arrays for the real and imaginary parts of the split complex vector
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)
        
        // Variable to hold the resulting spectral centroid
        var spectralCentroid: Float = 0
        
        // Use nested closures to safely obtain mutable pointers with a guaranteed lifetime
        realp.withUnsafeMutableBufferPointer { realBuffer in
            imagp.withUnsafeMutableBufferPointer { imagBuffer in
                // Create the DSPSplitComplex structure using the pointers from the buffers.
                var complex = DSPSplitComplex(realp: realBuffer.baseAddress!,
                                              imagp: imagBuffer.baseAddress!)
                
                // Convert paddedSamples into split complex format.
                // First, get a pointer to paddedSamples and rebind it to DSPComplex.
                paddedSamples.withUnsafeMutableBufferPointer { samplesBuffer in
                    samplesBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { typeConvertedTransferBuffer in
                        // Convert interleaved complex input into split complex format.
                        // Note: The stride '2' means that the real and imaginary parts are interleaved.
                        vDSP_ctoz(typeConvertedTransferBuffer, 2, &complex, 1, vDSP_Length(halfN))
                    }
                }
                
                // Perform FFT on the split complex data
                vDSP_fft_zrip(fftSetup, &complex, 1, log2n, FFTDirection(kFFTDirection_Forward))
                
                // Calculate the squared magnitudes (real^2 + imag^2)
                var magnitudes = [Float](repeating: 0, count: halfN)
                vDSP_zvmags(&complex, 1, &magnitudes, 1, vDSP_Length(halfN))
                
                // Generate frequency bins corresponding to FFT bins
                var frequencies = [Float](repeating: 0, count: halfN)
                for i in 0..<halfN {
                    frequencies[i] = Float(i) * sampleRate / Float(n)
                }
                
                // Calculate the spectral centroid as weighted average:
                // centroid = sum(magnitude * frequency) / sum(magnitude)
                var weightedSum: Float = 0
                var magnitudeSum: Float = 0
                vDSP_dotpr(magnitudes, 1, frequencies, 1, &weightedSum, vDSP_Length(halfN))
                vDSP_sve(magnitudes, 1, &magnitudeSum, vDSP_Length(halfN))
                
                // Avoid division by zero
                spectralCentroid = magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
            }
        }
        
        return spectralCentroid
    }

    
    // MARK: - Vectorized Waveform Generators
    
    /// Generate vectorized sine wave samples directly
    public func sineWaveVectorized(count: Int, frequency: Float = 1.0, phase: Float = 0.0) -> [Float] {
        var result = [Float](repeating: 0, count: count)
        var positions = [Float](repeating: 0, count: count)
        
        // Create position array
        var start: Float = phase
        var step = frequency / Float(count)
        vDSP_vramp(&start, &step, &positions, 1, vDSP_Length(count))
        
        // Scale positions to 0...2π
        var scaleFactor = 2.0 * Float.pi
        vDSP_vsmul(positions, 1, &scaleFactor, &positions, 1, vDSP_Length(count))
        
        // Apply sine function
        vForce.sin(positions, result: &result)
        
        // Map from -1...1 to 0...1
        var offset: Float = 1.0
        var scale: Float = 0.5
        vDSP_vsmsa(result, 1, &scale, &offset, &result, 1, vDSP_Length(count))
        
        return result
    }
    
    /// Generate vectorized triangle wave samples directly
    public func triangleWaveVectorized(count: Int, symmetry: Float = 0.5) -> [Float] {
        var result = [Float](repeating: 0, count: count)
        var positions = [Float](repeating: 0, count: count)
        
        // Create position array (0...1)
        var start: Float = 0.0
        var step = 1.0 / Float(count - 1)
        vDSP_vramp(&start, &step, &positions, 1, vDSP_Length(count))
        
        // Apply triangle function
        for i in 0..<count {
            let pos = positions[i]
            result[i] = pos < symmetry ? (pos / symmetry) : (1.0 - ((pos - symmetry) / (1.0 - symmetry)))
        }
        
        return result
    }
}
