//
//  BufferedContainer.swift
//  Controllier
//
//  Created by Jared McFarland on 3/27/25.
//

import Foundation

/// A thread-safe double-buffered container that allows reading from one buffer while writing to another.
/// Generic type T must be a collection type that provides `count` and subscript functionality.
public class BufferedContainer<T> where T: Collection {
    /// Type alias for the element type stored in collection T
    public typealias Element = T.Element
    
    /// Initialize with default values
    public init() where T: DefaultConstructible {
        bufferedCache = [T(), T()]
    }
    
    /// Initialize with a specific value for both buffers
    public init(value: T) {
        bufferedCache = [value, value]
    }
    
    /// Access an element at the specified index from the current buffer
    public subscript(index: Int) -> Element {
        let currentCache = bufferedCache[currentCacheIndex.load(ordering: .acquiring)]
        
        // Use the collection's startIndex and index advancing to safely access elements
        var elementIndex = currentCache.startIndex
        let targetIndex = index % currentCache.count
        
        // Advance the index to the target position
        for _ in 0..<targetIndex {
            elementIndex = currentCache.index(after: elementIndex)
        }
        
        return currentCache[elementIndex]
    }
    
    /// Get the current buffer
    public func get() -> T {
        return bufferedCache[currentCacheIndex.load(ordering: .acquiring)]
    }
    
    /// Set a new value to the inactive buffer and make it active
    public func set(_ value: T) {
        let cacheIdx = currentCacheIndex.load(ordering: .acquiring) == 0 ? 1 : 0
        bufferedCache[cacheIdx] = value
        currentCacheIndex.store(cacheIdx, ordering: .releasing)
    }
    
    /// Get the size of the current buffer
    public var size: Int {
        return bufferedCache[currentCacheIndex.load(ordering: .acquiring)].count
    }
    
    // MARK: - Private
    
    private var bufferedCache: [T]
    private let currentCacheIndex = AtomicInteger(value: 0)
}

/// Protocol for types that can be initialized with no parameters
public protocol DefaultConstructible {
    init()
}

/// Simple atomic integer implementation using os_unfair_lock
public class AtomicInteger {
    private var lock = os_unfair_lock_s()
    
    public init(value: Int) {
        self.value = value
    }
    
    public func load(ordering: AtomicLoadOrdering) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return value
    }
    
    public func store(_ desired: Int, ordering: AtomicStoreOrdering) {
        os_unfair_lock_lock(&lock)
        value = desired
        os_unfair_lock_unlock(&lock)
    }
    
    private var value: Int
}

/// Memory ordering for atomic loads
public enum AtomicLoadOrdering {
    case relaxed
    case acquiring
}

/// Memory ordering for atomic stores
public enum AtomicStoreOrdering {
    case relaxed
    case releasing
}

// MARK: - Standard Collection Types Conformance

extension Array: DefaultConstructible {}
extension Dictionary: DefaultConstructible {}
extension Set: DefaultConstructible {}
