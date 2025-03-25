//
//  ContentView.swift
//  Controllier
//
//  Created by Jared McFarland on 3/23/25.
//

import MIDIKitIO
import MIDIKitUI
import SwiftUI

struct ContentView: View {
    @Environment(ObservableMIDIManager.self) private var midiManager
    @Environment(MIDIHelper.self) private var midiHelper
    
    @StateObject private var viewModel = LiveViewModel()
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text(
                """
                This example creates a MIDI output connection to the MIDI endpoint that iOS creates once an iOS-to-Mac USB connection has been established in Audio MIDI Setup on the Mac.
                
                Note that this example project must be run on a physical iOS device connected with a USB cable.
                
                Test events can be sent to the Mac by using the buttons below.
                
                Events received from the Mac are logged to the console in this example.
                """
            )
            .multilineTextAlignment(.center)
            
            Button("Send Note On C3") {
//                midiHelper.sendNoteOn()
                viewModel.startPlaying()
            }
            
            Button("Send Note Off C3") {
                midiHelper.sendNoteOff()
            }
            
            Button("Send CC1") {
                midiHelper.sendCC1()
            }
        }
        .font(.system(size: 18))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task {
            await viewModel.setupLiveConnection()
        }
    }
}
