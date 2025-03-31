//
//  Generator.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

public enum GeneratorType {
    case note
    case cc
    case osc
}

public protocol Generator {
    // Identity
    var id: String { get }
    var type: GeneratorType { get }
    
    // State dependency
    // var requiredStateKeys: [KeyPath<GlobalState, Any>] { get }
    
    // Generation
    func shouldGenerate(given state: GlobalState, currentBeat: Double) -> Bool
    func generate(state: GlobalState, startBeat: Double) -> [Any] // TODO: PatternData
    
    // Lifecycle
    func initialize(state: GlobalState)
    func cleanup(state: GlobalState)
}
