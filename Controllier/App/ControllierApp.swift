//
//  ControllierApp.swift
//  Controllier
//
//  Created by Jared McFarland on 3/23/25.
//

import SwiftUI
import MIDIKitIO

@main
struct ControllierApp: App {
    
    @State var globalState = GlobalState()
    
    @State var midiService = MIDIService()
    
    // Add the TimelineManager
    @State var timelineManager = TimelineManager()
    
    
    init() {
        midiService.setGlobalState(globalState)
        
        // Connect timeline to MIDI helper
        timelineManager.setMIDIService(midiService)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(midiService)
                .environment(timelineManager) // Make the timeline available to views
        }
    }
}
