//
//  Constants.swift
//  
//  Created by Jared on 3/23/25
//
//  This file defines constants and enumerations that mirror some of PyLive's
//  internal codes, as well as useful default values for ports, etc.
//

import Foundation

/// Default OSC ports for communication with AbletonOSC
/// - sendPort: the port we send data to (AbletonOSC listens on this port)
/// - receivePort: the port we listen on for replies
public struct LiveDefaults {
    public static let defaultSendPort = 11000
    public static let defaultReceivePort = 11001
}

/// Clip status in Ableton Live (mirroring PyLive & AbletonOSC codes).
///
/// These might correspond to an integer code from AbletonOSC replies:
/// - 0 = No clip present
/// - 1 = Clip stopped
/// - 2 = Clip playing
/// - 3 = Clip triggered
///
/// Provide an enum to handle it more safely in Swift.
public enum ClipStatus: Int {
    case empty      = 0
    case stopped    = 1
    case playing    = 2
    case triggered  = 3
}

/// Convenience for converting integer statuses from OSC messages to a `ClipStatus`.
extension ClipStatus {
    public static func from(_ rawValue: Int) -> ClipStatus {
        return ClipStatus(rawValue: rawValue) ?? .empty
    }
}

/// Optional enumeration for track types or other categories if needed.
/// You can decide how best to populate or detect track types within your logic.
public enum TrackType {
    case audio
    case midi
    case returnTrack
    case master
    case group
    case unknown
}
