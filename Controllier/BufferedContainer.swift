//
//  BufferedContainer.swift
//  Controllier
//
//  Created by Jared McFarland on 3/27/25.
//

import Foundation

/// A thread-safe double-buffered container that allows reading from one buffer
/// while writing to another. Generic type T must be a collection type.
@available(iOS 15.0, macOS 12.0, *)
public actor BufferedContainer<T> where T: Collection {
    /// Type alias for the element type stored in collection T
    public typealias Element = T.Element
    
    /// The internal buffer storage
    private var bufferedCache: [T]
    
    /// The index of the currently active buffer
    private var currentCacheIndex: Int = 0
    
    /// Initialize with default values
    public init() where T: DefaultConstructible {
        bufferedCache = [T(), T()]
    }
    
    /// Initialize with a specific value for both buffers
    public init(value: T) {
        bufferedCache = [value, value]
    }
    
    /// Access an element at the specified index from the current buffer
    public func element(at index: Int) -> Element? {
        let currentCache = bufferedCache[currentCacheIndex]
        
        // Handle index safely to avoid out-of-bounds access
        let safeIndex = index % currentCache.count
        guard safeIndex >= 0 && currentCache.count > 0 else { return nil }
        
        // Navigate to the desired index
        var currentIndex = currentCache.startIndex
        var currentPosition = 0
        
        while currentPosition < safeIndex && currentIndex != currentCache.endIndex {
            currentIndex = currentCache.index(after: currentIndex)
            currentPosition += 1
        }
        
        // Return the element if the index is valid
        return currentIndex != currentCache.endIndex ? currentCache[currentIndex] : nil
    }
    
    /// Get the current buffer
    public func get() -> T {
        return bufferedCache[currentCacheIndex]
    }
    
    /// Set a new value to the inactive buffer and make it active
    public func set(_ value: T) {
        let inactiveIndex = currentCacheIndex == 0 ? 1 : 0
        bufferedCache[inactiveIndex] = value
        currentCacheIndex = inactiveIndex
    }
    
    /// Get the size of the current buffer
    public var size: Int {
        return bufferedCache[currentCacheIndex].count
    }
}

/// Non-actor version for compatibility with older iOS/macOS versions
public class BufferedContainerClassic<T> where T: Collection {
    /// Type alias for the element type stored in collection T
    public typealias Element = T.Element
    
    /// The internal buffer storage
    private var bufferedCache: [T]
    
    /// The index of the currently active buffer
    private var currentCacheIndex: Int = 0
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Initialize with default values
    public init() where T: DefaultConstructible {
        bufferedCache = [T(), T()]
    }
    
    /// Initialize with a specific value for both buffers
    public init(value: T) {
        bufferedCache = [value, value]
    }
    
    /// Access an element at the specified index from the current buffer
    public func element(at index: Int) -> Element? {
        lock.lock()
        defer { lock.unlock() }
        
        let currentCache = bufferedCache[currentCacheIndex]
        
        // Handle index safely to avoid out-of-bounds access
        let safeIndex = index % currentCache.count
        guard safeIndex >= 0 && currentCache.count > 0 else { return nil }
        
        // Navigate to the desired index
        var currentIndex = currentCache.startIndex
        var currentPosition = 0
        
        while currentPosition < safeIndex && currentIndex != currentCache.endIndex {
            currentIndex = currentCache.index(after: currentIndex)
            currentPosition += 1
        }
        
        // Return the element if the index is valid
        return currentIndex != currentCache.endIndex ? currentCache[currentIndex] : nil
    }
    
    /// Get the current buffer
    public func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return bufferedCache[currentCacheIndex]
    }
    
    /// Set a new value to the inactive buffer and make it active
    public func set(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let inactiveIndex = currentCacheIndex == 0 ? 1 : 0
        bufferedCache[inactiveIndex] = value
        currentCacheIndex = inactiveIndex
    }
    
    /// Get the size of the current buffer
    public var size: Int {
        lock.lock()
        defer { lock.unlock() }
        return bufferedCache[currentCacheIndex].count
    }
}

/// Protocol for types that can be initialized with no parameters
public protocol DefaultConstructible {
    init()
}

// MARK: - Standard Collection Types Conformance

extension Array: DefaultConstructible {}
extension Dictionary: DefaultConstructible {}
extension Set: DefaultConstructible {}
