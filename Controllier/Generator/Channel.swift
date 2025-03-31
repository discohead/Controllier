//
//  Channel.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

import Foundation

public class Channel: ObservableObject {
    @Published var number: Int
    @Published var isMuted: Bool
    @Published var isSolo: Bool
    @Published var volume: Double
    @Published var pan: Double
    // @Published var noteGenerator: NoteGenerator
    // @Published var controlGenerators: [ControlGenerator]?
    
    public init(number: Int, isMuted: Bool, isSolo: Bool, volume: Double, pan: Double, patternGenerator: NoteGenerator, controlGenerators: [ControlGenerator]? = nil) {
        self.number = number
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.volume = volume
        self.pan = pan
        // self.noteGenerator = noteGenerator
        // self.controlGenerators = controlGenerators
    }
}
