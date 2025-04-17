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
    
    @State var controlSystem = ControlSystem()
    
    init() {}
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(controlSystem)
        }
    }
}
