//
//  ControllerState.swift
//  Controllier
//
//  Created by Jared McFarland on 4/14/25.
//

import MIDIKit


public struct ControllerState: Equatable {
    private var state: [UInt4: [UInt7: MIDIEvent.CC.Value]] = {
        var dict: [UInt4: [UInt7: MIDIEvent.CC.Value]] = [:]
        for chInt in 0...15 {
            if let ch = UInt4(exactly: chInt) {
                dict[ch] = [:]
            }
        }
        return dict
    }()
    
    public subscript(channel: UInt4, controller: UInt7) -> MIDIEvent.CC.Value {
        get {
            state[channel]?[controller] ?? .midi1(0)
        }
        set {
            state[channel]?[controller] = newValue
        }
    }
    
    public func controllerValue(_ controller: UInt7, on channel: UInt4) -> MIDIEvent.CC.Value {
        self[channel, controller]
    }
    
    public func allControllers(for channel: UInt4) -> [UInt7: MIDIEvent.CC.Value] {
        state[channel] ?? [:]
    }
    
    /// Updates the value if different. Returns true if updated.
    @discardableResult
    public mutating func updateIfChanged(cc: MIDIEvent.CC) -> Bool {
        let current = self[cc.channel, cc.controller.number]
        if current != cc.value {
            self[cc.channel, cc.controller.number] = cc.value
            return true
        } else {
            return false
        }
    }
}
