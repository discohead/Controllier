//
//  NoteGenerator.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

import Foundation

public class NoteGenerator: Generator {
    var numBeats = 16.0
    
    var beatDivision = 0.25
    
    var op: Crvs.FloatOp?
    
    public func generate(state: GlobalState, startBeat: Double) -> [Any] {
        print("Generating notes...")
        let endBeat = startBeat + numBeats
        for beat in stride(from: startBeat, to: endBeat, by: beatDivision) {
            print("Generating note at beat \(beat)")
        }
        
        return []
    }
    
    public var id: String = ""
    
    public var type: GeneratorType = .note
    
    // public var requiredStateKeys: [KeyPath<GlobalState, Any>]
    
    public func shouldGenerate(given state: GlobalState, currentBeat: Double) -> Bool {
        return true
    }
    
    public func initialize(state: GlobalState) {
        
    }
    
    public func cleanup(state: GlobalState) {
        
    }
    
    public init(op: @escaping Crvs.FloatOp) {
        self.op = op
    }
    
}
    

