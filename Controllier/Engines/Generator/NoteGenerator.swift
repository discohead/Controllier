//
//  NoteGenerator.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

import Foundation

public class NoteGenerator: ObservableObject {
    @Published var numBeats = 4.0
    
    @Published var stepLength = 1.0/16.0
    
    @Published var trigThreshold = 0.5
    
    @Published var rotation = 0.0
    
    @Published var op: Crvs.FloatOp?
    
    private let crvs: Crvs.Ops
    
    public func generate(state: GlobalState, phase: Double, startBeat: Double) -> [Any] {
        print("Generating notes...")
        var notes: [Any] = []
        let endBeat = startBeat + numBeats
        for beat in stride(from: startBeat, through: endBeat, by: stepLength) {
            print("Generating note at beat \(beat)")
            if let op {
                let trig = crvs.pulse(op, Float(trigThreshold))
                if trig(Float(phase)) > 0 {
                    print("Triggering note generation")
                }
            }
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
        self.crvs = Crvs.Ops()
    }
    
}
    

