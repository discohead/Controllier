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
    
    @State var midiManager = ObservableMIDIManager(
        clientName: "ControllierMIDIManager",
        model: "Controllier",
        manufacturer: "JaredMcFarland"
    )
    
    @State var midiHelper = MIDIHelper()
    
    // Add the TimelineManager
    @State var timelineManager = TimelineManager()
    
    init() {
        // Setup MIDI
        midiHelper.setup(midiManager: midiManager)
        
        // Connect timeline to MIDI helper
        timelineManager.setMIDIHelper(midiHelper)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(midiManager)
                .environment(midiHelper)
                .environment(timelineManager) // Make the timeline available to views
        }
    }
}
