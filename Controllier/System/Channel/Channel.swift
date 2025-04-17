//
//  Channel.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

import Foundation

public class Channel: ObservableObject {
    private let globalState: GlobalState
    
    @Published var noteGenerator: NoteGenerator
    @Published var number: Int
    @Published var isMuted: Bool
    @Published var isSolo: Bool
    @Published var volume: Double
    @Published var pan: Double
    
    public init(globalState: GlobalState, noteGenerator: NoteGenerator, number: Int, isMuted: Bool = false, isSolo: Bool = false, volume: Double = 1.0, pan: Double = 0.0) {
        self.globalState = globalState
        self.noteGenerator = noteGenerator
        self.number = number
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.volume = volume
        self.pan = pan
    }
}
