//
//  Waveforms.metal
//  Controllier
//
//  Created by Jared McFarland on 3/26/25.
//


//
// Waveforms.metal
//
// This file contains Metal shader code for waveform generation and
// is intended to be compiled as part of your Xcode project.
//

#include <metal_stdlib>
using namespace metal;

// Define M_PI_F if it isn't already defined
#ifndef M_PI_F
#define M_PI_F 3.14159265358979323846f
#endif

// Basic waveform generators

kernel void sine(device float* output [[buffer(0)]],
                 device const float* parameters [[buffer(1)]],
                 device const uint& count [[buffer(2)]],
                 uint id [[thread_position_in_grid]])
{
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
    
    // Generate sine wave value
    float value = (sin(adjustedPos * 2.0 * M_PI_F) * 0.5 + 0.5) * amplitude + offset;
    output[id] = value;
}

kernel void triangle(device float* output [[buffer(0)]],
                     device const float* parameters [[buffer(1)]],
                     device const uint& count [[buffer(2)]],
                     uint id [[thread_position_in_grid]])
{
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
                uint id [[thread_position_in_grid]])
{
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
                   uint id [[thread_position_in_grid]])
{
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
                      uint id [[thread_position_in_grid]])
{
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
    
    // Linear interpolation between table values
    float value = mix(table[index1], table[index2], fraction);
    
    output[id] = value;
}

// Multiple waveforms in one kernel

kernel void multiWaveform(device float* output [[buffer(0)]],
                          device const uint* types [[buffer(1)]],
                          device const float* allParameters [[buffer(2)]],
                          device const uint* dimensions [[buffer(3)]],
                          uint id [[thread_position_in_grid]])
{
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
            if (adjustedPos < param1) { // param1 represents symmetry
                value = adjustedPos / param1;
            } else {
                value = 1.0 - ((adjustedPos - param1) / (1.0 - param1));
            }
            break;
            
        case 2: // Saw
            value = 1.0 - adjustedPos;
            break;
            
        case 3: // Square
            value = adjustedPos < param1 ? 0.0 : 1.0; // param1 represents pulse width
            break;
            
        default:
            value = 0.5;
            break;
    }
    
    output[waveformIndex * sampleCount + sampleIndex] = value * amplitude + offset;
}
