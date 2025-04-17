//
//  ContentView.swift
//  Controllier
//
//  Created by Jared McFarland on 3/23/25.
//

import MIDIKitIO
import MIDIKitUI
import SwiftUI

struct ContentView: View {
    @Environment(ControlSystem.self) private var controlSystem
    
    @StateObject private var viewModel = LiveViewModel()
    
    @State private var tempoValue: Double = 120.0
    @State private var selectedPatternType = 0
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            // Description section
            Text("Controllier: Middleware for Generative MIDI Composition")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Timeline controls section
            GroupBox("Timeline Controls") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Tempo:")
                        Slider(value: $tempoValue, in: 60...180, step: 1)
                            .onChange(of: tempoValue) { _, newValue in
                                controlSystem.globalState.tempo = newValue
                            }
                        Text("\(Int(tempoValue)) BPM")
                            .frame(width: 80, alignment: .trailing)
                    }
                    
                    HStack {
                        Button(controlSystem.isRunning ? "Stop Timeline" : "Start Timeline") {
                            controlSystem.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        Button("Reset") {
                            controlSystem.stop()
                            // Add additional reset logic if needed
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            
            // Pattern generation section
            GroupBox("Pattern Generator") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Pattern Type", selection: $selectedPatternType) {
                        Text("Arpeggios").tag(0)
                        Text("Chords").tag(1)
                        Text("Evolving").tag(2)
                        Text("Random").tag(3)
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Button("Generate Pattern") {
                            generatePattern()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        Button("Clear Patterns") {
                            // This would ideally clear scheduled patterns
                            // For now, stopping and starting would clear everything
                            if controlSystem.isRunning {
                                controlSystem.stop()
                                controlSystem.start()
                            }
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            
            // Manual MIDI tests section
            GroupBox("Manual MIDI Tests") {
                HStack(spacing: 20) {
                    Button("Send Note On C3") {
                        let noteOnEvent = MIDIEvent.noteOn(60, velocity: .midi1(100), channel: 0)
                        try? controlSystem.midiService.send(noteOnEvent)
                    }
                    
                    Button("Send Note Off C3") {
                        let noteOffEvent = MIDIEvent.noteOff(60, velocity: .midi1(0), channel: 0)
                        try? controlSystem.midiService.send(noteOffEvent)
                    }
                    
                    Button("Send CC1") {
                        let ccEvent = MIDIEvent.cc(1, value: .midi1(64), channel: 0)
                        try? controlSystem.midiService.send(ccEvent)
                    }
                }
                .padding(.vertical, 5)
            }
            
            // Ableton Live integration section
            GroupBox("Ableton Live Integration") {
                HStack {
                    Button("Start Playing") {
                        viewModel.startPlaying()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Text("Tempo: \(Int(viewModel.tempo)) BPM")
                        .foregroundColor(viewModel.tempo > 0 ? .primary : .secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .font(.system(size: 14))
        .padding()
        .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity, minHeight: 400, idealHeight: 500, maxHeight: .infinity, alignment: .center)
        .task {
            // Initialize the LiveViewModel connection
            await viewModel.setupLiveConnection()
            
            // Initialize the timeline tempo to match the UI
            controlSystem.globalState.tempo = tempoValue
        }
    }
    
    // Generate different patterns based on selection
    private func generatePattern() {
        if !controlSystem.isRunning {
            // Start the timeline if it's not running
            controlSystem.start()
        }
        
        // Current beat position plus a small offset (half a beat)
        let startBeat = controlSystem.timeline.currentBeat + 0.5
        
        switch selectedPatternType {
        case 0: // Arpeggios
            generateArpeggioPattern(startBeat: startBeat)
        case 1: // Chords
            generateChordPattern(startBeat: startBeat)
        case 2: // Evolving
            controlSystem.scheduleGenerativePattern(startBeat: startBeat)
        case 3: // Random
            generateRandomPattern(startBeat: startBeat)
        default:
            break
        }
    }
    
    // Example: Generate an arpeggio pattern
    private func generateArpeggioPattern(startBeat: Double) {
        let rootNote: UInt7 = 60 // C4
        let notes: [UInt7] = [rootNote, rootNote + 3, rootNote + 7, rootNote + 12]
        let velocities: [UInt7] = [100, 90, 80, 110]
        let durations: [Double] = [0.2, 0.2, 0.2, 0.3] // 0.2 beats = 1/5 of a quarter note
        let intervals: [Double] = [0.25, 0.25, 0.25, 0.25] // 0.25 beats = sixteenth note
        
        controlSystem.schedulePattern(
            startBeat: startBeat,
            notes: notes,
            velocities: velocities,
            durations: durations,
            intervals: intervals,
            repeats: 4,
            probability: 0.9
        )
    }
    
    // Example: Generate a chord pattern
    private func generateChordPattern(startBeat: Double) {
        // Define a progression: C, Am, F, G
        let chords: [[UInt7]] = [
            [60, 64, 67], // C major
            [57, 60, 64], // A minor
            [53, 57, 60, 65], // F major
            [55, 59, 62, 67]  // G major
        ]
        
        // Schedule each chord one after another
        var beatPosition = startBeat
        for chord in chords {
            for note in chord {
                controlSystem.scheduleNote(
                    at: beatPosition,
                    note: note,
                    velocity: 100,
                    duration: 1.8, // Hold chord for almost 2 beats
                    probability: 0.95,
                    condition: nil,
                    rescheduleHandler: nil
                )
            }
            beatPosition += 2.0 // Move to next chord every 2 beats
        }
    }
    
    // Example: Generate random notes
    private func generateRandomPattern(startBeat: Double) {
        // Define a pentatonic scale for random notes
        let scale: [UInt7] = [60, 62, 64, 67, 69, 72, 74, 79]
        
        var beatPosition = startBeat
        for _ in 0..<16 {
            // Pick a random note from the scale
            let note = scale.randomElement() ?? 60
            
            // Random velocity between 70 and 110
            let velocity = UInt7(UInt8.random(in: 70...110))
            
            // Random duration between 0.1 and 0.4 beats
            let duration = Double.random(in: 0.1...0.4)
            
            // Random interval between notes (0.2 to 0.5 beats)
            let interval = Double.random(in: 0.2...0.5)
            
            // Schedule the note
            controlSystem.scheduleNote(
                at: beatPosition,
                note: note,
                velocity: velocity,
                duration: duration,
                probability: 0.8,
                condition: nil,
                rescheduleHandler: nil
            )
            
            // Move to the next note beat position
            beatPosition += interval
        }
    }
}
