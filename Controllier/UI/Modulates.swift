//
//  Modulates.swift
//  Controllier
//
//  Created by Jared McFarland on 4/14/25.
//


import SwiftUI
import MIDIKitCore

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}


@propertyWrapper
struct Modulates: DynamicProperty {
    @ObservedObject var state: PublishedStructRelay<ControllerState>
    let channel: UInt4
    let controller: UInt7

    var wrappedValue: Double {
        get {
            state.get()[channel, controller].unitIntervalValue
        }
        nonmutating set {
            state.modify {
                $0[channel, controller] = .unitInterval(newValue.clamped(to: 0...1))
            }
        }
    }

    var projectedValue: Binding<Double> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }

    init(_ state: PublishedStructRelay<ControllerState>, channel: UInt4, controller: UInt7) {
        self.state = state
        self.channel = channel
        self.controller = controller
    }
}
