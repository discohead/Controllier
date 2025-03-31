//
//  TimelineManager.swift
//  Controllier
//

import Foundation
import MIDIKit
import SwiftUI

@Observable final class TimelineManager {
    // Components
    private weak var midiHelper: MIDIHelper?
    private let clock: CallbackClock
    let timeline: Timeline
    
    // State tracking
    private(set) var isRunning = false
    
    // Musical timing properties
    var tempo: Double {
        didSet {
            clock.tempo = tempo
        }
    }
    
    var ticksPerBeat: Int
    
    // MARK: - Initialization
    
    init(midiHelper: MIDIHelper? = nil, tempo: Double = 120.0, ticksPerBeat: Int = 24) {
        self.midiHelper = midiHelper
        self.tempo = tempo
        self.ticksPerBeat = ticksPerBeat
        
        // Create the timeline
        self.timeline = Timeline(globalState: GlobalState(
            rootNote: 60,
            tempo: tempo,
            density: 0.5,
            complexity: 0.5,
            variation: 0.3,
            channels: [],
            controlState: ControlState()
        ))
        
        // Create the clock
        self.clock = CallbackClock(tempo: tempo, ticksPerBeat: ticksPerBeat)
        
        // Set up the clock callback
        setupClockCallback()
    }
    
    private func setupClockCallback() {
        clock.tickCallback = { [weak self] beatPosition, tickType in
            guard let self = self else { return }
            
            // Update the timeline with the current beat position
            self.timeline.updateBeatPosition(beatPosition)
            
            // Handle specific tick types if needed
            switch tickType {
            case .quarter:
                // Quarter note specific processing
                break
                
            case .eighth:
                // Eighth note specific processing
                break
                
            case .sixteenth:
                // Sixteenth note specific processing
                break
                
            case .triplet:
                // Triplet specific processing
                break
                
            case .unknown:
                break
            }
        }
    }
    
    func setMIDIHelper(_ midiHelper: MIDIHelper) {
        self.midiHelper = midiHelper
    }
    
    // MARK: - Timeline Control
    
    func start() {
        timeline.reset()
        clock.start()
        isRunning = true
    }
    
    func stop() {
        clock.stop()
        isRunning = false
    }
    
    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    // MARK: - MIDI Scheduling
    
    /// Schedule a MIDI note event
    /// - Parameters:
    ///   - beatPosition: Position in beats (1.0 = quarter note)
    ///   - note: MIDI note number
    ///   - velocity: MIDI velocity (0-127)
    ///   - duration: Note duration in beats (1.0 = quarter note)
    ///   - channel: MIDI channel
    ///   - probability: Chance of the note happening (0.0-1.0)
    ///   - condition: Additional condition to check
    func scheduleNote(
        at beatPosition: Double,
        note: UInt7,
        velocity: UInt7 = 127,
        duration: Double = 0.5,
        channel: UInt4 = 0,
        probability: Double = 1.0,
        condition: ConditionClosure?,
        rescheduleHandler: RescheduleHandler?
    ) {
        // Schedule the note-on event
        let noteOnAction = ScheduledAction(
            scheduledBeat: beatPosition,
            state: ["note": note, "velocity": velocity, "channel": channel],
            condition: condition,
            probability: probability,
            rescheduleHandler: rescheduleHandler
        ) { [weak self] _, action in
            guard let self = self else { return }
            
            let note = action.state["note"] as? UInt7 ?? note
            let velocity = action.state["velocity"] as? UInt7 ?? velocity
            let channel = action.state["channel"] as? UInt4 ?? channel
            
            self.midiHelper?.sendNoteOn(noteNum: note, velocity: velocity, channel: channel)
        }
        
        // Schedule the note-off event
        let noteOffAction = ScheduledAction(
            scheduledBeat: beatPosition + duration,
            state: ["note": note, "channel": channel],
            condition: { true },
            probability: 1.0  // Always release notes that were played
        ) { [weak self] _, action in
            guard let self = self else { return }
            
            let note = action.state["note"] as? UInt7 ?? note
            let channel = action.state["channel"] as? UInt4 ?? channel
            
            self.midiHelper?.sendNoteOff(noteNum: note, channel: channel)
        }
        
        // Add both actions to the timeline
        timeline.schedule(action: noteOnAction)
        timeline.schedule(action: noteOffAction)
    }
    
    /// Schedule a MIDI CC event
    /// - Parameters:
    ///   - beatPosition: Position in beats (1.0 = quarter note)
    ///   - controller: MIDI CC number
    ///   - value: CC value (0-127)
    ///   - channel: MIDI channel
    ///   - probability: Chance of the event happening (0.0-1.0)
    ///   - condition: Additional condition to check
    func scheduleCC(
        at beatPosition: Double,
        controller: UInt7,
        value: UInt7,
        channel: UInt4,
        probability: Double = 1.0,
        condition: ConditionClosure?,
        rescheduleHandler: RescheduleHandler?
    ) {
        let ccAction = ScheduledAction(
            scheduledBeat: beatPosition,
            state: ["controller": controller, "value": value, "channel": channel],
            condition: condition,
            probability: probability
        ) { [weak self] _, action in
            guard let self = self else { return }
            
            let controller = action.state["controller"] as? UInt7 ?? controller
            let value = action.state["value"] as? UInt7 ?? value
            let channel = action.state["channel"] as? UInt4 ?? channel
            
            self.midiHelper?.sendCC(ccNum: controller, value: value, channel: channel)
        }
        
        timeline.schedule(action: ccAction)
    }
    
    /// Schedule a recurring pattern of notes (useful for generative sequences)
    /// - Parameters:
    ///   - startBeat: Starting position in beats
    ///   - notes: Array of MIDI note numbers
    ///   - velocities: Optional array of velocities (defaults to 100)
    ///   - durations: Optional array of durations in beats (defaults to 0.25)
    ///   - intervals: Optional array of intervals between notes in beats (defaults to 0.5)
    ///   - channel: MIDI channel
    ///   - repeats: Number of times to repeat the pattern
    ///   - probability: Base probability for notes (0.0-1.0)
    func schedulePattern(
        startBeat: Double,
        notes: [UInt7],
        velocities: [UInt7]? = nil,
        durations: [Double]? = nil,
        intervals: [Double]? = nil,
        channel: UInt4 = 0,
        repeats: Int = 1,
        probability: Double = 1.0
    ) {
        let vels = velocities ?? Array(repeating: 100, count: notes.count)
        let durs = durations ?? Array(repeating: 0.25, count: notes.count)
        let ints = intervals ?? Array(repeating: 0.5, count: notes.count)
        
        // Ensure all arrays are the same length
        let count = min(notes.count, vels.count, durs.count, ints.count)
        
        var currentBeat = startBeat
        
        // Schedule each note in the pattern
        for _ in 0..<repeats {
            for i in 0..<count {
                // Optional: Add some variation using the GlobalState
                // let noteProb = probability * (0.8 + (Double(timeline.globalState.someParameter) * 0.2))
                
                scheduleNote(
                    at: currentBeat,
                    note: notes[i],
                    velocity: vels[i],
                    duration: durs[i],
                    channel: channel,
                    probability: 1.0,
                    condition: nil,
                    rescheduleHandler: nil
                )
                
                currentBeat += ints[i]
            }
        }
    }
    
    /// Schedule a generative pattern that evolves over time
    /// - Parameters:
    ///   - startBeat: Starting position in beats
    ///   - patternLength: Number of notes in the pattern
    func scheduleGenerativePattern(startBeat: Double, patternLength: Int = 8) {
        let rootNote: UInt8 = 60 // C4
        let scale: [UInt8] = [0, 2, 3, 5, 7, 9, 10, 12] // C minor scale intervals
        
        // Create a scheduled action using musical time (beats)
        let generatePattern = ScheduledAction(
            scheduledBeat: startBeat,
            state: ["iteration": 0],
            condition: nil,
            probability: 1.0
        ) { [weak self] state, action in
            guard let self = self else { return }
            
            // Generate a new pattern based on current state
            let iteration = (action.state["iteration"] as? Int ?? 0) + 1
            action.state["iteration"] = iteration
            
            // Generate notes using the scale
            var notes: [UInt7] = []
            var velocities: [UInt7] = []
            var durations: [Double] = []
            var intervals: [Double] = []
            
            for _ in 0..<patternLength {
                // Pick a scale degree based on some algorithm
                // Here's a simple one that changes with iteration
                let scaleDegree = Int.random(in: 0..<scale.count)
                let note = rootNote + scale[scaleDegree]
                notes.append(UInt7(note))
                
                // Generate some variation in velocity
                velocities.append(UInt7(UInt8.random(in: 70...110)))
                
                // Generate some variation in duration and timing (in beats)
                durations.append(Double.random(in: 0.1...0.4))
                intervals.append(Double.random(in: 0.2...0.5))
            }
            
            // Schedule the new pattern at the current beat position
            self.schedulePattern(
                startBeat: action.scheduledBeat,
                notes: notes,
                velocities: velocities,
                durations: durations,
                intervals: intervals
            )
        }
        
        // Set up the reschedule handler to continue generating patterns
        generatePattern.rescheduleHandler = { (globalState: GlobalState, action: ScheduledAction) -> ScheduledAction? in
            // Create a new action with updated beat position (4 beats later)
            let newAction = ScheduledAction(
                scheduledBeat: action.scheduledBeat + 4.0,
                state: action.state,
                condition: action.condition,
                probability: action.probability,
                closure: action.closure
            )
            newAction.rescheduleHandler = action.rescheduleHandler
            return newAction
        }
        
        // Schedule the initial generative action
        timeline.schedule(action: generatePattern)
    }
    
    // MARK: - Rhythm-Based Event Scheduling
    
    /// Subdivision types following the Vermona Random Rhythm concept
    enum Subdivision {
        case quarter    // 1/4 notes (beats 1, 5, 9, 13 in 16th terms)
        case eighth     // 1/8 notes (beats 3, 7, 11, 15 in 16th terms)
        case sixteenth  // 1/16 notes (all other 16th positions)
        case triplet    // 1/3 notes (triplet eighth notes)
        case all        // All subdivisions
    }
    
    /// Schedule a note to play on specific subdivisions
    /// - Parameters:
    ///   - note: MIDI note number
    ///   - velocity: MIDI velocity (0-127)
    ///   - duration: Note duration in beats
    ///   - channel: MIDI channel
    ///   - subdivision: Which subdivision type to trigger on
    ///   - measures: How many measures to schedule
    ///   - startMeasure: Measure to start scheduling (0 = current measure)
    ///   - probability: Chance of each note happening (0.0-1.0)
    func scheduleOnSubdivision(
        note: UInt7,
        velocity: UInt7 = 100,
        duration: Double = 0.25,
        channel: UInt4 = 0,
        subdivision: Subdivision = .quarter,
        measures: Int = 1,
        startMeasure: Int = 0,
        probability: Double = 1.0
    ) {
        // Calculate beats per measure (assuming 4/4 time)
        let beatsPerMeasure = 4.0
        
        // Calculate start position (beginning of the specified measure)
        let startPosition = Double(startMeasure) * beatsPerMeasure
        
        // For the given number of measures
        for measure in 0..<measures {
            let measurePosition = startPosition + (Double(measure) * beatsPerMeasure)
            
            // Schedule based on subdivision type
            switch subdivision {
            case .quarter:
                // Quarter notes (4 per measure in 4/4 time)
                for i in 0..<4 {
                    let position = measurePosition + Double(i)
                    if Double.random(in: 0...1) <= probability {
                        scheduleNote(
                            at: position,
                            note: note,
                            velocity: velocity,
                            duration: duration,
                            channel: channel,
                            probability: probability,
                            condition: nil,
                            rescheduleHandler: nil
                        )
                    }
                }
                
            case .eighth:
                // Eighth notes that aren't quarter notes (4 per measure in 4/4 time)
                // These occur halfway between quarter notes
                for i in 0..<4 {
                    let position = measurePosition + Double(i) + 0.5
                    if Double.random(in: 0...1) <= probability {
                        scheduleNote(
                            at: position,
                            note: note,
                            velocity: velocity,
                            duration: duration,
                            channel: channel,
                            probability: probability,
                            condition: nil,
                            rescheduleHandler: nil
                        )
                    }
                }
                
            case .sixteenth:
                // Sixteenth notes that aren't quarter or eighth notes (8 per measure)
                for i in 0..<16 {
                    // Skip positions that are quarter or eighth notes
                    if i % 4 == 0 || i % 2 == 0 {
                        continue
                    }
                    let position = measurePosition + (Double(i) * 0.25)
                    if Double.random(in: 0...1) <= probability {
                        scheduleNote(
                            at: position,
                            note: note,
                            velocity: velocity,
                            duration: duration,
                            channel: channel,
                            probability: probability,
                            condition: nil,
                            rescheduleHandler: nil
                        )
                    }
                }
                
            case .triplet:
                // Triplet eighth notes (excluding those that fall on quarter notes)
                // 3 triplets per beat, but we skip the ones at beat positions
                for beat in 0..<4 { // 4 beats per measure
                    for triplet in 1..<3 { // Skip triplet at position 0 (coincides with quarter)
                        let position = measurePosition + Double(beat) + (Double(triplet) * (1.0/3.0))
                        if Double.random(in: 0...1) <= probability {
                            scheduleNote(
                                at: position,
                                note: note,
                                velocity: velocity,
                                duration: duration,
                                channel: channel,
                                probability: probability,
                                condition: nil,
                                rescheduleHandler: nil
                            )
                        }
                    }
                }
                
            case .all:
                // Schedule on all subdivision types
                // Quarter notes
                for i in 0..<4 {
                    let position = measurePosition + Double(i)
                    if Double.random(in: 0...1) <= probability {
                        scheduleNote(
                            at: position,
                            note: note,
                            velocity: velocity,
                            duration: duration,
                            channel: channel,
                            probability: probability,
                            condition: nil,
                            rescheduleHandler: nil
                        )
                    }
                }
                
                // Eighth notes (non-quarter positions)
                for i in 0..<4 {
                    let position = measurePosition + Double(i) + 0.5
                    if Double.random(in: 0...1) <= probability {
                        scheduleNote(
                            at: position,
                            note: note,
                            velocity: velocity,
                            duration: duration,
                            channel: channel,
                            probability: probability,
                            condition: nil,
                            rescheduleHandler: nil
                        )
                    }
                }
                
                // Sixteenth notes (non-quarter, non-eighth positions)
                for i in 0..<16 {
                    if i % 4 == 0 || i % 2 == 0 {
                        continue
                    }
                    let position = measurePosition + (Double(i) * 0.25)
                    if Double.random(in: 0...1) <= probability {
                        scheduleNote(
                            at: position,
                            note: note,
                            velocity: velocity,
                            duration: duration,
                            channel: channel,
                            probability: probability,
                            condition: nil,
                            rescheduleHandler: nil
                        )
                    }
                }
                
                // Triplets (excluding those at quarter note positions)
                for beat in 0..<4 {
                    for triplet in 1..<3 {
                        let position = measurePosition + Double(beat) + (Double(triplet) * (1.0/3.0))
                        if Double.random(in: 0...1) <= probability {
                            scheduleNote(
                                at: position,
                                note: note,
                                velocity: velocity,
                                duration: duration,
                                channel: channel,
                                probability: probability,
                                condition: nil,
                                rescheduleHandler: nil
                            )
                        }
                    }
                }
            }
        }
    }
    
    /// Create a drum pattern using the Vermona Random Rhythm concept
    /// - Parameters:
    ///   - kick: MIDI note for kick drum
    ///   - snare: MIDI note for snare drum
    ///   - hihat: MIDI note for hihat
    ///   - measures: Number of measures to schedule
    ///   - startMeasure: Measure to start scheduling (0 = current measure)
    ///   - variations: Enable pattern variations
    func createDrumPattern(
        kick: UInt7 = 36,
        snare: UInt7 = 38,
        hihat: UInt7 = 42,
        measures: Int = 2,
        startMeasure: Int = 0,
        variations: Bool = false
    ) {
        // Basic kick pattern - on quarter notes (1 and 3)
        scheduleOnSubdivision(
            note: kick,
            velocity: 100,
            duration: 0.2,
            subdivision: .quarter,
            measures: measures,
            startMeasure: startMeasure,
            probability: variations ? 0.9 : 1.0
        )
        
        // Basic snare pattern - on quarter notes (2 and 4)
        scheduleOnSubdivision(
            note: snare,
            velocity: 90,
            duration: 0.15,
            subdivision: .quarter,
            measures: measures,
            startMeasure: startMeasure,
            probability: variations ? 0.95 : 1.0
        )
        
        // HiHat pattern - primary on eighth notes
        scheduleOnSubdivision(
            note: hihat,
            velocity: 80,
            duration: 0.05,
            subdivision: .eighth,
            measures: measures,
            startMeasure: startMeasure,
            probability: 1.0
        )
        
        // Additional hihat pattern - some on sixteenth notes
        if variations {
            scheduleOnSubdivision(
                note: hihat,
                velocity: 60,
                duration: 0.05,
                subdivision: .sixteenth,
                measures: measures,
                startMeasure: startMeasure,
                probability: 0.4
            )
            
            // Occasional triplet flourishes
            scheduleOnSubdivision(
                note: hihat,
                velocity: 70,
                duration: 0.05,
                subdivision: .triplet,
                measures: measures,
                startMeasure: startMeasure,
                probability: 0.3
            )
        }
    }
}
