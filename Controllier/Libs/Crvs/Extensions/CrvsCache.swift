import Foundation
import os

extension Crvs {
    
    // MARK: - Advanced Cache Policies
    
    /// Cache eviction strategy options
    public enum CacheEvictionPolicy {
        /// Standard LRU (Least Recently Used)
        case lru
        /// Time-based expiration
        case timeToLive(TimeInterval)
        /// Segmented LRU (combines recency and frequency)
        case segmentedLRU
        /// Adaptive (dynamically adjusts based on access patterns)
        case adaptive
    }
    
    // MARK: - Memoization Utilities
    
    /// Advanced memoization wrapper for FloatOp functions with enhanced caching strategy
    public static func memoize<C: CacheProtocol>(_ op: @escaping FloatOp,
                                                 precision: Float = 0.001,
                                                 cache: C) -> FloatOp where C.Key == Int, C.Value == Float {
        
        // Create and return memoized function
        return { pos in
            // Discretize input to increase cache hits
            let discretePos = Int(pos / precision)
            
            // Try to get from cache
            if let cachedValue = cache.get(discretePos) {
                return cachedValue
            }
            
            // Calculate and store result
            let result = op(pos)
            cache.set(discretePos, result)
            return result
        }
    }
    
    /// Standard memoization with default LRU cache
    public static func memoize(_ op: @escaping FloatOp,
                               precision: Float = 0.001,
                               cacheSize: Int = 1000,
                               policy: CacheEvictionPolicy = .lru) -> FloatOp {
        
        // Create appropriate cache based on policy
        let cache: any CacheProtocol<Int, Float>
        
        switch policy {
        case .lru:
            cache = LRUCache<Int, Float>(capacity: cacheSize)
        case .timeToLive(let ttl):
            cache = TTLCache<Int, Float>(capacity: cacheSize, ttl: ttl)
        case .segmentedLRU:
            cache = SegmentedLRUCache<Int, Float>(capacity: cacheSize)
        case .adaptive:
            cache = AdaptiveCache<Int, Float>(capacity: cacheSize)
        }
        
        // Use the generic memoize function
        return memoize(op, precision: precision, cache: cache)
    }
    
    // MARK: - Cache Protocol
    
    /// Protocol defining cache behavior with generic parameters
    public protocol CacheProtocol<Key, Value> {
        associatedtype Key: Hashable
        associatedtype Value
        
        /// Get a value by key
        func get(_ key: Key) -> Value?
        
        /// Set a value for a key
        func set(_ key: Key, _ value: Value)
        
        /// Clear the cache
        func clear()
        
        /// Get current size
        var count: Int { get }
        
        /// Get capacity
        var capacity: Int { get }
    }
    
    // MARK: - Advanced LRU Cache Implementation
    
    /// Thread-safe LRU cache with enhanced performance
    public final class LRUCache<Key: Hashable, Value>: CacheProtocol {
        private struct CacheEntry {
            let key: Key
            var value: Value
            var accessCount: Int = 1
            var lastAccessed: Date = Date()
            
            init(key: Key, value: Value) {
                self.key = key
                self.value = value
            }
        }
        
        public let capacity: Int
        private let lock = NSLock()
        private var cache = [Key: CacheEntry]()
        private var keysInOrder = [Key]()
        private let batchUpdateSize: Int
        private var pendingUpdates = 0
        private var hitCount: Int = 0
        private var missCount: Int = 0
        private let logger = Logger(subsystem: "com.crvs.cache", category: "LRUCache")
        
        public init(capacity: Int, batchUpdateSize: Int = 10) {
            self.capacity = max(1, capacity)
            self.batchUpdateSize = max(1, batchUpdateSize)
        }
        
        public func get(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            
            guard let entry = cache[key] else {
                missCount += 1
                return nil
            }
            
            // Update access stats
            var updatedEntry = entry
            updatedEntry.accessCount += 1
            updatedEntry.lastAccessed = Date()
            cache[key] = updatedEntry
            
            // Batch LRU list updates for performance
            if let index = keysInOrder.firstIndex(of: key) {
                keysInOrder.remove(at: index)
                keysInOrder.append(key)
                
                pendingUpdates += 1
                if pendingUpdates >= batchUpdateSize {
                    reorganizeCache()
                }
            }
            
            hitCount += 1
            return entry.value
        }
        
        public func set(_ key: Key, _ value: Value) {
            lock.lock()
            defer { lock.unlock() }
            
            let newEntry = CacheEntry(key: key, value: value)
            
            // Check if key already exists
            if cache[key] != nil {
                cache[key] = newEntry
                
                // Move to end of usage order
                if let index = keysInOrder.firstIndex(of: key) {
                    keysInOrder.remove(at: index)
                }
                keysInOrder.append(key)
                return
            }
            
            // If cache is at capacity, evict least recently used
            if cache.count >= capacity {
                evictEntries(count: 1)
            }
            
            // Add new entry
            cache[key] = newEntry
            keysInOrder.append(key)
        }
        
        public func clear() {
            lock.lock()
            defer { lock.unlock() }
            
            cache.removeAll(keepingCapacity: true)
            keysInOrder.removeAll(keepingCapacity: true)
            hitCount = 0
            missCount = 0
            pendingUpdates = 0
        }
        
        public var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return cache.count
        }
        
        // Reorganize cache when needed
        private func reorganizeCache() {
            // Reset pending updates counter
            pendingUpdates = 0
            
            // If cache is approaching capacity, preemptively evict some entries
            if cache.count > Int(Double(capacity) * 0.9) {
                evictEntries(count: max(1, capacity / 10))
            }
        }
        
        // Evict entries based on LRU policy
        private func evictEntries(count: Int) {
            // Evict oldest entries
            let entriesToRemove = min(count, keysInOrder.count)
            for i in 0..<entriesToRemove {
                let keyToRemove = keysInOrder[i]
                cache.removeValue(forKey: keyToRemove)
            }
            
            // Update keys order
            if entriesToRemove > 0 {
                keysInOrder.removeSubrange(0..<entriesToRemove)
            }
        }
        
        // Get cache statistics
        public func getStats() -> (hitRate: Double, entryCount: Int) {
            lock.lock()
            defer { lock.unlock() }
            
            let totalAccesses = hitCount + missCount
            let hitRate = totalAccesses > 0 ? Double(hitCount) / Double(totalAccesses) : 0.0
            return (hitRate: hitRate, entryCount: cache.count)
        }
    }
    
    // MARK: - TTL Cache Implementation
    
    /// Cache with time-based expiration
    public final class TTLCache<Key: Hashable, Value>: CacheProtocol {
        private struct CacheEntry {
            let key: Key
            var value: Value
            let expirationTime: Date
            
            var isExpired: Bool {
                return Date() > expirationTime
            }
            
            init(key: Key, value: Value, ttl: TimeInterval) {
                self.key = key
                self.value = value
                self.expirationTime = Date().addingTimeInterval(ttl)
            }
        }
        
        public let capacity: Int
        private let ttl: TimeInterval
        private let lock = NSLock()
        private var cache = [Key: CacheEntry]()
        private var cleanupTimer: Timer?
        private var lastCleanup = Date()
        private let cleanupInterval: TimeInterval
        
        public init(capacity: Int, ttl: TimeInterval, cleanupInterval: TimeInterval = 60.0) {
            self.capacity = max(1, capacity)
            self.ttl = max(1.0, ttl)
            self.cleanupInterval = cleanupInterval
            
            // Schedule periodic cleanup
            setupCleanupTimer()
        }
        
        private func setupCleanupTimer() {
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
                self?.removeExpiredEntries()
            }
        }
        
        public func get(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            
            // Check if entry exists and is not expired
            guard let entry = cache[key], !entry.isExpired else {
                // Remove expired entry if it exists
                if cache[key]?.isExpired == true {
                    cache.removeValue(forKey: key)
                }
                return nil
            }
            
            return entry.value
        }
        
        public func set(_ key: Key, _ value: Value) {
            lock.lock()
            defer { lock.unlock() }
            
            // Create new entry with TTL
            let newEntry = CacheEntry(key: key, value: value, ttl: ttl)
            
            // If cache is at capacity and key doesn't exist, remove least recently used
            if cache.count >= capacity && cache[key] == nil {
                removeOldestEntries(count: 1)
            }
            
            // Add/update entry
            cache[key] = newEntry
            
            // Perform cleanup if needed
            if Date().timeIntervalSince(lastCleanup) > cleanupInterval {
                removeExpiredEntries()
            }
        }
        
        public func clear() {
            lock.lock()
            defer { lock.unlock() }
            
            cache.removeAll(keepingCapacity: true)
        }
        
        private func removeExpiredEntries() {
            lock.lock()
            defer {
                lock.unlock()
                lastCleanup = Date()
            }
            
            // Find and remove all expired entries
            let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
            for key in expiredKeys {
                cache.removeValue(forKey: key)
            }
        }
        
        private func removeOldestEntries(count: Int) {
            // Sort by expiration time and remove oldest
            let sortedEntries = cache.values.sorted { $0.expirationTime < $1.expirationTime }
            let entriesToRemove = min(count, sortedEntries.count)
            
            for i in 0..<entriesToRemove {
                cache.removeValue(forKey: sortedEntries[i].key)
            }
        }
        
        public var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return cache.count
        }
        
        deinit {
            cleanupTimer?.invalidate()
        }
    }
    
    // MARK: - Segmented LRU Cache Implementation
    
    /// Segmented LRU cache (better for workloads with both temporal and frequency locality)
    public final class SegmentedLRUCache<Key: Hashable, Value>: CacheProtocol {
        private struct CacheEntry {
            let key: Key
            var value: Value
            var accessCount: Int = 1
            var lastAccessed: Date = Date()
            
            init(key: Key, value: Value) {
                self.key = key
                self.value = value
            }
        }
        
        public let capacity: Int
        private let probationarySegmentRatio: Double
        private let lock = NSLock()
        
        // Two-segment cache (probationary and protected)
        private var probationaryCache = [Key: CacheEntry]()
        private var protectedCache = [Key: CacheEntry]()
        
        // LRU tracking
        private var probationaryLRU = [Key]()
        private var protectedLRU = [Key]()
        
        public init(capacity: Int, probationaryRatio: Double = 0.2) {
            self.capacity = max(1, capacity)
            self.probationarySegmentRatio = min(max(0.1, probationaryRatio), 0.5)
        }
        
        public func get(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            
            // Check protected cache first
            if let entry = protectedCache[key] {
                updateProtectedEntry(key: key, entry: entry)
                return entry.value
            }
            
            // Then check probationary cache
            if let entry = probationaryCache[key] {
                // Promote to protected cache if frequently accessed
                var updatedEntry = entry
                updatedEntry.accessCount += 1
                updatedEntry.lastAccessed = Date()
                
                if updatedEntry.accessCount >= 2 {
                    promoteEntry(key: key, entry: updatedEntry)
                } else {
                    // Update in probationary cache
                    probationaryCache[key] = updatedEntry
                    
                    // Update LRU order
                    if let index = probationaryLRU.firstIndex(of: key) {
                        probationaryLRU.remove(at: index)
                    }
                    probationaryLRU.append(key)
                }
                
                return entry.value
            }
            
            return nil
        }
        
        public func set(_ key: Key, _ value: Value) {
            lock.lock()
            defer { lock.unlock() }
            
            let newEntry = CacheEntry(key: key, value: value)
            
            // Update if key exists in either cache
            if protectedCache[key] != nil {
                protectedCache[key] = newEntry
                updateProtectedEntry(key: key, entry: newEntry)
                return
            }
            
            if probationaryCache[key] != nil {
                probationaryCache[key] = newEntry
                
                // Update LRU order
                if let index = probationaryLRU.firstIndex(of: key) {
                    probationaryLRU.remove(at: index)
                }
                probationaryLRU.append(key)
                return
            }
            
            // New entry goes to probationary cache
            checkCapacity()
            
            probationaryCache[key] = newEntry
            probationaryLRU.append(key)
        }
        
        private func updateProtectedEntry(key: Key, entry: CacheEntry) {
            var updatedEntry = entry
            updatedEntry.accessCount += 1
            updatedEntry.lastAccessed = Date()
            protectedCache[key] = updatedEntry
            
            // Update LRU order
            if let index = protectedLRU.firstIndex(of: key) {
                protectedLRU.remove(at: index)
            }
            protectedLRU.append(key)
        }
        
        private func promoteEntry(key: Key, entry: CacheEntry) {
            // Remove from probationary
            probationaryCache.removeValue(forKey: key)
            if let index = probationaryLRU.firstIndex(of: key) {
                probationaryLRU.remove(at: index)
            }
            
            // Check if protected segment needs eviction
            let protectedMaxSize = Int(Double(capacity) * (1.0 - probationarySegmentRatio))
            if protectedCache.count >= protectedMaxSize {
                // Demote least recently used protected item to probationary
                if let lruKey = protectedLRU.first, let entry = protectedCache[lruKey] {
                    protectedCache.removeValue(forKey: lruKey)
                    protectedLRU.removeFirst()
                    
                    // Reset access count for demotion
                    var demotedEntry = entry
                    demotedEntry.accessCount = 1
                    probationaryCache[lruKey] = demotedEntry
                    probationaryLRU.append(lruKey)
                }
            }
            
            // Add to protected
            protectedCache[key] = entry
            protectedLRU.append(key)
        }
        
        private func checkCapacity() {
            let totalCount = probationaryCache.count + protectedCache.count
            
            if totalCount >= capacity {
                // Evict from probationary cache first
                if !probationaryLRU.isEmpty {
                    let keyToRemove = probationaryLRU.removeFirst()
                    probationaryCache.removeValue(forKey: keyToRemove)
                }
                // If still at capacity, evict from protected
                else if !protectedLRU.isEmpty {
                    let keyToRemove = protectedLRU.removeFirst()
                    protectedCache.removeValue(forKey: keyToRemove)
                }
            }
        }
        
        public func clear() {
            lock.lock()
            defer { lock.unlock() }
            
            probationaryCache.removeAll(keepingCapacity: true)
            protectedCache.removeAll(keepingCapacity: true)
            probationaryLRU.removeAll(keepingCapacity: true)
            protectedLRU.removeAll(keepingCapacity: true)
        }
        
        public var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return probationaryCache.count + protectedCache.count
        }
    }
    
    // MARK: - Adaptive Cache Implementation
    
    /// Adaptive cache that dynamically adjusts eviction strategy based on access patterns
    public final class AdaptiveCache<Key: Hashable, Value>: CacheProtocol {
        private enum EntryState: Int {
            case new = 0
            case infrequent = 1
            case frequent = 2
        }
        
        private struct CacheEntry {
            let key: Key
            var value: Value
            var state: EntryState
            var accessCount: Int
            var lastAccessed: Date
            
            init(key: Key, value: Value) {
                self.key = key
                self.value = value
                self.state = .new
                self.accessCount = 1
                self.lastAccessed = Date()
            }
        }
        
        public let capacity: Int
        private let lock = NSLock()
        private var cache = [Key: CacheEntry]()
        private var lruKeys = [EntryState: [Key]]()
        private var adaptationTimer: Timer?
        private var accessPattern = [Bool]() // true = hit, false = miss
        private let patternHistorySize = 100
        private var currentStrategy: CacheEvictionPolicy = .lru
        
        public init(capacity: Int) {
            self.capacity = max(1, capacity)
            
            // Initialize LRU tracking for each state
            lruKeys[.new] = []
            lruKeys[.infrequent] = []
            lruKeys[.frequent] = []
            
            // Setup adaptation timer
            setupAdaptationTimer()
        }
        
        private func setupAdaptationTimer() {
            adaptationTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
                self?.adaptStrategy()
            }
        }
        
        public func get(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            
            if let entry = cache[key] {
                updateEntryAccess(key: key, entry: entry)
                accessPattern.append(true)
                if accessPattern.count > patternHistorySize {
                    accessPattern.removeFirst()
                }
                return entry.value
            }
            
            accessPattern.append(false)
            if accessPattern.count > patternHistorySize {
                accessPattern.removeFirst()
            }
            return nil
        }
        
        public func set(_ key: Key, _ value: Value) {
            lock.lock()
            defer { lock.unlock() }
            
            // Update existing entry
            if let entry = cache[key] {
                var updatedEntry = entry
                updatedEntry.value = value
                updatedEntry.lastAccessed = Date()
                cache[key] = updatedEntry
                
                // Update LRU tracking
                updateLRUTracking(key: key, oldState: entry.state, newState: entry.state)
                return
            }
            
            // Check capacity
            if cache.count >= capacity {
                evictEntry()
            }
            
            // Add new entry
            let newEntry = CacheEntry(key: key, value: value)
            cache[key] = newEntry
            lruKeys[.new]?.append(key)
        }
        
        private func updateEntryAccess(key: Key, entry: CacheEntry) {
            var updatedEntry = entry
            updatedEntry.accessCount += 1
            updatedEntry.lastAccessed = Date()
            
            // Determine new state based on access count
            let oldState = entry.state
            var newState = oldState
            
            if oldState == .new && updatedEntry.accessCount >= 2 {
                newState = .infrequent
            } else if oldState == .infrequent && updatedEntry.accessCount >= 4 {
                newState = .frequent
            }
            
            updatedEntry.state = newState
            cache[key] = updatedEntry
            
            // Update LRU tracking if state changed
            if oldState != newState {
                updateLRUTracking(key: key, oldState: oldState, newState: newState)
            } else {
                // Move to end of current state's LRU list
                if let index = lruKeys[newState]?.firstIndex(of: key) {
                    lruKeys[newState]?.remove(at: index)
                    lruKeys[newState]?.append(key)
                }
            }
        }
        
        private func updateLRUTracking(key: Key, oldState: EntryState, newState: EntryState) {
            // Remove from old state's LRU list
            if let index = lruKeys[oldState]?.firstIndex(of: key) {
                lruKeys[oldState]?.remove(at: index)
            }
            
            // Add to end of new state's LRU list
            lruKeys[newState]?.append(key)
        }
        
        private func evictEntry() {
            // Eviction priority: new -> infrequent -> frequent
            for state in [EntryState.new, .infrequent, .frequent] {
                if var keys = lruKeys[state], !keys.isEmpty {
                    let keyToRemove = keys.removeFirst()
                    cache.removeValue(forKey: keyToRemove)
                    lruKeys[state] = keys
                    return
                }
            }
        }
        
        private func adaptStrategy() {
            guard accessPattern.count >= 30 else { return }
            
            // Calculate hit rate
            let hitCount = accessPattern.filter { $0 }.count
            let hitRate = Double(hitCount) / Double(accessPattern.count)
            
            // Detect temporal vs frequency locality
            var sequentialHits = 0
            var maxSequentialHits = 0
            var repeatedKeyHits = Set<Bool>()
            
            for isHit in accessPattern {
                if isHit {
                    sequentialHits += 1
                    if sequentialHits > maxSequentialHits {
                        maxSequentialHits = sequentialHits
                    }
                } else {
                    sequentialHits = 0
                }
                repeatedKeyHits.insert(isHit)
            }
            
            // Adjust strategy based on patterns
            if hitRate < 0.3 {
                // Low hit rate: use time-based eviction with short TTL
                currentStrategy = .timeToLive(30.0)
            } else if maxSequentialHits > 10 {
                // Sequential access patterns: use standard LRU
                currentStrategy = .lru
            } else if repeatedKeyHits.count < accessPattern.count / 2 {
                // Repeated key access: use segmented LRU
                currentStrategy = .segmentedLRU
            } else {
                // Balanced workload: use adaptive approach
                currentStrategy = .adaptive
            }
        }
        
        public func clear() {
            lock.lock()
            defer { lock.unlock() }
            
            cache.removeAll(keepingCapacity: true)
            lruKeys[.new]?.removeAll(keepingCapacity: true)
            lruKeys[.infrequent]?.removeAll(keepingCapacity: true)
            lruKeys[.frequent]?.removeAll(keepingCapacity: true)
            accessPattern.removeAll(keepingCapacity: true)
        }
        
        public var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return cache.count
        }
        
        deinit {
            adaptationTimer?.invalidate()
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Batch processing for multiple values with a single operation
    public static func batchProcess<T>(_ inputs: [T],
                                       _ op: @escaping (T) -> Float,
                                       cache: LRUCache<T, Float>? = nil) -> [Float] {
        // Use concurrent processing for large batches
        var results = [Float](repeating: 0, count: inputs.count)
        
        // Process each input
        for (index, input) in inputs.enumerated() {
            // Check cache first if provided
            if let cache = cache, let cachedValue = cache.get(input) {
                results[index] = cachedValue
                continue
            }
            
            // Process the input
            let result = op(input)
            
            // Cache the result if cache provided
            cache?.set(input, result)
            
            // Store the result
            results[index] = result
        }
        
        return results
    }
    
    // MARK: - Optimized Wavetable Access
    
    /// Precomputed lookup tables for common waveforms with enhanced caching
    public class WaveformTables {
        private let sineTable: [Float]
        private let triangleTable: [Float]
        private let sawTable: [Float]
        private let tableSize: Int
        private let calculationCache = LRUCache<String, [Float]>(capacity: 10)
        
        public init(tableSize: Int = 4096) {
            self.tableSize = tableSize
            
            // Precompute sine table
            sineTable = (0..<tableSize).map { i in
                let phase = Float(i) / Float(tableSize)
                return (sin(phase * 2.0 * Float.pi) * 0.5) + 0.5
            }
            
            // Precompute triangle table
            triangleTable = (0..<tableSize).map { i in
                let phase = Float(i) / Float(tableSize)
                return phase < 0.5 ? (phase * 2.0) : (2.0 - (phase * 2.0))
            }
            
            // Precompute saw table
            sawTable = (0..<tableSize).map { i in
                let phase = Float(i) / Float(tableSize)
                return 1.0 - phase
            }
        }
        
        /// Lookup sine value with interpolation
        public func lookupSine(_ phase: Float) -> Float {
            return lookupTable(sineTable, phase)
        }
        
        /// Lookup triangle value with interpolation
        public func lookupTriangle(_ phase: Float) -> Float {
            return lookupTable(triangleTable, phase)
        }
        
        /// Lookup saw value with interpolation
        public func lookupSaw(_ phase: Float) -> Float {
            return lookupTable(sawTable, phase)
        }
        
        /// Generic table lookup with interpolation
        private func lookupTable(_ table: [Float], _ phase: Float) -> Float {
            let wrappedPhase = phase - floor(phase)
            let scaledPos = wrappedPhase * Float(tableSize)
            let index1 = Int(scaledPos) % tableSize
            let index2 = (index1 + 1) % tableSize
            let fraction = scaledPos - Float(index1)
            
            return (table[index1] * (1.0 - fraction)) + (table[index2] * fraction)
        }
        
        /// Generate optimized wavetable with parameters
        public func generateWavetable(type: String, params: [String: Float], size: Int) -> [Float] {
            // Create cache key
            let cacheKey = "\(type)_\(size)_" + params.sorted(by: { $0.key < $1.key })
                .map { "\($0.key)_\($0.value)" }
                .joined(separator: "_")
            
            // Check cache
            if let cached = calculationCache.get(cacheKey) {
                return cached
            }
            
            // Generate wavetable
            var table: [Float]
            
            switch type {
            case "sine":
                let feedback = params["feedback"] ?? 0.0
                
                if feedback == 0.0 {
                    // Optimization for standard sine
                    table = (0..<size).map { i in
                        let phase = Float(i) / Float(size)
                        return (sin(phase * 2.0 * Float.pi) * 0.5) + 0.5
                    }
                } else {
                    // Compute with feedback
                    table = (0..<size).map { i in
                        var phase = Float(i) / Float(size)
                        phase += feedback * ((sin(phase * 2.0 * Float.pi) * 0.5) + 0.5)
                        return (sin(phase * 2.0 * Float.pi) * 0.5) + 0.5
                    }
                }
                
            case "triangle":
                let symmetry = params["symmetry"] ?? 0.5
                
                table = (0..<size).map { i in
                    let phase = Float(i) / Float(size)
                    return phase < symmetry ?
                    (phase / symmetry) :
                    (1.0 - ((phase - symmetry) / (1.0 - symmetry)))
                }
                
            case "saw":
                table = (0..<size).map { i in
                    let phase = Float(i) / Float(size)
                    return 1.0 - phase
                }
                
            case "square":
                let width = params["width"] ?? 0.5
                
                table = (0..<size).map { i in
                    let phase = Float(i) / Float(size)
                    return phase < width ? 0.0 : 1.0
                }
                
            default:
                // Default to sine
                table = (0..<size).map { i in
                    let phase = Float(i) / Float(size)
                    return (sin(phase * 2.0 * Float.pi) * 0.5) + 0.5
                }
            }
            
            // Apply additional processing if needed
            if let gain = params["gain"], gain != 1.0 {
                for i in 0..<table.count {
                    table[i] *= gain
                }
            }
            
            if let offset = params["offset"], offset != 0.0 {
                for i in 0..<table.count {
                    table[i] += offset
                }
            }
            
            // Cache the computed table
            calculationCache.set(cacheKey, table)
            
            return table
        }
    }
    
    /// Compatibility adapter to maintain the original SmartWaveformProcessor API
    public class SmartWaveformProcessor {
        private let waveformTables = Crvs.WaveformTables(tableSize: 8192)
        private let cache = Crvs.LRUCache<String, [Float]>(capacity: 100)
        private let ops = Crvs.Ops()
        
        public init() {}
        
        /// Generate samples using the enhanced wavetable implementation
        public func generateSamples(type: String, params: [String: Float], count: Int) -> [Float] {
            // Create cache key
            let cacheKey = "\(type)_\(count)_" + params.sorted(by: { $0.key < $1.key })
                .map { "\($0.key)_\($0.value)" }
                .joined(separator: "_")
            
            // Check cache first
            if let cachedResult = cache.get(cacheKey) {
                return cachedResult
            }
            
            // Generate waveform using our new implementation
            let samples = waveformTables.generateWavetable(type: type, params: params, size: count)
            
            // Cache the result
            cache.set(cacheKey, samples)
            
            return samples
        }
    }
}

// MARK: - Extension for Ops class

extension Crvs.Ops {
    
    /// Creates a memoized (cached) version of an operation with specified policy
    public func cached(_ op: @escaping Crvs.FloatOp,
                       precision: Float = 0.001,
                       policy: Crvs.CacheEvictionPolicy = .lru) -> Crvs.FloatOp {
        return Crvs.memoize(op, precision: precision, policy: policy)
    }
    
    /// Creates a batch-optimized version of an operation
    public func batchOptimized(_ op: @escaping Crvs.FloatOp) -> ([Float]) -> [Float] {
        return { positions in
            // Process in batches to optimize cache utilization
            let batchSize = 128
            var results = [Float](repeating: 0, count: positions.count)
            
            // Process each batch
            for startIndex in stride(from: 0, to: positions.count, by: batchSize) {
                let endIndex = Swift.min(startIndex + batchSize, positions.count)
                let batch = Array(positions[startIndex..<endIndex])
                
                // Use a local LRU cache for this batch
                let cache = Crvs.LRUCache<Float, Float>(capacity: batchSize)
                
                // Process each position in the batch
                for (i, pos) in batch.enumerated() {
                    // Check cache first
                    if let cachedValue = cache.get(pos) {
                        results[startIndex + i] = cachedValue
                        continue
                    }
                    
                    // Calculate and cache
                    let value = op(pos)
                    cache.set(pos, value)
                    results[startIndex + i] = value
                }
            }
            
            return results
        }
    }
    
    /// Creates a pre-computed version of a waveform with improved caching
    public func precomputed(_ op: @escaping Crvs.FloatOp, tableSize: Int = 4096) -> Crvs.FloatOp {
        // Generate lookup table
        var table = [Float](repeating: 0, count: tableSize)
        
        // Compute values in parallel
        let workQueue = DispatchQueue(label: "com.crvs.precomputed", attributes: .concurrent)
        let group = DispatchGroup()
        
        let chunkSize = 256
        for startIndex in stride(from: 0, to: tableSize, by: chunkSize) {
            let endIndex = Swift.min(startIndex + chunkSize, tableSize)
            
            workQueue.async(group: group) {
                for i in startIndex..<endIndex {
                    let pos = Float(i) / Float(tableSize)
                    table[i] = op(pos)
                }
            }
        }
        
        // Wait for all calculations to complete
        group.wait()
        
        // Return optimized lookup function
        return { pos in
            let wrappedPos = pos - floor(pos)
            let scaledPos = wrappedPos * Float(tableSize)
            let index1 = Int(scaledPos) % tableSize
            let index2 = (index1 + 1) % tableSize
            let fraction = scaledPos - Float(index1)
            
            return (table[index1] * (1.0 - fraction)) + (table[index2] * fraction)
        }
    }
    
    /// Precomputes a chain of operations into an optimized lookup table
    public func precomputeChain(_ ops: [Crvs.FloatOp], tableSize: Int = 4096) -> Crvs.FloatOp {
        // First, create a chained operation from the array of operations
        let chainedOp: Crvs.FloatOp = { pos in
            var result = pos
            for op in ops {
                result = op(result)
            }
            return result
        }
        
        // Then use the existing precomputed method to optimize it
        return precomputed(chainedOp, tableSize: tableSize)
    }
}
