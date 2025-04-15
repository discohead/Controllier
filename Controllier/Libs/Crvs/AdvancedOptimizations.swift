import Foundation
import Dispatch
import os.log

#if canImport(UIKit)
import UIKit
#endif

/// Advanced memory management and threading optimizations for Crvs
public class AdvancedOptimizations {
    
    // MARK: - Memory Pool Management
    
    /// Thread-safe memory pool for reusing sample buffers
    public class SampleBufferPool {
        /// Class to manage buffer lifecycle
        private class BufferStorage {
            let buffer: [Float]
            let capacity: Int
            
            init(capacity: Int) {
                self.capacity = capacity
                self.buffer = [Float](repeating: 0.0, count: capacity)
            }
        }
        
        private let lock = NSLock()
        private var pools: [Int: [BufferStorage]] = [:]
        private let maxBuffersPerSize = 10
        private let logger = Logger(subsystem: "com.crvs.advanced", category: "BufferPool")
        
        /// Get a buffer of the specified size from the pool
        public func getBuffer(size: Int) -> [Float] {
            lock.lock()
            defer { lock.unlock() }
            
            // Check if we have a cached buffer
            if var availableBuffers = pools[size], !availableBuffers.isEmpty {
                let bufferStorage = availableBuffers.removeLast()
                pools[size] = availableBuffers
                
                return bufferStorage.buffer
            }
            
            // Create a new buffer if none available
            logger.debug("Creating new buffer of size \(size)")
            return [Float](repeating: 0.0, count: size)
        }
        
        /// Return a buffer to the pool for future reuse
        public func returnBuffer(_ buffer: [Float]) {
            let size = buffer.count
            
            lock.lock()
            defer { lock.unlock() }
            
            // Create entry for this size if it doesn't exist
            var buffers = pools[size] ?? []
            
            // Add buffer to pool if we're under the limit
            if buffers.count < maxBuffersPerSize {
                buffers.append(BufferStorage(capacity: size))
                pools[size] = buffers
                logger.debug("Returned buffer of size \(size) to pool. Pool now has \(buffers.count) buffers of this size.")
            }
        }
        
        /// Clean up the pool
        public func drain() {
            lock.lock()
            defer { lock.unlock() }
            
            // Clear all buffer references
            pools.removeAll()
            logger.debug("Buffer pool drained")
        }
    }
    
    // MARK: - Thread-Safe Waveform Generator
    
    /// Thread-safe waveform processor that uses a thread pool for parallel processing
    @available(iOS 15.0, macOS 12.0, *)
    public actor ThreadedWaveformProcessor {
        private let ops = Crvs.Ops()
        private let maxConcurrentTasks: Int
        private let logger = Logger(subsystem: "com.crvs.advanced", category: "WaveformProcessor")
        
        public init(maxConcurrentTasks: Int = ProcessInfo.processInfo.activeProcessorCount) {
            self.maxConcurrentTasks = maxConcurrentTasks
        }
        
        /// Generate multiple waveforms in parallel
        public func generateWaveforms(types: [String],
                                      params: [[String: Float]],
                                      count: Int) async -> [[Float]] {
            // Create tasks array
            var tasks: [Task<[Float], Error>] = []
            
            // Process each waveform in parallel
            for (index, type) in types.enumerated() {
                let waveformParams = index < params.count ? params[index] : [:]
                
                let task = Task<[Float], Error> {
                    try await generateWaveform(type: type, params: waveformParams, count: count)
                }
                tasks.append(task)
                
                // Limit concurrent tasks if needed
                if tasks.count >= maxConcurrentTasks {
                    // Wait for a task to complete before continuing
                    do {
                        _ = try await tasks.first?.value
                        tasks.removeFirst()
                    } catch {
                        logger.error("Error generating waveform: \(error.localizedDescription)")
                    }
                }
            }
            
            // Collect all results
            var results: [[Float]] = []
            for task in tasks {
                do {
                    let waveform = try await task.value
                    results.append(waveform)
                } catch {
                    logger.error("Error collecting waveform result: \(error.localizedDescription)")
                    results.append([Float](repeating: 0, count: count))
                }
            }
            
            return results
        }
        
        /// Generate a single waveform
        private func generateWaveform(type: String, params: [String: Float], count: Int) async throws -> [Float] {
            var result = [Float](repeating: 0, count: count)
            
            // Create operation based on type
            let op: Crvs.FloatOp
            
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
                
            default:
                op = ops.sine()
            }
            
            // Apply frequency and phase modulation if specified
            let frequency = params["frequency"] ?? 1.0
            let phase = params["phase"] ?? 0.0
            
            let modulatedOp: Crvs.FloatOp
            if frequency != 1.0 || phase != 0.0 {
                modulatedOp = { pos in
                    let modPos = (pos * frequency) + phase
                    return op(modPos.truncatingRemainder(dividingBy: 1.0))
                }
            } else {
                modulatedOp = op
            }
            
            // Generate samples with support for cooperative cancellation
            for i in 0..<count {
                if Task.isCancelled { break }
                
                let pos = Float(i) / Float(count)
                result[i] = modulatedOp(pos)
                
                // Yield periodically to prevent blocking the thread for too long
                if i % 1000 == 0 { await Task.yield() }
            }
            
            return result
        }
    }
    
    // MARK: - Triple Buffer Implementation
    
    /// Thread-safe triple buffering system for real-time audio processing
    public class TripleBuffer<T> {
        private var buffers: [T]
        private var writeIndex: Int = 0
        private var readIndex: Int = 0
        private let lock = NSLock()
        
        public init(bufferFactory: () -> T, bufferCount: Int = 3) {
            // Create the initial buffers
            var initialBuffers: [T] = []
            for _ in 0..<bufferCount {
                initialBuffers.append(bufferFactory())
            }
            self.buffers = initialBuffers
        }
        
        /// Get a writable buffer
        public func getWriteBuffer() -> T {
            lock.lock()
            defer { lock.unlock() }
            
            return buffers[writeIndex]
        }
        
        /// Mark the current write buffer as ready and advance to the next one
        public func advanceWriteBuffer() {
            lock.lock()
            defer { lock.unlock() }
            
            // Advance to next buffer in circular fashion
            writeIndex = (writeIndex + 1) % buffers.count
        }
        
        /// Get the current read buffer
        public func getReadBuffer() -> T {
            lock.lock()
            defer { lock.unlock() }
            
            // Use a buffer that's not currently being written to
            let index = (writeIndex + 1) % buffers.count
            readIndex = index
            return buffers[index]
        }
    }
    
    // MARK: - Automatic Memory Management
    
    /// Automatic memory management for waveform operations
    public class MemoryManager {
        private let logger = Logger(subsystem: "com.crvs.advanced", category: "MemoryManager")
        private let memoryWarningThreshold: Double = 0.8 // 80% of available memory
        private var lastCacheClear: Date = Date()
        private let minimumCacheClearInterval: TimeInterval = 5.0 // seconds
        private let lock = NSLock()
        
        // Reference to caches that can be cleared
        private weak var sampleCache: AnyObject?
        private weak var paramCache: AnyObject?
        
        public init(sampleCache: AnyObject? = nil, paramCache: AnyObject? = nil) {
            self.sampleCache = sampleCache
            self.paramCache = paramCache
            
            // Register for memory warning notifications on iOS
#if os(iOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleMemoryWarning),
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
#endif
        }
        
        /// Check memory usage and clear caches if needed
        public func checkMemoryUsage() {
            // Get memory usage
            let memoryUsage = getMemoryUsage()
            
            // Log memory usage
            logger.debug("Memory usage: \(memoryUsage * 100, privacy: .public)%")
            
            // Check if we need to clear caches
            if memoryUsage > memoryWarningThreshold {
                clearCachesIfNeeded()
            }
        }
        
        /// Handle memory warning notification
        @objc private func handleMemoryWarning() {
            logger.warning("Memory warning received")
            clearCaches()
        }
        
        /// Clear caches if enough time has passed since last clear
        private func clearCachesIfNeeded() {
            lock.lock()
            defer { lock.unlock() }
            
            let now = Date()
            if now.timeIntervalSince(lastCacheClear) > minimumCacheClearInterval {
                clearCachesInternal()
                lastCacheClear = now
            }
        }
        
        /// Clear all caches immediately
        public func clearCaches() {
            lock.lock()
            defer { lock.unlock() }
            
            clearCachesInternal()
            lastCacheClear = Date()
        }
        
        /// Internal implementation of cache clearing
        private func clearCachesInternal() {
            logger.info("Clearing caches")
            
            // Call clear methods on caches if available
            if let cache = sampleCache as? CacheClearable {
                cache.clear()
            }
            
            if let cache = paramCache as? CacheClearable {
                cache.clear()
            }
        }
        
        /// Get current memory usage as a percentage
        private func getMemoryUsage() -> Double {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
            
            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                              task_flavor_t(MACH_TASK_BASIC_INFO),
                              $0,
                              &count)
                }
            }
            
            if kerr == KERN_SUCCESS {
                let usedMemory = Double(info.resident_size)
                let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)
                return usedMemory / physicalMemory
            }
            
            return 0.0
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // MARK: - High-Priority Audio Thread Safety
    
    /// Thread-safe buffer for real-time audio processing
    @available(iOS 15.0, macOS 12.0, *)
    public actor AudioBufferProcessor {
        private var buffer: [Float]
        private let underrunValue: Float
        private var writePosition: Int = 0
        private var readPosition: Int = 0
        
        public init(size: Int, underrunValue: Float = 0.0) {
            self.buffer = [Float](repeating: underrunValue, count: size)
            self.underrunValue = underrunValue
        }
        
        /// Write samples to the buffer (non-audio thread)
        public func write(_ samples: [Float]) {
            let count = min(samples.count, buffer.count)
            
            // Copy samples to the buffer at the current write position
            for i in 0..<count {
                let bufferIndex = (writePosition + i) % buffer.count
                buffer[bufferIndex] = samples[i]
            }
            
            // Update write position
            writePosition = (writePosition + count) % buffer.count
        }
        
        /// Read samples from the buffer (audio thread)
        public func read(count: Int) -> [Float] {
            var result = [Float](repeating: underrunValue, count: count)
            
            // Calculate available samples
            let available = (writePosition - readPosition + buffer.count) % buffer.count
            
            if available >= count {
                // We have enough samples
                for i in 0..<count {
                    let bufferIndex = (readPosition + i) % buffer.count
                    result[i] = buffer[bufferIndex]
                }
                
                // Update read position
                readPosition = (readPosition + count) % buffer.count
            }
            
            return result
        }
        
        /// Reset the buffer
        public func reset() {
            writePosition = 0
            readPosition = 0
            buffer = [Float](repeating: underrunValue, count: buffer.count)
        }
        
        /// Get the number of available samples
        public func availableSamples() -> Int {
            return (writePosition - readPosition + buffer.count) % buffer.count
        }
    }
}

// MARK: - Supporting Protocols and Extensions

/// Protocol for objects that can clear their caches
public protocol CacheClearable {
    func clear()
}

/// Extension for the legacy compatibility
public class AudioThreadSafeBufferClassic {
    private var buffer: [Float]
    private let underrunValue: Float
    private let size: Int
    private let lock = NSLock()
    
    private var writePosition: Int = 0
    private var readPosition: Int = 0
    
    public init(size: Int, underrunValue: Float = 0.0) {
        self.size = size
        self.underrunValue = underrunValue
        self.buffer = [Float](repeating: underrunValue, count: size)
    }
    
    /// Write samples to the buffer (non-audio thread)
    public func write(_ samples: [Float]) {
        let count = min(samples.count, size)
        
        lock.lock()
        
        // Copy samples to the buffer at the current write position
        for i in 0..<count {
            let bufferIndex = (writePosition + i) % size
            buffer[bufferIndex] = samples[i]
        }
        
        // Update write position
        writePosition = (writePosition + count) % size
        
        lock.unlock()
    }
    
    /// Read samples from the buffer (audio thread)
    public func read(count: Int) -> [Float] {
        var result = [Float](repeating: underrunValue, count: count)
        
        lock.lock()
        
        // Calculate available samples
        let available = (writePosition - readPosition + size) % size
        
        if available >= count {
            // We have enough samples
            for i in 0..<count {
                let bufferIndex = (readPosition + i) % size
                result[i] = buffer[bufferIndex]
            }
            
            // Update read position
            readPosition = (readPosition + count) % size
        }
        
        lock.unlock()
        
        return result
    }
}
