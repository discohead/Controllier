//
//  Clip.swift
//  
//  Created by Jared on 3/23/25
//
//  Represents a session clip in Ableton Live, analogous to PyLive's Clip class.
//  Manages properties such as name, length, and playing status, and supports
//  adding/removing notes.
//
//  NOTE: The '/live/clip/remove/notes' command either:
//   - Takes 0 arguments to remove ALL notes in the clip, or
//   - Takes 4 arguments [start_pitch, pitch_span, start_time, time_span] to remove
//     notes in that pitch/time range (as of the 2023-11 update).
//

import Foundation
import OSCKit

public final class Clip {
    
    // MARK: - Public Properties
    
    /// The track index to which this clip belongs.
    public let trackIndex: Int
    
    /// The scene index for this clip (i.e. which slot in the track).
    public let sceneIndex: Int
    
    /// Reference to the LiveConnection for querying/updating this clip.
    public let connection: LiveConnection
    
    // MARK: - Initialization
    
    public init(trackIndex: Int, sceneIndex: Int, connection: LiveConnection) {
        self.trackIndex = trackIndex
        self.sceneIndex = sceneIndex
        self.connection = connection
    }
    
    // MARK: - Basic Info
    
    public func getName() async throws -> String {
        let address = "/live/clip/get/name"
        let response = try await connection.query(
            address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex)
            ]
        )
        guard let clipName = response.first as? String else {
            throw LiveError.oscError("Could not parse clip name from response: \(response)")
        }
        return clipName
    }
    
    public func setName(_ newName: String) {
        let address = "/live/clip/set/name"
        connection.send(
            address: address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex),
                String(newName)
            ]
        )
    }
    
    public func getLength() async throws -> Double {
        let address = "/live/clip/get/length"
        let response = try await connection.query(
            address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex)
            ]
        )
        guard let length = response.first as? Double else {
            throw LiveError.oscError("Could not parse clip length from response: \(response)")
        }
        return length
    }
    
    public func setLength(_ beats: Double) {
        let address = "/live/clip/set/length"
        connection.send(
            address: address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex),
                Float32(Float(beats))
            ]
        )
    }
    
    // MARK: - Launching & Stopping
    
    public func play() {
        let address = "/live/clip/fire"
        connection.send(
            address: address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex)
            ]
        )
    }
    
    public func stop() {
        let address = "/live/clip/stop"
        connection.send(
            address: address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex)
            ]
        )
    }
    
    // MARK: - Status
    
    public func getStatus() async throws -> ClipStatus {
        // If your AbletonOSC fork has a direct "/live/clip/get/state" returning 0..3,
        // you can query that directly. Otherwise, we combine is_playing/is_triggered:
        let playingAddress = "/live/clip/get/is_playing"
        let triggeredAddress = "/live/clip/get/is_triggered"
        
        async let playingResp = connection.query(
            playingAddress,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex)
            ]
        )
        async let triggeredResp = connection.query(
            triggeredAddress,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex)
            ]
        )
        
        let (playRes, trigRes) = try await (playingResp, triggeredResp)
        
        let isPlaying = playRes.first as? Bool ?? false
        let isTriggered = trigRes.first as? Bool ?? false
        
        if isPlaying {
            return .playing
        } else if isTriggered {
            return .triggered
        } else {
            // If there's a valid clip, it's presumably "stopped."
            // For "empty," we typically wouldn't create a Clip object at all.
            return .stopped
        }
    }
    
    // MARK: - MIDI Note Editing
    
    /// Add a MIDI note event to this clip.
    ///
    /// - Parameters:
    ///   - pitch: The MIDI pitch of the note, where 60 = C3.
    ///   - startTime: The floating-point start time within this clip, in beats.
    ///   - duration: The floating-point duration of the note, in beats.
    ///   - velocity: The MIDI velocity of the note, from 0..127.
    ///   - mute: If true, the note is muted in Live.
    ///
    /// **Note**: Requires your AbletonOSC script to support `/live/clip/add/notes`.
    public func addNote(
        pitch: Int,
        startTime: Float,
        duration: Float,
        velocity: Int,
        mute: Bool
    ) {
        let address = "/live/clip/add/notes"
        connection.send(
            address: address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex),
                Int32(pitch),
                Float32(startTime),
                Float32(duration),
                Int32(velocity),
                Int32(mute ? 1 : 0)
            ]
        )
    }
    
    /**
     Removes notes from this clip, either *all notes* (if no arguments specified)
     or a specified pitch/time range (if all four arguments are provided).
     
     The message `/live/clip/remove/notes` expects either:
     - **0 arguments**: remove all notes, or
     - **4 arguments**: `[pitch_start, pitch_span, time_start, time_span]`.
     
     **Note**: As of 2023-11, the ordering is `[pitchStart, pitchSpan, timeStart, timeSpan]`.
     
     - Parameters:
       - pitchStart: lowest MIDI pitch in the range (optional).
       - pitchSpan: number of pitches to cover from `pitchStart` (optional).
       - timeStart: the starting time in beats (optional).
       - timeSpan: how many beats from `timeStart` to cover (optional).
     
     **Example**: Removing all notes
     ```swift
     clip.removeNotes()
     ```
     **Example**: Removing notes with pitch in [40..60) and time in [4.0..8.0)
     ```swift
     clip.removeNotes(pitchStart: 40, pitchSpan: 20, timeStart: 4.0, timeSpan: 4.0)
     ```
    */
    public func removeNotes(
        pitchStart: Int? = nil,
        pitchSpan: Int? = nil,
        timeStart: Float? = nil,
        timeSpan: Float? = nil
    ) {
        let address = "/live/clip/remove/notes"
        
        // If no parameters are passed, remove *all* notes in this clip.
        if pitchStart == nil,
           pitchSpan == nil,
           timeStart == nil,
           timeSpan == nil
        {
            connection.send(
                address: address,
                arguments: [
                    Int32(trackIndex),
                    Int32(sceneIndex)
                    // no pitch/time arguments => remove all
                ]
            )
            return
        }
        
        // Otherwise, all four must be provided to specify a range.
        guard let ps = pitchStart,
              let pspan = pitchSpan,
              let ts = timeStart,
              let tspan = timeSpan else {
            // This is consistent with the Python script raising an error for partial arguments.
            if connection.enableLogging {
                print("Invalid number of arguments for /live/clip/remove/notes: either 0 or 4 must be provided.")
            }
            return
        }
        
        connection.send(
            address: address,
            arguments: [
                Int32(trackIndex),
                Int32(sceneIndex),
                Int32(ps),
                Int32(pspan),
                Float32(ts),
                Float32(tspan)
            ]
        )
    }
}
