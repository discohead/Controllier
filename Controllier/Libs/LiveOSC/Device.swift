//
//  Device.swift
//  
//  Created by Jared on 3/23/25
//
//  Represents a device (instrument or effect) on an Ableton Live track,
//  analogous to PyLive's Device class. Provides methods to query the device's
//  name and to scan for its parameters.
//  
//  Note: This file assumes that a corresponding `Parameter` class exists in Parameter.swift.
//  It also assumes that AbletonOSC supports the endpoints:
//    - `/live/device/get/name`
//    - `/live/device/get/num_parameters`
//

import Foundation
import OSCKit

public final class Device {
    
    // MARK: - Public Properties
    
    /// The index of the track that this device belongs to.
    public let trackIndex: Int
    
    /// The 0-based index of this device in the track's device chain.
    public let deviceIndex: Int
    
    /// The OSC connection used to communicate with Ableton Live.
    public let connection: LiveConnection
    
    /// A list of parameters for this device, populated by scanning.
    public private(set) var parameters: [Parameter] = []
    
    // MARK: - Initialization
    
    /// Creates a new Device instance.
    /// - Parameters:
    ///   - trackIndex: The index of the track containing the device.
    ///   - deviceIndex: The device's index on that track.
    ///   - connection: The LiveConnection used for OSC communication.
    public init(trackIndex: Int, deviceIndex: Int, connection: LiveConnection) {
        self.trackIndex = trackIndex
        self.deviceIndex = deviceIndex
        self.connection = connection
    }
    
    // MARK: - Device Properties
    
    /// Retrieves the device's name from Ableton Live.
    /// - Returns: The device's name as a String.
    public func getName() async throws -> String {
        let address = "/live/device/get/name"
        let response = try await connection.query(address, arguments: [
          Int32(trackIndex),
          Int32(deviceIndex)
        ])
      guard let deviceName = response.first as? String else {
        throw LiveError.oscError("Failed to parse device name from response: \(response)")
      }
        return deviceName
    }
    
    /// Sets the device's name in Ableton Live.
    /// - Parameter newName: The new name to assign to the device.
    public func setName(_ newName: String) {
        let address = "/live/device/set/name"
        connection.send(address: address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex),
            String(newName)
        ])
    }
    
    // MARK: - Parameter Scanning
    
    /// Scans for parameters on this device and populates the `parameters` array.
    /// - Throws: A `LiveError` if the parameter count cannot be determined.
    public func scanParameters() async throws {
        let address = "/live/device/get/num_parameters"
        let response = try await connection.query(address, arguments: [
            Int32(trackIndex),
            Int32(deviceIndex)
        ])
        guard let paramCount = response.first as? Int else {
            throw LiveError.oscError("Failed to parse parameter count from response: \(response)")
        }
        
        parameters.removeAll()
        for i in 0..<paramCount {
            // Assumes Parameter has an initializer:
            // Parameter(trackIndex: Int, deviceIndex: Int, parameterIndex: Int, connection: LiveConnection)
            let param = Parameter(trackIndex: trackIndex, deviceIndex: deviceIndex, parameterIndex: i, connection: connection)
            parameters.append(param)
        }
    }
    
    // MARK: - Additional Device Functions
    
    /// Optionally, add further device-specific methods here (e.g., parameter refresh, device bypass, etc.)
}
