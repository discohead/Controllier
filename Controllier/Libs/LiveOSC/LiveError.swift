//
//  LiveError.swift
//  
//  Created by Jared on 3/23/25
//
//  This file defines the custom error types that can occur when communicating
//  with Ableton Live via OSC.
//

import Foundation

/// Describes errors that can occur during OSC communication or
/// when interacting with the Ableton Live API via OSC.
public enum LiveError: Error {
    /// Thrown when the connection to Ableton Live is not established.
    case notConnected
    
    /// Thrown when an OSC query takes too long to respond.
    case timeout
    
    /// Thrown when an OSC-specific error occurs, for example if we receive
    /// malformed data or have issues binding the ports.
    case oscError(String)
    
    /// Thrown for any other miscellaneous errors that don't fit the other cases.
    case unknown(String)
    
    /// A developer-friendly description of the error.
    public var description: String {
        switch self {
        case .notConnected:
            return "No connection to Ableton Live. Make sure AbletonOSC is running."
        case .timeout:
            return "The request to Ableton Live timed out."
        case .oscError(let message):
            return "An OSC error occurred: \(message)"
        case .unknown(let reason):
            return "An unknown error occurred: \(reason)"
        }
    }
}
