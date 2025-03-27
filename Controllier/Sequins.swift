//
//  Sequins.swift
//  Controllier
//
//  Created by Jared McFarland on 3/27/25.
//

import Foundation

// MARK: - FlowState and Flow Rules

/// A helper class to store flow modifier state (such as for "every", "times", or "count").
class FlowState {
    var n: Any
    var ix: Int
    
    init(n: Any) {
        self.n = n
        self.ix = 0
    }
}
/// Flow rule: "every" — skip the step unless (ix % n) == 0.
fileprivate func flowEvery(_ state: FlowState) -> Bool {
    let nValue = getFlowValue(state.n)
    guard let n = nValue as? Int else { return false } // Default to not skipping if n isn't an Int
    return (state.ix % n) != 0
}

/// Flow rule: "times" — if the step count exceeds n, signal termination.
fileprivate func flowTimes(_ state: FlowState) -> Bool {
    let nValue = getFlowValue(state.n)
    guard let n = nValue as? Int else { return false } // Default to not terminating if n isn't an Int
    return state.ix > n
}

/// Flow rule: "count" — if the step count is less than n, signal "again"; else reset the counter.
fileprivate func flowCount(_ state: FlowState) -> Bool {
    let nValue = getFlowValue(state.n)
    guard let n = nValue as? Int else { return false } // Default to not "again" if n isn't an Int
    if state.ix < n {
        return true   // meaning "again"
    } else {
        state.ix = 0
        return false
    }
}

/// Helper function to get the value from a flow state's n property, which might be a Sequins.
fileprivate func getFlowValue(_ value: Any) -> Any {
    if let sequins = value as? Sequins, let nextVal = sequins.next() {
        return nextVal
    }
    return value
}

/// A dictionary mapping flow names to functions.
fileprivate let FLOWS: [String: (FlowState) -> Bool] = [
    "every": flowEvery,
    "times": flowTimes,
    // "count" is handled separately because it returns a Bool flag for "again"
]

// MARK: - Sequins Class

/// Sequins is a lazy, step‑based sequencer that stores a sequence of data (which may include nested Sequins),
/// supports flow modifiers (every, times, count) and an optional transformation function.
/// This dynamic version uses 0‑based indexing.
class Sequins: CustomStringConvertible {
    
    /// The underlying data array. Elements can be of any type, including another Sequins.
    var data: [Any]
    
    /// The current step index (0‑based).
    var ix: Int = 0
    
    /// An optional queued index override for the next step. If set, the next call to next() will jump to this index.
    var qix: Int? = 0
    
    /// The step increment. This may also be a nested Sequins.
    var n: Any = 1
    
    /// A dictionary to hold flow modifiers (e.g. "every", "times", "count").
    var flw: [String: FlowState] = [:]
    
    /// An optional transformation function with additional arguments.
    /// When set, each stepped value is passed through transform(value, args...).
    var transform: ((Any) -> Any)?
    var transformArgs: [Any] = []
    
    // MARK: - Initializer
    
    /// Initialize with data t. If t is a String, it is converted into an array of Characters.
    init(_ t: Any) {
        if let str = t as? String {
            self.data = Array(str)
        } else if let arr = t as? [Any] {
            self.data = arr
        } else {
            self.data = [t]
        }
        self.ix = 0
        self.qix = 0
    }
    
    // MARK: - Helper: Unwrapping (Turtle)
    
    /// If a value is a Sequins, step it (recursively) until a non‑Sequins value is produced.
    fileprivate func unwrap(_ value: Any) -> Any {
        var current = value
        while let nested = current as? Sequins {
            if let nextVal = nested.next() {
                current = nextVal
            } else {
                break
            }
        }
        return current
    }
    
    // MARK: - Next Step
    
    /// Advances the sequins one step and returns the next value.
    /// If a flow modifier indicates that the step should be skipped or that the sequins is “dead,” the function returns "skip" or "dead" accordingly.
    func next() -> Any? {
        // Check "every" flow: if exists and its condition holds, skip this step.
        if let everyFlow = flw["every"], flowEvery(everyFlow) {
            // Already incremented; recursively get the next step.
            return next()
        }
        // Check "times" flow: if exists and indicates termination, return "dead".
        if let timesFlow = flw["times"], flowTimes(timesFlow) {
            return "dead"
        }
        // Check "count" flow: if exists, determine if we should signal "again".
        var again = false
        if let countFlow = flw["count"] {
            again = flowCount(countFlow)
            if again {  // if "again", then revert any "every" increment (if needed)
                if let eFlow = flw["every"] {
                    eFlow.ix -= 1
                }
            }
        }
        
        // Determine the new index.
        let newIx: Int
        if let queued = qix {
            newIx = wrapIndex(queued)
        } else {
            // Evaluate step increment: if n is callable (i.e. a Sequins), unwrap it; else assume an Int.
            let incVal = unwrap(n)
            if let inc = incVal as? Int {
                newIx = wrapIndex(ix + inc)
            } else {
                newIx = wrapIndex(ix + 1)
            }
        }
        ix = newIx
        qix = nil
        
        // Get the value at newIx.
        let rawVal = (newIx < data.count) ? data[newIx] : nil
        guard let stepped = rawVal else { return nil }
        
        // Recursively unwrap nested Sequins.
        let unwrapped = unwrap(stepped)
        
        // Apply the transformation function if one exists.
        if let fn = transform {
            let transformed = fn(unwrapped)  // For simplicity, additional transformArgs are ignored here;
            // you could extend this to pass transformArgs if desired.
            return transformed
        }
        return unwrapped
    }
    
    /// Wrap the given index (0‑based) around the length of data.
    private func wrapIndex(_ index: Int) -> Int {
        if data.isEmpty { return 0 }
        return index % data.count
    }
    
    // MARK: - Peek
    
    /// Returns the current value without advancing the sequins.
    func peek() -> Any? {
        if data.isEmpty { return nil }
        return data[wrapIndex(ix)]
    }
    
    // MARK: - Data Management
    
    /// Replaces the current data with new data.
    /// If t is a Sequins, its data (and any nested sequins) are merged.
    func setData(_ t: Any) {
        var newData: [Any]
        if let seq = t as? Sequins {
            // Merge flow modifiers.
            for (key, fSrc) in seq.flw {
                if let fDst = flw[key] {
                    fDst.n = fSrc.n
                } else {
                    flw[key] = FlowState(n: fSrc.n)
                }
            }
            // Merge transform.
            if let newTrans = seq.transform {
                if self.transform == nil {
                    self.transform = newTrans
                    self.transformArgs = seq.transformArgs
                } else {
                    // If already set, you could choose to override or combine.
                    self.transform = newTrans
                    self.transformArgs = seq.transformArgs
                }
            }
            // Use seq's data.
            newData = seq.data
        } else if let str = t as? String {
            newData = Array(str)
        } else if let arr = t as? [Any] {
            newData = arr
        } else {
            newData = [t]
        }
        // For each element, if both the new element and the existing element are Sequins, call setData recursively.
        for i in 0..<newData.count {
            if i < data.count, let newElem = newData[safe: i], let oldSeq = data[safe: i] as? Sequins, newElem is Sequins {
                oldSeq.setData(newElem)
            } else if i < data.count {
                data[i] = newData[i]
            } else {
                data.append(newData[i])
            }
        }
        // Truncate if necessary.
        if newData.count < data.count {
            data.removeSubrange(newData.count..<data.count)
        }
        // Update length.
        // (Since we're using an array, data.count is always current.)
        // Reset index if out-of-bounds.
        if ix >= data.count { ix = wrapIndex(ix) }
    }
    
    /// Returns a deep copy of this Sequins.
    func copy() -> Sequins {
        let copySeq = Sequins(self.data)
        copySeq.ix = self.ix
        copySeq.qix = self.qix
        copySeq.n = self.n
        // Shallow copy of flows and transform (deep copy if needed)
        copySeq.flw = self.flw  // In a more thorough implementation, you might deep-copy each FlowState.
        copySeq.transform = self.transform
        copySeq.transformArgs = self.transformArgs
        return copySeq
    }
    
    /// Bakes out a series of steps (default is the full length) into a new Sequins.
    func bake(_ count: Int? = nil) -> Sequins {
        let cnt = count ?? data.count
        var baked: [Any] = []
        for _ in 0..<cnt {
            if let v = self.next() {
                baked.append(v)
            }
        }
        return Sequins(baked)
    }
    
    // MARK: - Flow Modifiers
    
    /// Sets or updates a flow modifier (by key) with the given n.
    @discardableResult
    func flow(_ key: String, _ n: Any) -> Sequins {
        self.flw[key] = FlowState(n: n)
        return self
    }
    
    @discardableResult
    func every(_ n: Any) -> Sequins {
        return self.flow("every", n)
    }
    
    @discardableResult
    func times(_ n: Any) -> Sequins {
        return self.flow("times", n)
    }
    
    @discardableResult
    func count(_ n: Any) -> Sequins {
        return self.flow("count", n)
    }
    
    /// Sets count to the current length of data.
    @discardableResult
    func all() -> Sequins {
        return self.count(data.count)
    }
    
    // MARK: - Transformations
    
    /// Attaches a transformation function along with optional extra arguments.
    @discardableResult
    func funcTransform(_ fn: @escaping (Any, [Any]) -> Any, _ args: [Any] = []) -> Sequins {
        self.transform = { value in
            return fn(value, args)
        }
        self.transformArgs = args
        return self
    }
    
    /// Alias for funcTransform.
    @discardableResult
    func map(_ fn: @escaping (Any, [Any]) -> Any, _ args: Any...) -> Sequins {
        return self.funcTransform(fn, args)
    }
    
    // MARK: - Step Controls
    
    /// Sets the step increment (n). n may be an integer or a Sequins.
    @discardableResult
    func step(_ n: Any) -> Sequins {
        self.n = n
        return self
    }
    
    /// Queues a specific index to be used on the next step.
    @discardableResult
    func select(_ ix: Int) -> Sequins {
        self.qix = (ix < data.count ? ix : ix % data.count)
        return self
    }
    
    /// Resets the sequins (and any nested sequins) to the beginning.
    func reset() {
        self.ix = 0
        self.qix = 0
        for elem in data {
            if let nested = elem as? Sequins {
                nested.reset()
            }
        }
        for (_, flowState) in flw {
            flowState.ix = 0
            if let nestedSequins = flowState.n as? Sequins {
                nestedSequins.reset()
            }
        }
        for arg in transformArgs {
            if let nested = arg as? Sequins {
                nested.reset()
            }
        }
    }
    
    // MARK: - Description
    
    var description: String {
        var s = "Sequins[\(ix)]: [\(data.map { "\($0)" }.joined(separator: ", "))]"
        if !flw.isEmpty {
            for (key, flowState) in flw {
                s += " :\(key.prefix(1))[\(flowState.ix)](\(flowState.n))"
            }
        }
        if let tfn = transform {
            s += " :map(\(String(describing: tfn)))"
        }
        return s
    }
}

// MARK: - Convenience Constructors

/// Constructs a Sequins from a value (array, string, or single value).
func S(_ t: Any? = nil) -> Sequins {
    if let tUnwrapped = t {
        return Sequins(tUnwrapped)
    } else {
        return Sequins([])
    }
}

// MARK: - Array Safe Access Extension

extension Array {
    /// Returns the element at the given index if it exists; otherwise nil.
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Example Usage

#if DEBUG
// Uncomment the following lines to test in a Swift playground or project.
//let s1 = S("abcd")  // Sequins of Characters
//print(s1)           // e.g. "Sequins[0]: [a, b, c, d] ..."
//if let first = s1.next() {
//    print("First step:", first) // should print 'a'
//}
//if let second = s1.next() {
//    print("Second step:", second) // should print 'b'
//}
//print("Peek:", s1.peek() ?? "nil")
//
//// Demonstrate nested Sequins:
//let nested = S(["X", S("yz"), "W"])
//print("Nested before stepping:", nested)
//if let n1 = nested.next() {
//    print("Nested first step:", n1) // Should unwrap nested sequins in second element.
//}
//nested.reset()
//print("After reset:", nested)
//#endif
#endif
