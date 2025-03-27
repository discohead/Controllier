import Foundation

extension Crvs {
    
    // MARK: - Memoization Utilities
    
    /// Generic memoization wrapper for FloatOp functions
    public static func memoize(_ op: @escaping FloatOp, precision: Float = 0.001, cacheSize: Int = 1000) -> FloatOp {
        // Create thread-safe cache
        let cache = LRUCache<Int, Float>(capacity: cacheSize)
        
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
    
    /// Thread-safe LRU cache implementation
    public class LRUCache<Key: Hashable, Value> {
        private let capacity: Int
        private var cache = [Key: Value]()
        private var usageOrder = [Key]()
        private let lock = NSLock()
        
        public init(capacity: Int) {
            self.capacity = capacity
        }
        
        public func get(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            
            guard let value = cache[key] else {
                return nil
            }
            
            // Move key to most recently used
            if let index = usageOrder.firstIndex(of: key) {
                usageOrder.remove(at: index)
                usageOrder.append(key)
            }
            
            return value
        }
        
        public func set(_ key: Key, _ value: Value) {
            lock.lock()
            defer { lock.unlock() }
            
            // If key exists, update usage order
            if cache[key] != nil {
                if let index = usageOrder.firstIndex(of: key) {
                    usageOrder.remove(at: index)
                }
            } 
            // If cache is at capacity, remove least recently used
            else if cache.count >= capacity, let lruKey = usageOrder.first {
                cache.removeValue(forKey: lruKey)
                usageOrder.removeFirst()
            }
            
            // Add/update value and mark as most recently used
            cache[key] = value
            usageOrder.append(key)
        }
        
        public func clear() {
            lock.lock()
            defer { lock.unlock() }
            
            cache.removeAll()
            usageOrder.removeAll()
        }
    }
    
    // MARK: - Precomputed Lookup Tables
    
    /// Precomputed lookup tables for common waveforms
    public class WaveformTables {
        private let sineTable: [Float]
        private let triangleTable: [Float]
        private let sawTable: [Float]
        private let tableSize: Int
        
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
            let wrappedPhase = phase - floor(phase)
            let scaledPos = wrappedPhase * Float(tableSize)
            let index1 = Int(scaledPos) % tableSize
            let index2 = (index1 + 1) % tableSize
            let fraction = scaledPos - Float(index1)
            
            return (sineTable[index1] * (1.0 - fraction)) + (sineTable[index2] * fraction)
        }
        
        /// Lookup triangle value with interpolation
        public func lookupTriangle(_ phase: Float) -> Float {
            let wrappedPhase = phase - floor(phase)
            let scaledPos = wrappedPhase * Float(tableSize)
            let index1 = Int(scaledPos) % tableSize
            let index2 = (index1 + 1) % tableSize
            let fraction = scaledPos - Float(index1)
            
            return (triangleTable[index1] * (1.0 - fraction)) + (triangleTable[index2] * fraction)
        }
        
        /// Lookup saw value with interpolation
        public func lookupSaw(_ phase: Float) -> Float {
            let wrappedPhase = phase - floor(phase)
            let scaledPos = wrappedPhase * Float(tableSize)
            let index1 = Int(scaledPos) % tableSize
            let index2 = (index1 + 1) % tableSize
            let fraction = scaledPos - Float(index1)
            
            return (sawTable[index1] * (1.0 - fraction)) + (sawTable[index2] * fraction)
        }
    }
    
    // MARK: - Smart Parameter Caching
    
    /// Optimized waveform processor with parameter caching
    public class SmartWaveformProcessor {
        private let ops = Ops()
        private let tables = WaveformTables()
        private var parameterCache = [String: FloatOp]()
        private var sampleCache = LRUCache<String, [Float]>(capacity: 50)
        private let lock = NSLock()
        
        /// Generate waveform samples with smart caching
        public func generateSamples(type: String, 
                                   params: [String: Float], 
                                   count: Int) -> [Float] {
            
            // Create cache key
            let cacheKey = createCacheKey(type: type, params: params, count: count)
            
            // Check sample cache
            if let cachedSamples = sampleCache.get(cacheKey) {
                return cachedSamples
            }
            
            // Generate samples
            var samples: [Float]
            
            // Use lookup tables for basic waveforms when possible
            if count < 10000 {
                samples = [Float](repeating: 0, count: count)
                
                switch type {
                case "sine":
                    let frequency = params["frequency"] ?? 1.0
                    let phase = params["phase"] ?? 0.0
                    
                    for i in 0..<count {
                        let pos = Float(i) / Float(count)
                        let adjustedPhase = (pos * frequency) + phase
                        samples[i] = tables.lookupSine(adjustedPhase)
                    }
                    
                case "triangle":
                    let frequency = params["frequency"] ?? 1.0
                    let phase = params["phase"] ?? 0.0
                    
                    for i in 0..<count {
                        let pos = Float(i) / Float(count)
                        let adjustedPhase = (pos * frequency) + phase
                        samples[i] = tables.lookupTriangle(adjustedPhase)
                    }
                    
                case "saw":
                    let frequency = params["frequency"] ?? 1.0
                    let phase = params["phase"] ?? 0.0
                    
                    for i in 0..<count {
                        let pos = Float(i) / Float(count)
                        let adjustedPhase = (pos * frequency) + phase
                        samples[i] = tables.lookupSaw(adjustedPhase)
                    }
                    
                default:
                    // For other waveforms, use cached FloatOp
                    let op = getOrCreateOp(type: type, params: params)
                    
                    for i in 0..<count {
                        let pos = Float(i) / Float(count)
                        samples[i] = op(pos)
                    }
                }
            } else {
                // For large sample counts, use cached FloatOp
                let op = getOrCreateOp(type: type, params: params)
                
                samples = [Float](repeating: 0, count: count)
                for i in 0..<count {
                    let pos = Float(i) / Float(count)
                    samples[i] = op(pos)
                }
            }
            
            // Apply global processing if needed
            if let gain = params["gain"], gain != 1.0 {
                for i in 0..<count {
                    samples[i] *= gain
                }
            }
            
            if let offset = params["offset"], offset != 0.0 {
                for i in 0..<count {
                    samples[i] += offset
                }
            }
            
            // Cache the result
            sampleCache.set(cacheKey, samples)
            
            return samples
        }
        
        /// Get or create FloatOp for the specified waveform type and parameters
        private func getOrCreateOp(type: String, params: [String: Float]) -> FloatOp {
            let cacheKey = createCacheKey(type: type, params: params, count: 0)
            
            lock.lock()
            defer { lock.unlock() }
            
            // Check if we already have this op
            if let cachedOp = parameterCache[cacheKey] {
                return cachedOp
            }
            
            // Create new op based on type
            var op: FloatOp
            
            switch type {
            case "sine":
                let feedback = params["feedback"] ?? 0.0
                op = ops.sine(feedback)
                
            case "triangle":
                let symmetry = params["symmetry"] ?? 0.5
                op = ops.tri(symmetry)
                
            case "saw":
                op = ops.saw()
                
            case "square":
                let width = params["width"] ?? 0.5
                op = ops.pulse(width)
                
            case "easeIn":
                let exponent = params["exponent"] ?? 2.0
                op = ops.easeIn(exponent)
                
            case "easeOut":
                let exponent = params["exponent"] ?? 2.0
                op = ops.easeOut(exponent)
                
            case "easeInOut":
                let exponent = params["exponent"] ?? 2.0
                op = ops.easeInOut(exponent)
                
            default:
                op = ops.sine()
            }
            
            // Apply frequency/phase modifications if needed
            if let frequency = params["frequency"], frequency != 1.0 {
                op = { pos in
                    op(fmod(pos * frequency, 1.0))
                }
            }
            
            if let phase = params["phase"], phase != 0.0 {
                op = ops.phase(op, phase)
            }
            
            // Cache the operation
            parameterCache[cacheKey] = op
            
            return op
        }
        
        /// Create a cache key for the specified parameters
        private func createCacheKey(type: String, params: [String: Float], count: Int) -> String {
            var key = "\(type)_\(count)"
            
            for (paramName, paramValue) in params.sorted(by: { $0.key < $1.key }) {
                key += "_\(paramName)_\(String(format: "%.4f", paramValue))"
            }
            
            return key
        }
        
        /// Clear all caches
        public func clearCaches() {
            lock.lock()
            defer { lock.unlock() }
            
            parameterCache.removeAll()
            sampleCache.clear()
        }
    }
}

// MARK: - Extension for Ops class

extension Crvs.Ops {
    
    /// Creates a memoized (cached) version of an operation
    public func cached(_ op: @escaping Crvs.FloatOp, precision: Float = 0.001) -> Crvs.FloatOp {
        Crvs.memoize(op, precision: precision)
    }
    
    /// Creates a pre-computed version of a waveform
    public func precomputed(_ op: Crvs.FloatOp, tableSize: Int = 4096) -> Crvs.FloatOp {
        // Generate lookup table
        var table = [Float](repeating: 0, count: tableSize)
        for i in 0..<tableSize {
            let pos = Float(i) / Float(tableSize)
            table[i] = op(pos)
        }
        
        // Return lookup function
        return { pos in
            let wrappedPos = pos - floor(pos)
            let scaledPos = wrappedPos * Float(tableSize)
            let index1 = Int(scaledPos) % tableSize
            let index2 = (index1 + 1) % tableSize
            let fraction = scaledPos - Float(index1)
            
            return (table[index1] * (1.0 - fraction)) + (table[index2] * fraction)
        }
    }
    
    /// Creates a precomputed version of a computationally expensive chain of operations
    public func precomputeChain(_ ops: [Crvs.FloatOp], tableSize: Int = 4096) -> Crvs.FloatOp {
        // Create the chain operation
        let chainOp = chain(ops)
        
        // Precompute the result
        return precomputed(chainOp, tableSize: tableSize)
    }
}
