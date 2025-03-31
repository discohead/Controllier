//
//  ControlSystem.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

import Foundation

public class ControlSystem {
    public static let shared = ControlSystem(
        globalState: GlobalState(
            rootNote: 60,
            tempo: 120,
            density: 0.5,
            complexity: 0.5,
            variation: 0.3,
            channels: [],
            controlState: ControlState()
        ),
        timelineManager: TimelineManager()
    )
    
    @Published var globalState: GlobalState
    
    @Published var timelineManager: TimelineManager
    
    
    private init(globalState: GlobalState, timelineManager: TimelineManager) {
        self.globalState = globalState
        self.timelineManager = timelineManager
    }
}


