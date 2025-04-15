//
//  LiveSet.swift
//  
//  Created by Jared on 3/23/25
//
//  This file implements the central "Set" object, analogous to PyLive's Set class,
//  providing high-level access to global properties (e.g. tempo, transport) and tracks.
//

import Foundation
import OSCKit

/// Represents the Ableton Live "Set" (a.k.a. the Song in Live's API).
/// Provides global methods and properties (tempo, transport, overdub, etc.)
/// and also manages a list of Track objects discovered via scanning.
public final class LiveSet {
    
    // MARK: - Public Properties
    
    /// The OSC connection used to communicate with Ableton Live.
    /// Typically injected during initialization.
    public let connection: LiveConnection
    
    /// A list of Track objects representing the tracks in this Live set.
    /// Populated by calling `scan()`.
    public private(set) var tracks: [Track] = []
    
    // MARK: - Initialization
    
    /// Create a new LiveSet instance, referencing an existing LiveConnection.
    /// - Parameters:
    ///   - connection: The LiveConnection instance (must be connected).
    ///   - autoScan: Whether to automatically scan for tracks upon initialization.
    public init(
        connection: LiveConnection,
        autoScan: Bool = false
    ) async throws {
        self.connection = connection
        
        if autoScan {
            try await scan()
        }
    }
    
    // MARK: - Global Song Properties
    
    /// Gets the current tempo in BPM from Ableton Live.
    /// - Returns: The current tempo as a Double.
    public func getTempo() async throws -> Double {
        let response = try await connection.query("/live/song/get/tempo")
        guard let value = response.first as? Float32 else {
            throw LiveError.oscError("Failed to parse tempo from response \(response)")
        }
        return Double(value)
    }
    
    /// Sets the tempo (in BPM) in Ableton Live.
    /// - Parameter bpm: The BPM value to set.
    public func setTempo(_ bpm: Double) {
        // AbletonOSC generally expects float32 values; we'll convert our Double to Float.
        connection.send(address: "/live/song/set/tempo", 
                        arguments: [Float32(bpm)])
    }
    
    /// Starts Live transport (equivalent to pressing Play).
    public func startPlaying() {
        connection.send(address: "/live/song/start_playing")
    }
    
    /// Stops Live transport (equivalent to pressing Stop).
    public func stopPlaying() {
        connection.send(address: "/live/song/stop_playing")
    }
    
    /// Stops all clips in the session, but does not stop the global transport.
    public func stopAllClips() {
        connection.send(address: "/live/song/stop_all_clips")
    }
    
    /// Launches a scene at the specified index (0-based), causing all clips in that scene to fire.
    /// - Parameter index: The scene index to trigger.
    public func triggerScene(_ index: Int) {
        connection.send(address: "/live/scene/fire", arguments: [Int32(index)])
    }
    
    // MARK: - Scanning
    
    /// Scans the current Live set to discover and populate the `tracks` list.
    /// This method queries Ableton Live for the number of tracks, then instantiates
    /// a Track object for each. Clip/device scanning will be handled in Track/Clip later.
    public func scan() async throws {
        // 1. Query how many tracks are in the set
        let response = try await connection.query("/live/song/get/num_tracks")
        guard let trackCount = response.first as? Int32 else {
            throw LiveError.oscError("Failed to parse track count from response \(response)")
        }
        
        // 2. Clear any existing list and re-populate
        tracks.removeAll()
        for trackIndex in 0..<trackCount {
            // We'll define Track in Track.swift. For now, assume a minimal initializer:
            let newTrack = Track(index: Int(trackIndex), connection: connection)
            tracks.append(newTrack)
        }
    }
}
