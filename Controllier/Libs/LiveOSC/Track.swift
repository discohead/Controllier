//
//  Track.swift
//  
//  Created by Jared on 3/23/25
//
//  Represents an Ableton Live track, analogous to PyLive's Track class.
//  Handles basic properties (name, mute, etc.) and references to clips/devices.
//

import Foundation
import OSCKit

public final class Track {
    
    // MARK: - Public Properties
    
    /// The 0-based index of this track in Ableton Live.
    public let index: Int
    
    /// Reference to the LiveConnection for querying/updating this track.
    public let connection: LiveConnection
    
    /// A placeholder for discovered clips. We'll define Clip.swift soon.
    /// Use `[Clip?]` so that an empty slot is `nil`, matching PyLive approach.
    public private(set) var clips: [Clip?] = []
    
    /// A placeholder for discovered devices on this track. We'll define Device.swift later.
    public private(set) var devices: [Device] = []
    
    // MARK: - Initialization
    
    public init(index: Int, connection: LiveConnection) {
        self.index = index
        self.connection = connection
    }
    
    // MARK: - Basic Track Properties
    
    /// Gets the track's name from Ableton Live.
    public func getName() async throws -> String {
        // `/live/track/get/name <int trackIndex>`
        let response = try await connection.query("/live/track/get/name", arguments: [Int32(index)])
        
        guard let str = response.first as? String else {
            throw LiveError.oscError("Failed to parse track name for track \(index) from response: \(response)")
        }
        return str
    }
    
    /// Sets the track's name in Ableton Live.
    /// - Parameter newName: The new name to be assigned to this track.
    public func setName(_ newName: String) {
        // `/live/track/set/name <trackIndex> <string>`
        connection.send(address: "/live/track/set/name", arguments: [
            Int32(index),
            String(newName)
        ])
    }
    
    /// Checks if the track is currently muted.
    /// - Returns: True if muted, false otherwise.
    public func getMute() async throws -> Bool {
        // `/live/track/get/mute <trackIndex>`
        let response = try await connection.query("/live/track/get/mute", arguments: [Int32(index)])
        
        guard let value = response.first as? Bool else {
            throw LiveError.oscError("Failed to parse mute state from response \(response)")
        }
        return value
    }
    
    /// Sets the track's mute state.
    /// - Parameter muted: True to mute, false to unmute.
    public func setMute(_ muted: Bool) {
        // `/live/track/set/mute <trackIndex> <int 0/1>`
        connection.send(address: "/live/track/set/mute", arguments: [
            Int32(index),
            muted ? 1 : 0
        ])
    }
    
    /// Checks if the track is currently soloed.
    public func getSolo() async throws -> Bool {
        // `/live/track/get/solo <trackIndex>`
        let response = try await connection.query("/live/track/get/solo", arguments: [Int32(index)])
        guard let value = response.first as? Bool else {
            throw LiveError.oscError("Failed to parse solo state from response \(response)")
        }
        return value
    }
    
    /// Sets the track's solo state.
    public func setSolo(_ soloed: Bool) {
        // `/live/track/set/solo <trackIndex> <int 0/1>`
        connection.send(address: "/live/track/set/solo", arguments: [
            Int32(index),
            soloed ? 1 : 0
        ])
    }
    
    /// Check if this track is foldable (i.e., a Group track).
    /// - Returns: True if it's a group track, false otherwise.
    public func isGroupTrack() async throws -> Bool {
        // Some versions of AbletonOSC use `/live/track/get/is_foldable <trackIndex>`.
        // Check the documentation for your specific version if this endpoint is different.
        let response = try await connection.query("/live/track/get/is_foldable", arguments: [Int32(index)])
        guard let foldable = response.first as? Bool else {
            throw LiveError.oscError("Failed to parse is_foldable for track \(index). Response: \(response)")
        }
        return foldable
    }
    
    // MARK: - Additional Property Examples
    
    /// Example: Arm track for recording (if it's a MIDI or Audio track).
    public func setArm(_ armed: Bool) {
        // `/live/track/set/arm <trackIndex> <0/1>`
        connection.send(address: "/live/track/set/arm", arguments: [
            Int32(index),
            armed ? 1 : 0
        ])
    }
    
    // MARK: - Scan
    
    /// Retrieves clip slots or device details for this track and populates `clips` / `devices`.
    /// In PyLive, scanning might happen inside `Set(scan=True)`. We replicate that logic here
    /// or let the user call `scan()` explicitly.
    public func scan() async throws {
        // 1. Clear existing arrays.
        self.clips.removeAll()
        self.devices.removeAll()
        
        // 2. SCAN CLIPS
        // We can query the total number of scenes in the set, then for each scene check if a clip exists.
        // For now, let's just do a placeholder until we define `Clip`.
        
        // Example approach: if we know the scene count is from LiveSet, we pass it in or re-query:
        let response = try await connection.query("/live/song/get/num_scenes")
        guard let sceneCount = response.first as? Int else {
            throw LiveError.oscError("Failed to parse scene count from response: \(response)")
        }
        
        // For each scene slot, we might test if there's a clip or not. 
        // We'll define a minimal placeholder logic:
        var tempClips: [Clip?] = []
        for sceneIndex in 0..<sceneCount {
            // We'll define the actual `Clip` class in Clip.swift.
            // For now, assume a simple constructor for Clip:
            let hasClip = try await checkClipExists(at: sceneIndex)
            if hasClip {
                let newClip = Clip(trackIndex: index, sceneIndex: sceneIndex, connection: connection)
                tempClips.append(newClip)
            } else {
                tempClips.append(nil)
            }
        }
        self.clips = tempClips
        
        // 3. SCAN DEVICES
        // Similarly, once we define Device.swift, we can fill `devices`.
        // For now, we do a placeholder approach:
        // let deviceCountResponse = try await connection.query("/live/track/get/num_devices", [Int32(index))])
        // ...
        
        // 4. If track is a group track, we might do extra logic or handle child tracks, etc.
        // That can be advanced in a specialized `GroupTrack` subclass or right here as needed.
    }
    
    /// Simple helper to check if there's a clip in the given sceneIndex slot for this track.
    private func checkClipExists(at sceneIndex: Int) async throws -> Bool {
        // Attempt to get clip name: `/live/clip/get/name <trackIndex> <clipIndex>`
        // If we get a valid string, there's a clip. If we get an error or empty, no clip.
        // Another approach is to check `/live/clip/get/length`, etc.
        
        let address = "/live/clip/get/name"
      let args: [any OSCValue] = [
            Int32(index),
            Int32(sceneIndex)
        ]
        
        do {
            let response = try await connection.query(address, arguments: args)
            if response.isEmpty {
                // Possibly no clip
                return false
            } else if let clipName = response.first as? String, !clipName.isEmpty {
                return true
            }
            return false
        } catch LiveError.timeout {
            // If we timed out, assume no clip for this example
            return false
        } catch {
            // Another error might mean no clip, or we can rethrow it.
            return false
        }
    }
}
