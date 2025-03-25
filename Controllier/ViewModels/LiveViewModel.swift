//
//  LiveViewModel.swift
//  Controllier
//
//  Created by Jared McFarland on 3/24/25.
//


import Foundation

@MainActor
final class LiveViewModel: ObservableObject {
    @Published var tempo: Double = 0.0
    private var liveSet: LiveSet?
    private let connection = LiveConnection()

    func setupLiveConnection() async {
        do {
            connection.enableLogging = true
            try connection.connect()
            
            liveSet = try await LiveSet(connection: connection, autoScan: true)
            tempo = try await liveSet?.getTempo() ?? 0.0
            
            // Other setup code, e.g., control transport, trigger scenes, etc.
        } catch {
            print("Error setting up LiveOSC: \(error)")
        }
    }
    
    func startPlaying() {
        liveSet?.startPlaying()
    }
}
