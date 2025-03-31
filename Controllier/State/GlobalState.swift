//
//  GlobalState.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

import Foundation
import MIDIKitCore

public class GlobalState: ObservableObject {
    // Musical context
    // @Published var activeScale: Scale = .minorPentatonic
    @Published var rootNote: UInt7 = 60
    @Published var tempo: Double = 120
    
    // Pattern parameters
    @Published var density: Double = 0.5
    @Published var complexity: Double = 0.5
    @Published var variation: Double = 0.3
    
    // Performance state
    @Published var channels: [Channel] = []
    
    // Global control state
    @Published var controlState: ControlState
    
    // Generator seeds & history
//    @Published var patternHistory: RingBuffer<PatternData> = RingBuffer(capacity: 8)
//    @Published var currentSeed: Int = Int.random(in: 0..<Int.max)
    
    public init(rootNote: UInt7, tempo: Double, density: Double, complexity: Double, variation: Double, channels: [Channel], controlState: ControlState) {
        self.rootNote = rootNote
        self.tempo = tempo
        self.density = density
        self.complexity = complexity
        self.variation = variation
        self.channels = channels
        self.controlState = controlState
    }
}
