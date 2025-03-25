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
    
    init() {
        midiHelper.setup(midiManager: midiManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(midiManager)
                .environment(midiHelper)
        }
    }
}
