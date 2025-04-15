//
//  PublishedStructRelay.swift
//  Controllier
//
//  Created by Jared McFarland on 4/14/25.
//

import Foundation
import Combine

import MIDIKitCore

// MARK: - Extensions

extension Publisher where Output: Equatable {
    /// Emits the most recent value only once per interval, skipping intermediate duplicates.
    func coalesce(
        for interval: TimeInterval,
        scheduler: DispatchQueue = .main
    ) -> AnyPublisher<Output, Failure> {
        self
            .removeDuplicates()
            .throttle(for: .seconds(interval), scheduler: scheduler, latest: true)
            .eraseToAnyPublisher()
    }
}

/// A convenience extension for `PublishedStructRelay` that allows observing
/// specific MIDI controller values.

extension PublishedStructRelay<ControllerState> {
    func observe(
        channel: UInt4,
        controller: UInt7
    ) -> AnyPublisher<MIDIEvent.CC.Value, Never> {
        publisher
            .map { $0[channel, controller] }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// MARK: - PublishedStructRelay

/// A helper that wraps a value-type `@Published` property and provides safe,
/// diff-aware mutation.
final class PublishedStructRelay<Value: Equatable>: ObservableObject {
    @Published private(set) var value: Value
    
    init(_ initial: Value) {
        self.value = initial
    }
    
    func get() -> Value {
        value
    }
    
    func set(_ newValue: Value) {
        if newValue != value {
            if Thread.isMainThread {
                value = newValue
            } else {
#if DEBUG
                assert(true, "PublishedStructRelay.set() called off main thread!")
#endif
                DispatchQueue.main.async {
                    self.value = newValue
                }
            }
        }
    }
   
    @discardableResult
    func modify(_ transform: (inout Value) -> Void) -> Self {
        var copy = value
        transform(&copy)
        set(copy)
        return self
    }
    
    var publisher: AnyPublisher<Value, Never> {
        $value.eraseToAnyPublisher()
    }
}
