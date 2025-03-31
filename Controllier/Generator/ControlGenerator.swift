//
//  ControlGenerator.swift
//  Controllier
//
//  Created by Jared McFarland on 3/31/25.
//

import Foundation

public class ControlGenerator: Generator {
    public func generate(state: GlobalState, startBeat: Double) -> [Any] {
        print("Generating controls...")
        return []
    }
    
    public var id: String = ""
    
    public var type: GeneratorType = .cc
    
    // public var requiredStateKeys: [KeyPath<GlobalState, Any>]
    
    public func shouldGenerate(given state: GlobalState, currentBeat: Double) -> Bool {
        return true
    }
    
    public func initialize(state: GlobalState) {
        
    }
    
    public func cleanup(state: GlobalState) {
        
    }
    
    public init() {}
}
    

