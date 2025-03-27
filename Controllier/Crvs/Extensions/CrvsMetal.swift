import Metal
import MetalKit

/// GPU-accelerated waveform generation and processing
extension Crvs {
    
    // MARK: - Metal Waveform Processor
    
    public class MetalWaveformProcessor {
        private let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private let library: MTLLibrary
        
        // Pre-compiled compute pipelines
        private var pipelines: [String: MTLComputePipelineState] = [:]
        
        // Initialize Metal resources
        public init?() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue(),
                  let library = device.makeDefaultLibrary() else {
                return nil
            }
            
            self.device = device
            self.commandQueue = commandQueue
            self.library = library
            
            // Precompile common pipelines
            do {
                try compilePipelines()
            } catch {
                print("Failed to compile Metal pipelines: \(error)")
                return nil
            }
        }
        
        // Precompile all waveform compute pipelines
        private func compilePipelines() throws {
            let waveformTypes = ["sine", "triangle", "saw", "square", "wavetable", "multiWaveform"]
            
            for type in waveformTypes {
                guard let function = library.makeFunction(name: type) else {
                    continue
                }
                
                let pipeline = try device.makeComputePipelineState(function: function)
                pipelines[type] = pipeline
            }
        }
        
        // MARK: - Waveform Generation
        
        /// Generate basic waveform samples on the GPU
        public func generateWaveform(type: String, count: Int, params: [String: Float] = [:]) -> [Float] {
            guard let pipeline = pipelines[type] else {
                print("Pipeline not found for waveform type: \(type)")
                return [Float](repeating: 0, count: count)
            }
            
            // Create buffers
            let outputBuffer = device.makeBuffer(length: count * MemoryLayout<Float>.size, options: .storageModeShared)!
            
            // Create parameter buffer
            var parameters = [Float](repeating: 0, count: 16) // Support up to 16 parameters
            
            // Common parameters
            parameters[0] = params["frequency"] ?? 1.0
            parameters[1] = params["phase"] ?? 0.0
            parameters[2] = params["amplitude"] ?? 1.0
            parameters[3] = params["offset"] ?? 0.0
            
            // Specialized parameters
            switch type {
            case "sine":
                parameters[4] = params["feedback"] ?? 0.0
            case "triangle":
                parameters[4] = params["symmetry"] ?? 0.5
            case "square":
                parameters[4] = params["pulseWidth"] ?? 0.5
            default:
                break
            }
            
            let parametersBuffer = device.makeBuffer(bytes: &parameters, 
                                                    length: parameters.count * MemoryLayout<Float>.size, 
                                                    options: .storageModeShared)!
            
            // Execute compute kernel
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return [Float](repeating: 0, count: count)
            }
            
            computeEncoder.setComputePipelineState(pipeline)
            computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(parametersBuffer, offset: 0, index: 1)
            computeEncoder.setBytes([UInt32(count)], length: MemoryLayout<UInt32>.size, index: 2)
            
            // Calculate optimal thread configuration
            let threadExecutionWidth = pipeline.threadExecutionWidth
            let threadsPerGroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
            let threadgroupCount = MTLSize(width: (count + threadExecutionWidth - 1) / threadExecutionWidth, 
                                          height: 1, depth: 1)
            
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            
            // Execute and wait for completion
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // Read back results
            let outputPtr = outputBuffer.contents().bindMemory(to: Float.self, capacity: count)
            let result = Array(UnsafeBufferPointer(start: outputPtr, count: count))
            
            return result
        }
        
        /// Generate multiple waveforms simultaneously using GPU
        public func generateMultipleWaveforms(types: [String], count: Int, params: [[String: Float]]) -> [[Float]] {
            guard let pipeline = pipelines["multiWaveform"] else {
                print("Pipeline not found for multiWaveform")
                return Array(repeating: [Float](repeating: 0, count: count), count: types.count)
            }
            
            let numWaveforms = types.count
            
            // Create output buffer to hold all waveforms
            let outputBuffer = device.makeBuffer(length: count * numWaveforms * MemoryLayout<Float>.size, 
                                               options: .storageModeShared)!
            
            // Create waveform types buffer
            var typeIndices = [UInt32](repeating: 0, count: numWaveforms)
            for (i, type) in types.enumerated() {
                switch type {
                case "sine": typeIndices[i] = 0
                case "triangle": typeIndices[i] = 1
                case "saw": typeIndices[i] = 2
                case "square": typeIndices[i] = 3
                default: typeIndices[i] = 0
                }
            }
            
            let typesBuffer = device.makeBuffer(bytes: &typeIndices, 
                                              length: typeIndices.count * MemoryLayout<UInt32>.size, 
                                              options: .storageModeShared)!
            
            // Create parameters buffer
            var allParams = [Float](repeating: 0, count: numWaveforms * 16) // 16 params per waveform
            
            for i in 0..<numWaveforms {
                let baseIndex = i * 16
                let waveformParams = params[i]
                
                allParams[baseIndex + 0] = waveformParams["frequency"] ?? 1.0
                allParams[baseIndex + 1] = waveformParams["phase"] ?? 0.0
                allParams[baseIndex + 2] = waveformParams["amplitude"] ?? 1.0
                allParams[baseIndex + 3] = waveformParams["offset"] ?? 0.0
                allParams[baseIndex + 4] = waveformParams["param1"] ?? 0.5
                allParams[baseIndex + 5] = waveformParams["param2"] ?? 0.0
            }
            
            let paramsBuffer = device.makeBuffer(bytes: &allParams, 
                                               length: allParams.count * MemoryLayout<Float>.size, 
                                               options: .storageModeShared)!
            
            // Execute compute kernel
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return Array(repeating: [Float](repeating: 0, count: count), count: numWaveforms)
            }
            
            computeEncoder.setComputePipelineState(pipeline)
            computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(typesBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
            computeEncoder.setBytes([UInt32(count), UInt32(numWaveforms)], 
                                  length: 2 * MemoryLayout<UInt32>.size, index: 3)
            
            // Calculate optimal thread configuration
            let threadExecutionWidth = pipeline.threadExecutionWidth
            let threadsPerGroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
            let threadgroupCount = MTLSize(width: (count * numWaveforms + threadExecutionWidth - 1) / threadExecutionWidth, 
                                          height: 1, depth: 1)
            
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            
            // Execute and wait for completion
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // Read back results and separate into individual waveforms
            let outputPtr = outputBuffer.contents().bindMemory(to: Float.self, 
                                                            capacity: count * numWaveforms)
            
            var results: [[Float]] = []
            for i in 0..<numWaveforms {
                var waveform = [Float](repeating: 0, count: count)
                for j in 0..<count {
                    waveform[j] = outputPtr[i * count + j]
                }
                results.append(waveform)
            }
            
            return results
        }
        
        /// Process a wavetable lookup on the GPU
        public func processWavetable(table: [Float], inputValues: [Float]) -> [Float] {
            guard let pipeline = pipelines["wavetable"] else {
                print("Pipeline not found for wavetable")
                return [Float](repeating: 0, count: inputValues.count)
            }
            
            let outputCount = inputValues.count
            
            // Create buffers
            let outputBuffer = device.makeBuffer(length: outputCount * MemoryLayout<Float>.size, 
                                               options: .storageModeShared)!
            
            let inputBuffer = device.makeBuffer(bytes: inputValues, 
                                              length: inputValues.count * MemoryLayout<Float>.size, 
                                              options: .storageModeShared)!
            
            let tableBuffer = device.makeBuffer(bytes: table, 
                                              length: table.count * MemoryLayout<Float>.size, 
                                              options: .storageModeShared)!
            
            // Execute compute kernel
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return [Float](repeating: 0, count: outputCount)
            }
            
            computeEncoder.setComputePipelineState(pipeline)
            computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(inputBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(tableBuffer, offset: 0, index: 2)
            computeEncoder.setBytes([UInt32(outputCount), UInt32(table.count)], 
                                  length: 2 * MemoryLayout<UInt32>.size, index: 3)
            
            // Calculate optimal thread configuration
            let threadExecutionWidth = pipeline.threadExecutionWidth
            let threadsPerGroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
            let threadgroupCount = MTLSize(width: (outputCount + threadExecutionWidth - 1) / threadExecutionWidth, 
                                          height: 1, depth: 1)
            
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            
            // Execute and wait for completion
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // Read back results
            let outputPtr = outputBuffer.contents().bindMemory(to: Float.self, capacity: outputCount)
            let result = Array(UnsafeBufferPointer(start: outputPtr, count: outputCount))
            
            return result
        }
    }
}

// MARK: - Metal Shader Code for Inclusion in the Project

/* 
 Below is the Metal shader code that would be compiled into the app.
 This would be saved in a .metal file in your Xcode project.
 */

/*
// Basic waveform generators
kernel void sine(device float* output [[buffer(0)]],
                 device const float* parameters [[buffer(1)]],
                 device const uint& count [[buffer(2)]],
                 uint id [[thread_position_in_grid]]) {
    
    if (id >= count) return;
    
    float frequency = parameters[0];
    float phase = parameters[1];
    float amplitude = parameters[2];
    float offset = parameters[3];
    float feedback = parameters[4];
    
    float pos = float(id) / float(count);
    float adjustedPos = pos * frequency + phase;
    
    // Apply feedback if needed
    if (feedback > 0.0) {
        adjustedPos += feedback * sin(adjustedPos * 2.0 * M_PI_F) * 0.1;
    }
    
    // Wrap to 0-1 range
    adjustedPos = fract(adjustedPos);
    
    // Generate sine
    float value = (sin(adjustedPos * 2.0 * M_PI_F) * 0.5 + 0.5) * amplitude + offset;
    output[id] = value;
}

kernel void triangle(device float* output [[buffer(0)]],
                    device const float* parameters [[buffer(1)]],
                    device const uint& count [[buffer(2)]],
                    uint id [[thread_position_in_grid]]) {
    
    if (id >= count) return;
    
    float frequency = parameters[0];
    float phase = parameters[1];
    float amplitude = parameters[2];
    float offset = parameters[3];
    float symmetry = parameters[4];
    
    float pos = float(id) / float(count);
    float adjustedPos = fract(pos * frequency + phase);
    
    // Triangle wave calculation
    float value;
    if (adjustedPos < symmetry) {
        value = adjustedPos / symmetry;
    } else {
        value = 1.0 - ((adjustedPos - symmetry) / (1.0 - symmetry));
    }
    
    output[id] = value * amplitude + offset;
}

kernel void saw(device float* output [[buffer(0)]],
              device const float* parameters [[buffer(1)]],
              device const uint& count [[buffer(2)]],
              uint id [[thread_position_in_grid]]) {
    
    if (id >= count) return;
    
    float frequency = parameters[0];
    float phase = parameters[1];
    float amplitude = parameters[2];
    float offset = parameters[3];
    
    float pos = float(id) / float(count);
    float adjustedPos = fract(pos * frequency + phase);
    
    // Saw wave calculation
    float value = 1.0 - adjustedPos;
    
    output[id] = value * amplitude + offset;
}

kernel void square(device float* output [[buffer(0)]],
                 device const float* parameters [[buffer(1)]],
                 device const uint& count [[buffer(2)]],
                 uint id [[thread_position_in_grid]]) {
    
    if (id >= count) return;
    
    float frequency = parameters[0];
    float phase = parameters[1];
    float amplitude = parameters[2];
    float offset = parameters[3];
    float pulseWidth = parameters[4];
    
    float pos = float(id) / float(count);
    float adjustedPos = fract(pos * frequency + phase);
    
    // Square wave calculation
    float value = adjustedPos < pulseWidth ? 0.0 : 1.0;
    
    output[id] = value * amplitude + offset;
}

// Wavetable lookup
kernel void wavetable(device float* output [[buffer(0)]],
                    device const float* inputs [[buffer(1)]],
                    device const float* table [[buffer(2)]],
                    device const uint* dimensions [[buffer(3)]],
                    uint id [[thread_position_in_grid]]) {
    
    if (id >= dimensions[0]) return;
    
    float position = inputs[id];
    uint tableSize = dimensions[1];
    
    // Ensure position is in 0-1 range
    position = fract(position);
    
    // Calculate table indices and interpolation factor
    float scaledPos = position * (tableSize - 1);
    uint index1 = uint(scaledPos);
    uint index2 = (index1 + 1) % tableSize;
    float fraction = scaledPos - float(index1);
    
    // Linear interpolation
    float value = mix(table[index1], table[index2], fraction);
    
    output[id] = value;
}

// Multiple waveforms in one kernel
kernel void multiWaveform(device float* output [[buffer(0)]],
                        device const uint* types [[buffer(1)]],
                        device const float* allParameters [[buffer(2)]],
                        device const uint* dimensions [[buffer(3)]],
                        uint id [[thread_position_in_grid]]) {
    
    uint sampleCount = dimensions[0];
    uint waveformCount = dimensions[1];
    
    uint waveformIndex = id / sampleCount;
    uint sampleIndex = id % sampleCount;
    
    if (waveformIndex >= waveformCount || sampleIndex >= sampleCount) return;
    
    uint waveformType = types[waveformIndex];
    uint paramOffset = waveformIndex * 16; // 16 parameters per waveform
    
    float frequency = allParameters[paramOffset + 0];
    float phase = allParameters[paramOffset + 1];
    float amplitude = allParameters[paramOffset + 2];
    float offset = allParameters[paramOffset + 3];
    float param1 = allParameters[paramOffset + 4]; // Type-specific parameter
    
    float pos = float(sampleIndex) / float(sampleCount);
    float adjustedPos = fract(pos * frequency + phase);
    
    float value = 0.0;
    
    // Generate waveform based on type
    switch (waveformType) {
        case 0: // Sine
            value = sin(adjustedPos * 2.0 * M_PI_F) * 0.5 + 0.5;
            break;
            
        case 1: // Triangle
            if (adjustedPos < param1) { // param1 = symmetry
                value = adjustedPos / param1;
            } else {
                value = 1.0 - ((adjustedPos - param1) / (1.0 - param1));
            }
            break;
            
        case 2: // Saw
            value = 1.0 - adjustedPos;
            break;
            
        case 3: // Square
            value = adjustedPos < param1 ? 0.0 : 1.0; // param1 = pulse width
            break;
            
        default:
            value = 0.5;
            break;
    }
    
    output[waveformIndex * sampleCount + sampleIndex] = value * amplitude + offset;
}
*/
