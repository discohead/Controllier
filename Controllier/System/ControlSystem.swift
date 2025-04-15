//
//  ControlSystem.swift
//  Controllier
//
//  Created by Jared McFarland on 3/30/25.
//

final class ControlSystem {
    let globalState: GlobalState
    let channels: [Channel]
    let midiService: MIDIServiceProtocol
//    let oscService: OSCServiceProtocol
//    let output: OutputModuleProtocol
    
    init(channels: [Channel],
         midiService: MIDIServiceProtocol
//         oscService: OSCServiceProtocol,
//         output: OutputModuleProtocol
    ) {
        
        self.globalState = GlobalState()
        self.midiService = midiService
//        self.oscService = oscService
//        self.output = output
        
        // Instantiate channels from configs
//        self.channels = channelConfigs.enumerated().map { index, config in
//            Channel(index: index, config: config, globalState: globalState)
//        }
        
        self.channels = channels
        
//        output.start(globalState: globalState,
//                     channels: channels,
//                     midiService: midiService,
//                     oscService: oscService
//        )
    }
    
//    func start() {
//        channels.forEach { $0.start() }
//    }
//    
//    func stop() {
//        channels.forEach { $0.stop() }
//    }
}
