//
//  Parameter.swift
//  
//  Created by Jared on 3/23/25
//
//  Represents a parameter (e.g., a knob or slider) on an Ableton Live device,
//  analogous to PyLive's Parameter class.
//  Provides methods to query the parameter's name, current value, min/max range,
//  and whether it's quantized, as well as updating the parameter value.
//

import Foundation
import OSCKit

public final class Parameter {
    
    // MARK: - Public Properties
    
    /// The index of the track that contains this parameter's device.
    public let trackIndex: Int
    
    /// The index of the device on the track.
    public let deviceIndex: Int
    
    /// The 0-based index of this parameter on the device.
    public let parameterIndex: Int
    
    /// The OSC connection used to communicate with Ableton Live.
    public let connection: LiveConnection
    
    // MARK: - Initialization
    
    /// Creates a new Parameter instance.
    ///
    /// - Parameters:
    ///   - trackIndex: The index of the track containing the device.
    ///   - deviceIndex: The index of the device in that track.
    ///   - parameterIndex: The parameter's index within the device.
    ///   - connection: The LiveConnection used for OSC messaging.
    public init(trackIndex: Int, deviceIndex: Int, parameterIndex: Int, connection: LiveConnection) {
        self.trackIndex = trackIndex
        self.deviceIndex = deviceIndex
        self.parameterIndex = parameterIndex
        self.connection = connection
    }
    
    // MARK: - Parameter Information
    
    /// Retrieves the name of this parameter.
    ///
    /// - Returns: The parameter's name as a String.
    public func getName() async throws -> String {
        let address = "/live/device/get/parameter/name"
        let response = try await connection.query(address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex),
            Int32(parameterIndex)
        ])
        guard let name = response.first as? String else {
            throw LiveError.oscError("Failed to parse parameter name from response: \(response)")
        }
        return name
    }
    
    /// Retrieves the current value of this parameter.
    ///
    /// - Returns: The current parameter value as a Float.
    public func getValue() async throws -> Float {
        let address = "/live/device/get/parameter/value"
        let response = try await connection.query(address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex),
            Int32(parameterIndex)
        ])
        guard let value = response.first as? Float else {
            throw LiveError.oscError("Failed to parse parameter value from response: \(response)")
        }
        return value
    }
    
    /// Updates the value of this parameter.
    ///
    /// - Parameter newValue: The new value to be set.
    public func setValue(_ newValue: Float) {
        let address = "/live/device/set/parameter/value"
        connection.send(address: address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex),
            Int32(parameterIndex),
            Float32(newValue)
        ])
    }
    
    /// Retrieves the minimum value allowed for this parameter.
    ///
    /// - Returns: The minimum value as a Float.
    public func getMin() async throws -> Float {
        let address = "/live/device/get/parameter/min"
        let response = try await connection.query(address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex),
            Int32(parameterIndex)
        ])
        guard let minValue = response.first as? Float else {
            throw LiveError.oscError("Failed to parse parameter min from response: \(response)")
        }
        return minValue
    }
    
    /// Retrieves the maximum value allowed for this parameter.
    ///
    /// - Returns: The maximum value as a Float.
    public func getMax() async throws -> Float {
        let address = "/live/device/get/parameter/max"
        let response = try await connection.query(address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex),
            Int32(parameterIndex)
        ])
        guard let maxValue = response.first as? Float else {
            throw LiveError.oscError("Failed to parse parameter max from response: \(response)")
        }
        return maxValue
    }
    
    /// (Optional) Checks whether this parameter is quantized.
    ///
    /// - Returns: True if the parameter is quantized, false otherwise.
    /// - Note: If your AbletonOSC version doesn't support this endpoint, you can remove or modify this method.
    public func isQuantized() async throws -> Bool {
        let address = "/live/device/get/parameter/is_quantized"
        let response = try await connection.query(address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex),
            Int32(parameterIndex)
        ])
        guard let quantized = response.first as? Bool else {
            throw LiveError.oscError("Failed to parse parameter quantization state from response: \(response)")
        }
        return quantized
    }
}
