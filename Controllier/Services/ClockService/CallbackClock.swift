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
        
        // Create a track for our tick events
        metronomeTrack = sequencer.newTrack()
        metronomeTrack?.setMIDIOutput(callbackInstrument.midiIn)
        
        // Set up metronome events
        setupMetronomeTrack()
        
        // Set up sequencer for metronome
        // sequencer.setGlobalMIDIOutput()
        sequencer.enableLooping(Duration(beats: 4))
        sequencer.setTempo(tempo)
    }
    
    // Set up the metronome track with different subdivision types
    private func setupMetronomeTrack() {
        guard let track = metronomeTrack else { return }
        
        track.clear()
        
        // Note numbers for each tick type
        let quarterNoteNum: MIDINoteNumber = 60
        let eighthNoteNum: MIDINoteNumber = 61
        let sixteenthNoteNum: MIDINoteNumber = 62
        let tripletNoteNum: MIDINoteNumber = 63
        
        // Explicit positions for each subdivision in a 4/4 measure:
        let quarterNotePositions: [Double] = [0.0, 1.0, 2.0, 3.0]
        let eighthNotePositions: [Double] = [0.5, 1.5, 2.5, 3.5]
        let sixteenthNotePositions: [Double] = [0.25, 0.75, 1.25, 1.75, 2.25, 2.75, 3.25, 3.75]
        let tripletNotePositions: [Double] = [
            1.0/3.0, 2.0/3.0,
            1.0 + 1.0/3.0, 1.0 + 2.0/3.0,
            2.0 + 1.0/3.0, 2.0 + 2.0/3.0,
            3.0 + 1.0/3.0, 3.0 + 2.0/3.0
        ]
        
        // Helper to add notes
        func addNotes(at positions: [Double], noteNumber: MIDINoteNumber) {
            for position in positions {
                track.add(noteNumber: noteNumber,
                          velocity: 100,
                          position: Duration(beats: position),
                          duration: Duration(beats: 0.01))
            }
        }
        
        // Add the notes explicitly
        addNotes(at: quarterNotePositions, noteNumber: quarterNoteNum)
        addNotes(at: eighthNotePositions, noteNumber: eighthNoteNum)
        addNotes(at: sixteenthNotePositions, noteNumber: sixteenthNoteNum)
        addNotes(at: tripletNotePositions, noteNumber: tripletNoteNum)
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
            sequencer.preroll()
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
