//
//  BinaryFloatingPointUtils.swift
//  Controllier
//
//  Created by Jared McFarland on 4/14/25.
//


import Foundation
import MIDIKit

// MARK: - Clamping

extension Comparable {
    /// Clamps a value to a closed range.
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// MARK: - Linear Interpolation (Lerp)

extension BinaryFloatingPoint {
    /// Performs linear interpolation between two values.
    static func lerp(from start: Self, to end: Self, by t: Self) -> Self {
        (1 - t) * start + t * end
    }
}

// MARK: - Inverse Lerp

extension BinaryFloatingPoint {
    /// Normalizes a value from a given range to a 0.0...1.0 unit interval.
    static func inverseLerp(from start: Self, to end: Self, value: Self) -> Self {
        guard end != start else { return 0 }
        return (value - start) / (end - start)
    }
}

// MARK: - Remapping Ranges

extension BinaryFloatingPoint {
    /// Remaps a value from one range to another.
    static func remap(value: Self,
                      from fromRange: ClosedRange<Self>,
                      to toRange: ClosedRange<Self>) -> Self {
        let normalized = inverseLerp(from: fromRange.lowerBound,
                                     to: fromRange.upperBound,
                                     value: value)
        return lerp(from: toRange.lowerBound,
                    to: toRange.upperBound,
                    by: normalized).clamped(to: toRange)
    }
}

// MARK: - MIDI CC Bridging

extension BinaryFloatingPoint {
    /// Converts a normalized (0.0 ... 1.0) value to MIDI 7-bit (0 ... 127).
    var toUInt7: UInt7 {
        let clamped = self.clamped(to: 0.0 ... 1.0)
        return UInt7((clamped * 127).rounded(.toNearestOrAwayFromZero))
    }

    /// Converts a MIDI 7-bit value (0 ... 127) to a normalized (0.0 ... 1.0) value.
    static func from(uint7: UInt7) -> Self {
        Self(uint7.value) / 127
    }
}