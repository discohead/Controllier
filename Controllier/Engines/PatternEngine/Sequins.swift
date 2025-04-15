//
//  Sequins.swift
//
//  A generic, fully templated version of the Sequins library using an enum wrapper
//  to preserve nested Sequins functionality.
//  This version is designed to be type safe and convenient for clients.
//
//  Created by Jared McFarland on [Date].
//

import Foundation

// MARK: - Array Safe Access Extension

extension Array {
    /// Returns the element at the given index if it exists; otherwise, returns nil.
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


// MARK: - SequinsDirection Enum

/// Represents the direction or stepping behavior of a Sequins instance.
public enum SequinsDirection {
    case forward   // Advances normally.
    case backward  // Returns the previous element.
    case drunk     // Advances with a random sign (like a drunkard's walk).
    case random    // Picks a random element from the data array.
}

// MARK: - Step Result Enum

/// Represents the possible outcomes of a sequencing step.
public enum SequinsStepResult<T> {
    case v(T) // A valid stepped value.
    case skip     // Indicates that this step should be skipped.
    case dead     // Indicates that the sequence has terminated.
}

// MARK: - Sequins Element Enum

/// Wraps an element to allow storage of either a plain value of type T
/// or a nested Sequins sequence.
public enum SequinsElement<T> {
    case v(T)
    case s(Sequins<T>)
}

// MARK: - Flow State

/// A helper class to store the state for flow modifiers (e.g. "every", "times", "count").
/// The property `n` may be an integer or a nested Sequins<Int> to support dynamic behavior.
public class FlowState {
    var n: Any
    var ix: Int
    
    public init(n: Any) {
        self.n = n
        self.ix = 0
    }
}

// MARK: - Flow Modifier Helper Functions

/// If the provided value is a Sequins<Int>, this function retrieves its next value.
fileprivate func getFlowValue(_ value: Any) -> Any {
    if let seq = value as? Sequins<Int> {
        switch seq.next() {
        case .v(let intVal):
            return intVal
        default:
            break
        }
    }
    return value
}

/// Flow rule for "every": returns true if (ix % n) is not zero.
fileprivate func flowEvery(_ state: FlowState) -> Bool {
    let nValue = getFlowValue(state.n)
    guard let n = nValue as? Int else { return false }
    return (state.ix % n) != 0
}

/// Flow rule for "times": returns true if the step count exceeds n.
fileprivate func flowTimes(_ state: FlowState) -> Bool {
    let nValue = getFlowValue(state.n)
    guard let n = nValue as? Int else { return false }
    return state.ix > n
}

/// Flow rule for "count": returns true ("again") if ix is less than n; otherwise resets ix.
fileprivate func flowCount(_ state: FlowState) -> Bool {
    let nValue = getFlowValue(state.n)
    guard let n = nValue as? Int else { return false }
    if state.ix < n {
        return true   // Signal "again"
    } else {
        state.ix = 0
        return false
    }
}

// MARK: - Sequins Class

/// Sequins is a lazy, step‑based sequencer that is fully generic over type T.
/// It can hold plain values (wrapped in SequinsElement.value) and nested sequences
/// (wrapped in SequinsElement.sequence), supports flow modifiers and optional transformation.
public class Sequins<T>: CustomStringConvertible {
    
    // The underlying data array.
    public var data: [SequinsElement<T>]
    
    /// The current step index (0‑based).
    public var ix: Int = 0
    
    /// A queued index override for the next step.
    public var qix: Int? = 0
    
    /// The step increment. This may be an Int or a Sequins<Int>.
    public var n: Any = 1
    
    /// Dictionary holding flow modifier states (keys like "every", "times", "count").
    public var flw: [String: FlowState] = [:]
    
    /// An optional transformation function with extra arguments.
    /// When set, each stepped value is passed through transform(value, transformArgs).
    public var transform: ((T, [Any]) -> T)?
    public var transformArgs: [Any] = []
    
    public var direction: SequinsDirection = .forward
    
    // MARK: - Initializers
    
    /// Initializes Sequins with an array of SequinsElements.
    public init(_ elements: [SequinsElement<T>]) {
        self.data = elements
        self.ix = 0
        self.qix = 0
    }
    
    /// Convenience initializer: creates a Sequins from an array of plain values.
    public convenience init(_ values: [T]) {
        let elements = values.map { SequinsElement.v($0) }
        self.init(elements)
    }
    
    /// Convenience initializer: creates a Sequins from a single value.
    public convenience init(_ value: T) {
        self.init([SequinsElement.v(value)])
    }
    
    /// If T is Character, this initializer creates a Sequins from a String.
    public convenience init(_ str: String) where T == Character {
        let chars = Array(str)
        self.init(chars)
    }
    
    // MARK: - Private Helpers
    
    /// Wraps the given index around the data array.
    private func wrapIndex(_ index: Int) -> Int {
        guard !data.isEmpty else { return 0 }
        return index % data.count
    }
    
    /// Recursively unwraps a SequinsElement to obtain a plain value.
    private func unwrapElement(_ element: SequinsElement<T>) -> T? {
        switch element {
        case .v(let v):
            return v
        case .s(let seq):
            let result = seq.next()
            switch result {
            case .v(let v):
                return v
            case .skip, .dead:
                return nil
            }
        }
    }
    
    /// Helper to process the increment value, unwrapping if it is a nested Sequins.
    private func unwrapIncrement(_ value: Any) -> Any {
        if let seq = value as? Sequins<Int> {
            switch seq.next() {
            case .v(let intVal):
                return intVal
            default:
                break
            }
        }
        return value
    }
    
    // MARK: - Core Sequencing Function
    
    /// Advances the sequins one step and returns the result.
    /// Applies flow modifiers, wraps the index, unwraps nested sequences,
    /// and applies an optional transformation.
    public func next() -> SequinsStepResult<T> {
        // Check "every" flow modifier.
        if let everyFlow = flw["every"], flowEvery(everyFlow) {
            return self.next()  // Skip this step.
        }
        // Check "times" flow modifier.
        if let timesFlow = flw["times"], flowTimes(timesFlow) {
            return .dead
        }
        // Handle "count" flow modifier.
        var again = false
        if let countFlow = flw["count"] {
            again = flowCount(countFlow)
            if again, let eFlow = flw["every"] {
                eFlow.ix -= 1  // Undo "every" increment if needed.
            }
        }
        
        // Determine the new index.
        let newIx: Int
        if let queued = qix {
            newIx = wrapIndex(queued)
        } else {
            let incValue = unwrapIncrement(n)
            let stepInc: Int = (incValue as? Int) ?? 1
            
            switch direction {
            case .forward:
                newIx = wrapIndex(ix + stepInc)
            case .backward:
                newIx = wrapIndex(ix - stepInc)
            case .drunk:
                let randomSign = Bool.random() ? 1 : -1
                newIx = wrapIndex(ix + randomSign * stepInc)
            case .random:
                newIx = Int.random(in: 0..<data.count)
            }
        }
        ix = newIx
        qix = nil
        
        // Retrieve the element at the new index.
        guard let element = data[safe: newIx] else {
            return .dead
        }
        guard let unwrapped = unwrapElement(element) else {
            return .skip
        }
        
        // Apply the transformation if set.
        var finalValue = unwrapped
        if let transformFn = transform {
            finalValue = transformFn(finalValue, transformArgs)
        }
        return .v(finalValue)
    }
    
    // Sets the direction of the sequins.
    @discardableResult
    public func setDirection(_ direction: SequinsDirection) -> Sequins<T> {
        self.direction = direction
        return self
    }
    
    /// Returns the current value without advancing the sequins.
    public func peek() -> T? {
        guard !data.isEmpty else { return nil }
        return unwrapElement(data[wrapIndex(ix)])
    }
    
    // MARK: - Data Management
    
    /// Replaces the current data with new data.
    /// (For more complex merging behavior, you can extend this method.)
    public func setData(_ newData: [SequinsElement<T>]) {
        self.data = newData
        if ix >= data.count {
            ix = wrapIndex(ix)
        }
    }
    
    /// Creates a deep copy of the Sequins.
    public func copy() -> Sequins<T> {
        let copiedElements = data.map { element -> SequinsElement<T> in
            switch element {
            case .v(let v):
                return .v(v)
            case .s(let seq):
                return .s(seq.copy())
            }
        }
        let copySeq = Sequins<T>(copiedElements)
        copySeq.ix = self.ix
        copySeq.qix = self.qix
        copySeq.n = self.n
        copySeq.flw = self.flw  // Note: this is a shallow copy; deep copy if needed.
        copySeq.transform = self.transform
        copySeq.transformArgs = self.transformArgs
        return copySeq
    }
    
    /// Bakes out a series of steps into a new Sequins.
    public func bake(_ count: Int? = nil) -> Sequins<T> {
        let cnt = count ?? data.count
        var baked: [SequinsElement<T>] = []
        for _ in 0..<cnt {
            let result = self.next()
            switch result {
            case .v(let v):
                baked.append(.v(v))
            case .skip:
                continue
            case .dead:
                break
            }
        }
        return Sequins<T>(baked)
    }
    
    // MARK: - Flow Modifiers
    
    /// Sets or updates a flow modifier for the given key.
    @discardableResult
    public func flow(_ key: String, _ n: Any) -> Sequins<T> {
        self.flw[key] = FlowState(n: n)
        return self
    }
    
    /// Shortcut for the "every" flow modifier.
    @discardableResult
    public func every(_ n: Any) -> Sequins<T> {
        return self.flow("every", n)
    }
    
    /// Shortcut for the "times" flow modifier.
    @discardableResult
    public func times(_ n: Any) -> Sequins<T> {
        return self.flow("times", n)
    }
    
    /// Shortcut for the "count" flow modifier.
    @discardableResult
    public func count(_ n: Any) -> Sequins<T> {
        return self.flow("count", n)
    }
    
    /// Sets count to the current length of data.
    @discardableResult
    public func all() -> Sequins<T> {
        return self.count(data.count)
    }
    
    // MARK: - Transformations
    
    /// Attaches a transformation function along with optional extra arguments.
    /// - Parameters:
    ///   - fn: A function that takes a value of type T and an array of extra arguments, returning a new value of type T.
    ///   - args: Additional arguments for the transformation.
    @discardableResult
    public func funcTransform(_ fn: @escaping (T, [Any]) -> T, _ args: [Any] = []) -> Sequins<T> {
        self.transform = fn
        self.transformArgs = args
        return self
    }
    
    /// Alias for funcTransform.
    @discardableResult
    public func map(_ fn: @escaping (T, [Any]) -> T, _ args: Any...) -> Sequins<T> {
        return self.funcTransform(fn, args)
    }
    
    // MARK: - Step Controls
    
    /// Sets the step increment. The increment may be an Int or a Sequins<Int>.
    @discardableResult
    public func step(_ n: Any) -> Sequins<T> {
        self.n = n
        return self
    }
    
    /// Queues a specific index to be used on the next step.
    @discardableResult
    public func select(_ index: Int) -> Sequins<T> {
        self.qix = (index < data.count ? index : index % data.count)
        return self
    }
    
    /// Resets the sequins and any nested sequins to the beginning.
    public func reset() {
        self.ix = 0
        self.qix = 0
        for element in data {
            if case .s(let seq) = element {
                seq.reset()
            }
        }
        for (_, flowState) in flw {
            flowState.ix = 0
            if let nestedSeq = flowState.n as? Sequins<Int> {
                nestedSeq.reset()
            }
        }
        for arg in transformArgs {
            if let nestedSeq = arg as? Sequins<T> {
                nestedSeq.reset()
            }
        }
    }
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        var s = "Sequins[\(ix)]: ["
        s += data.map { element -> String in
            switch element {
            case .v(let v):
                return "\(v)"
            case .s(let seq):
                return seq.description
            }
        }.joined(separator: ", ")
        s += "]"
        if !flw.isEmpty {
            for (key, flowState) in flw {
                s += " :\(key.prefix(1))[\(flowState.ix)](\(flowState.n))"
            }
        }
        if transform != nil {
            s += " :map(transform)"
        }
        return s
    }
}

// MARK: - Data Manipulation Extension

extension Sequins {
    /// Shuffles the underlying data array in place using the Fisher–Yates algorithm.
    ///
    /// - Returns: The Sequins instance (self) for chaining.
    @discardableResult
    public func shuffle() -> Sequins<T> {
        guard data.count > 1 else { return self }
        // Loop from the last index down to 1.
        for i in stride(from: data.count - 1, through: 1, by: -1) {
            // Generate a random index in the range 0...i.
            let j = Int.random(in: 0...i)
            data.swapAt(i, j)
        }
        return self
    }
    
    /// Reverses the elements in the underlying data array within the specified range.
    ///
    /// The parameters use 0‑based indexing. Negative values are interpreted as offsets from the end (e.g. -1 is the last element).
    /// If no parameters are provided, the entire array is reversed.
    ///
    /// - Parameters:
    ///   - start: The starting index of the range to reverse (default is 0).
    ///   - stop: The ending index of the range to reverse (default is data.count - 1).
    /// - Returns: The Sequins instance (self) for chaining.
    @discardableResult
    public func reverse(start: Int? = nil, stop: Int? = nil) -> Sequins<T> {
        let count = data.count
        // Determine start index (handling nil and negative values).
        var s = start ?? 0
        if s < 0 { s = count + s }
        // Determine stop index.
        var e = stop ?? (count - 1)
        if e < 0 { e = count + e }
        
        // Clamp indices to valid bounds.
        s = max(0, min(s, count - 1))
        e = max(0, min(e, count - 1))
        // If the range is invalid, adjust stop to be at least start.
        if e < s { e = s }
        
        var left = s
        var right = e
        while left < right {
            data.swapAt(left, right)
            left += 1
            right -= 1
        }
        return self
    }
    
    /// Rotates the elements in the underlying data array within the specified range by a given step.
    ///
    /// Positive step values rotate the range to the left while negative step values rotate it to the right.
    /// The parameters use 0‑based indexing, with negative values supported (e.g. -1 means the last element).
    /// If no range is provided, the entire array is rotated.
    ///
    /// - Parameters:
    ///   - step: The number of positions to rotate by. Positive rotates left; negative rotates right.
    ///   - start: The starting index for the rotation range (default is 0).
    ///   - stop: The ending index for the rotation range (default is data.count - 1).
    /// - Returns: The Sequins instance (self) for chaining.
    @discardableResult
    public func rotate(step: Int, start: Int? = nil, stop: Int? = nil) -> Sequins<T> {
        guard data.count > 0 else { return self }
        let count = data.count
        // Determine start index.
        var s = start ?? 0
        if s < 0 { s = count + s }
        // Determine stop index.
        var e = stop ?? (count - 1)
        if e < 0 { e = count + e }
        
        // Clamp indices.
        s = max(0, min(s, count - 1))
        e = max(0, min(e, count - 1))
        if e < s { e = s }
        
        // If step is 0, nothing changes.
        if step == 0 { return self }
        
        // Calculate the effective step (normalized within the subarray length).
        let subLength = e - s + 1
        let normalizedStep = ((step % subLength) + subLength) % subLength
        if normalizedStep == 0 { return self }
        
        // Rotate via three reversals:
        // 1. Reverse the first part.
        self.reverse(start: s, stop: s + normalizedStep - 1)
        // 2. Reverse the second part.
        self.reverse(start: s + normalizedStep, stop: e)
        // 3. Reverse the entire range.
        self.reverse(start: s, stop: e)
        
        return self
    }
}


// MARK: - Drunk Flow Modifier

extension Sequins {
    /// Enables the drunk behavior modifier.
    ///
    /// When active, on each call to `next()` the sequins will randomly move forward or backward
    /// using the current step increment (`n`).
    ///
    /// - Returns: The Sequins instance (self) for chaining.
    @discardableResult
    public func drunk() -> Sequins<T> {
        self.flw["drunk"] = FlowState(n: 1) // The stored value here is just a placeholder.
        return self
    }
}


// MARK: - Global Convenience Constructor

/// Global helper to create a Sequins instance from a single value.
/// This is analogous to the S() function in the Lua version.
public func S<T>(_ input: T) -> Sequins<T> {
    return Sequins<T>(input)
}
