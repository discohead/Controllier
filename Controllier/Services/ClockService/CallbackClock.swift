//
//  CallbackClock.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//


//
//  CallbackClock.swift
//  Controllier
//

import Foundation
import AudioKit
import AudioKitEX

/// A high-precision musical clock based on AudioKit's AppleSequencer
class CallbackClock {
    // Audio engine components
    private let engine = AudioEngine()
    private let sequencer = AppleSequencer()
    private let callbackInstrument = MIDICallbackInstrument()
    private var metronomeTrack: MusicTrackManager?
    
    // Clock state
    private(set) var isRunning = false
    private(set) var currentBeat: Double = 0
    private var firstTickReceived = false
    
    // Tick types (based on Vermona Random Rhythm approach)
    enum TickType {
        case quarter    // Quarter notes (main beats)
        case eighth     // Eighth notes (offbeats)
        case sixteenth  // Sixteenth notes
        case triplet    // Triplet eighth notes
        case unknown    // Unknown tick type
    }
    
    // Callback properties
    var tickCallback: ((Double, TickType) -> Void)?
    
    // Musical timing properties
    var tempo: Double {
        didSet {
            sequencer.setTempo(tempo)
        }
    }
    
    var ticksPerBeat: Int
    
    // Initialize with given tempo and resolution
    init(tempo: Double = 120.0, ticksPerBeat: Int = 24) {
        self.tempo = tempo
        self.ticksPerBeat = ticksPerBeat
        
        setupAudioEngine()
    }
    
    // Set up the audio engine and sequencer
    private func setupAudioEngine() {
        // Connect the callback instrument to the engine
        engine.output = callbackInstrument
        
        // Set up MIDI callback to drive our timeline
        callbackInstrument.callback = { [weak self] status, note, velocity in
            guard let self = self else { return }
            
            // Only process Note On messages (144)
            if status == 144 {
                self.handleTick(note: note)
            }
        }
        
        // Set up sequencer for metronome
        // sequencer.setGlobalMIDIOutput()
        sequencer.enableLooping()
        sequencer.setLoopInfo(Duration(beats: 1), loopCount: Int.max)
        sequencer.setTempo(tempo)
        
        // Create a track for our tick events
        metronomeTrack = sequencer.newTrack()
        metronomeTrack?.setMIDIOutput(callbackInstrument.midiIn)
        
        // Set up metronome events
        setupMetronomeTrack()
    }
    
    // Set up the metronome track with different subdivision types
    private func setupMetronomeTrack() {
        guard let track = metronomeTrack else { return }
        
        // Clear any existing events
        track.clear()
        
        // Define note numbers for each subdivision type
        let quarterNoteNum: MIDINoteNumber = 60 // 1/4 events
        let eighthNoteNum: MIDINoteNumber = 61  // 1/8 events
        let sixteenthNoteNum: MIDINoteNumber = 62 // 1/16 events
        let tripletNoteNum: MIDINoteNumber = 63 // 1/3 events (triplets)
        
        // Calculate total ticks in a measure (assuming 4/4 time)
        let ticksPerMeasure = ticksPerBeat * 4
        
        // Add events for a full measure
        for tick in 0..<ticksPerMeasure {
            // Convert to 16th-note position (0-15) for easier comparison with diagram
            let pos16th = (tick * 16) / ticksPerMeasure
            
            // Calculate position in beats for sequencer
            let positionInBeats = Double(tick) / Double(ticksPerBeat)
            
            // Determine which subdivision this tick represents
            // Following Vermona Random Rhythm's hierarchy
            let noteNumber: MIDINoteNumber
            var shouldEmit = false
            
            if pos16th % 4 == 0 {
                // Quarter notes on positions 0, 4, 8, 12
                noteNumber = quarterNoteNum
                shouldEmit = true
            } else if pos16th % 2 == 0 {
                // Eighth notes on positions 2, 6, 10, 14
                noteNumber = eighthNoteNum
                shouldEmit = true
            } else {
                // Sixteenth notes on all other positions
                noteNumber = sixteenthNoteNum
                shouldEmit = true
            }
            
            // Add the note event if this position should emit
            if shouldEmit {
                track.add(noteNumber: noteNumber, 
                          velocity: 100, 
                          position: Duration(beats: positionInBeats), 
                          duration: Duration(beats: 0.01))
            }
        }
        
        // Add triplet events (1/3 notes) - placed between quarter notes
        // In a 4/4 measure, we have 12 triplet eighth notes (3 per beat)
        for tripletIndex in 0..<12 {
            // Calculate the beat and position within beat
            let beatNumber = Double(tripletIndex / 3) // 0-3 as Double
            let positionInBeat = Double(tripletIndex % 3) // 0-2 as Double
            
            // Skip triplet positions that would overlap with quarter notes
            // In Vermona terms, we skip positions where triplet falls on a quarter note
            if positionInBeat == 0 {
                continue // Skip the first triplet of each beat (overlaps with quarter)
            }
            
            // Calculate position in beats for sequencer
            let positionInBeats = beatNumber + (positionInBeat * (1.0/3.0))
            
            // Add the triplet note event
            track.add(noteNumber: tripletNoteNum, 
                      velocity: 100, 
                      position: Duration(beats: positionInBeats), 
                      duration: Duration(beats: 0.01))
        }
    }
    
    // Handle a tick from the sequencer
    private func handleTick(note: MIDINoteNumber) {
        // Update current beat position
        currentBeat = sequencer.currentPosition.beats
        
        // Determine the tick type based on the note number
        let tickType: TickType
        switch note {
        case 60: tickType = .quarter
        case 61: tickType = .eighth
        case 62: tickType = .sixteenth
        case 63: tickType = .triplet
        default: tickType = .unknown
        }
        
        // Call the tick callback with current beat position and tick type
        tickCallback?(currentBeat, tickType)
    }
    
    // Start the clock
    func start() {
        do {
            // Start the audio engine
            try engine.start()
            
            // Reset current beat
            currentBeat = 0
            
            // Start the sequencer
            sequencer.rewind()
            sequencer.play()
            
            isRunning = true
            
            print("CallbackClock started at tempo: \(tempo) BPM")
        } catch {
            print("Error starting CallbackClock: \(error)")
            isRunning = false
        }
    }
    
    // Stop the clock
    func stop() {
        sequencer.stop()
        isRunning = false
    }
    
    // Clean up resources
    deinit {
        sequencer.stop()
        engine.stop()
    }
}
