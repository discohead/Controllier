//
//  LiveViewModel.swift
//  Controllier
//
//  Created by Jared McFarland on 3/24/25.
//

import Foundation
import SwiftUI

@MainActor
final class LiveViewModel: ObservableObject {
    @Published var tempo: Double = 0.0
    private var liveSet: LiveSet?
    private let connection = LiveConnection()
    
    private var controlSystem: ControlSystem?
    
    func setupLiveConnection() async {
        do {
            connection.enableLogging = true
            try connection.connect()
            
            liveSet = try await LiveSet(connection: connection, autoScan: true)
            tempo = try await liveSet?.getTempo() ?? 0.0
            
            // Set up a tempo observer to sync with TimelineManager
//            setupTempoObserver()
            
            // Other setup code, e.g., control transport, trigger scenes, etc.
        } catch {
            print("Error setting up LiveOSC: \(error)")
        }
    }
    
    func setControlSystem(_ contolSystem: ControlSystem) {
        self.controlSystem = contolSystem
        
        // If we already have a tempo from Live, update the TimelineManager
        if tempo > 0 {
            controlSystem?.globalState.tempo = tempo
        }
    }
    
    private func setupTempoObserver() {
        // This is a placeholder for where you'd set up tempo sync from Live
        // You would ideally register for tempo change notifications from Live
        // and then update both the local tempo property and the TimelineManager
        
        // Example (pseudo-code):
        // connection.observeTempo { [weak self] newTempo in
        //     self?.tempo = newTempo
        //     self?.timelineManager?.tempo = newTempo
        // }
    }
    
    func startPlaying() {
        liveSet?.startPlaying()
        
        // Optional: Start the timeline when starting Live
        controlSystem?.start()
    }
    
    func stopPlaying() {
        liveSet?.stopPlaying()
        
        // Optional: Stop the timeline when stopping Live
        controlSystem?.stop()
    }
}
