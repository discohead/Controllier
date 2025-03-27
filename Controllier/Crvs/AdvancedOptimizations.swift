import Foundation
import Dispatch
import os.log

#if canImport(UIKit)
import UIKit
#endif


/// Advanced memory management and threading optimizations for Crvs
public class AdvancedOptimizations {
    
    // MARK: - Memory Pool Management
    
    /// Memory pool for reusing sample buffers
    public class SampleBufferPool {
        private let lock = NSLock()
        private var pools: [Int: [UnsafeMutableBufferPointer<Float>]] = [:]
        private let maxBuffersPerSize = 10
        
        /// Get a buffer from the pool or create a new one
        public func getBuffer(size: Int) -> UnsafeMutableBufferPointer<Float> {
            lock.lock()
            defer { lock.unlock() }
            
            // Check if we have a cached buffer
            if var availableBuffers = pools[size], !availableBuffers.isEmpty {
                let buffer = availableBuffers.removeLast()
                pools[size] = availableBuffers
                
                // Zero the memory before returning
                buffer.initialize(repeating: 0.0)
                return buffer
            }
            
            // Create a new buffer if none available
            let pointer = UnsafeMutableBufferPointer<Float>.allocate(capacity: size)
            pointer.initialize(repeating: 0.0)
            return pointer
        }
        
        /// Return a buffer to the pool
        public func returnBuffer(_ buffer: UnsafeMutableBufferPointer<Float>) {
            let size = buffer.count
            
            lock.lock()
            defer { lock.unlock() }
            
            // Create entry for this size if it doesn't exist
            var buffers = pools[size] ?? []
            
            // Add buffer to pool if we're under the limit
            if buffers.count < maxBuffersPerSize {
                buffers.append(buffer)
                pools[size] = buffers
            } else {
                // Too many in the pool, just deallocate
                buffer.deallocate()
            }
        }
        
        /// Clean up the pool
        public func drain() {
            lock.lock()
            defer { lock.unlock() }
            
            // Deallocate all buffers
            for (_, buffers) in pools {
                for buffer in buffers {
                    buffer.deallocate()
                }
            }
            
            pools.removeAll()
        }
        
        deinit {
            drain()
        }
    }
    
    // MARK: - Thread-Safe Waveform Generator
    
    /// Thread-safe waveform processor that uses a thread pool for parallel processing
    public class ThreadedWaveformProcessor {
        private let ops = Crvs.Ops()
        private let bufferPool = SampleBufferPool()
        private let processingQueue: DispatchQueue
        private let maxConcurrentTasks: Int
        
        public init(maxConcurrentTasks: Int = ProcessInfo.processInfo.activeProcessorCount) {
            self.maxConcurrentTasks = maxConcurrentTasks
            self.processingQueue = DispatchQueue(label: "com.Crvs.processing", 
                                               qos: .userInitiated, 
                                               attributes: .concurrent)
        }
        
        /// Generate multiple waveforms in parallel
        public func generateWaveforms(types: [String], 
                                    params: [[String: Float]], 
                                    count: Int,
                                    completion: @escaping ([[Float]]) -> Void) {
            
            let group = DispatchGroup()
            let resultLock = NSLock()
            var results: [Int: [Float]] = [:]
            
            // Create a semaphore to limit concurrent tasks
            let semaphore = DispatchSemaphore(value: maxConcurrentTasks)
            
            // Process each waveform in parallel
            for (index, type) in types.enumerated() {
                group.enter()
                
                // Wait for a slot to become available
                semaphore.wait()
                
                processingQueue.async {
                    let waveformParams = index < params.count ? params[index] : [:]
                    
                    // Get a buffer from the pool
                    let buffer = self.bufferPool.getBuffer(size: count)
                    
                    // Generate the waveform
                    self.fillBuffer(buffer: buffer, type: type, params: waveformParams)
                    
                    // Copy to a regular array
                    let result = Array(buffer)
                    
                    // Return buffer to the pool
                    self.bufferPool.returnBuffer(buffer)
                    
                    // Store the result
                    resultLock.lock()
                    results[index] = result
                    resultLock.unlock()
                    
                    // Signal that a slot is available
                    semaphore.signal()
                    group.leave()
                }
            }
            
            // Notify when all waveforms are generated
            group.notify(queue: .main) {
                // Assemble results in the correct order
                var orderedResults: [[Float]] = Array(repeating: [], count: types.count)
                
                for (index, result) in results {
                    orderedResults[index] = result
                }
                
                completion(orderedResults)
            }
        }
        
        /// Fill a buffer with waveform data
        private func fillBuffer(buffer: UnsafeMutableBufferPointer<Float>, 
                               type: String, 
                               params: [String: Float]) {
            
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
            
            // Generate samples directly into the buffer
            let count = buffer.count
            for i in 0..<count {
                let pos = Float(i) / Float(count)
                buffer[i] = modulatedOp(pos)
            }
        }
    }
    
    // MARK: - Lock-Free Processing
    
    /// Lock-free sample processor for high-performance scenarios
    public class LockFreeProcessor {
        private let bufferPool = SampleBufferPool()
        private var processingBuffers: [UnsafeMutableBufferPointer<Float>] = []
        private var currentBufferIndex: UnsafeMutablePointer<Int32>
        
        public init(bufferCount: Int = 3, bufferSize: Int = 4096) {
            // Allocate atomic counter for buffer index
            currentBufferIndex = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
            currentBufferIndex.initialize(to: 0)
            
            // Allocate processing buffers
            for _ in 0..<bufferCount {
                let buffer = bufferPool.getBuffer(size: bufferSize)
                processingBuffers.append(buffer)
            }
        }
        
        /// Process samples with a lock-free triple buffer approach
        public func processSamples(_ sampleBlock: (UnsafeMutableBufferPointer<Float>) -> Void) -> UnsafeBufferPointer<Float> {
            // Get current buffer index atomically
            let currentIndex = OSAtomicIncrement32Barrier(currentBufferIndex) % Int32(processingBuffers.count)
            let buffer = processingBuffers[Int(currentIndex)]
            
            // Process samples into the buffer
            sampleBlock(buffer)
            
            // Return read-only view of the buffer
            return UnsafeBufferPointer(buffer)
        }
        
        /// Reset all buffers to zero
        public func resetBuffers() {
            for buffer in processingBuffers {
                buffer.initialize(repeating: 0.0)
            }
        }
        
        deinit {
            // Clean up all buffers
            for buffer in processingBuffers {
                bufferPool.returnBuffer(buffer)
            }
            
            // Deallocate atomic counter
            currentBufferIndex.deallocate()
        }
    }
    
    // MARK: - Automatic Memory Management
    
    /// Automatic memory management for waveform operations
    public class AutomaticMemoryManager {
        private let memoryLogger = OSLog(subsystem: "com.Crvs", category: "MemoryManager")
        private let memoryWarningThreshold: Double = 0.8 // 80% of available memory
        private var lastCacheClear: Date = Date()
        private let minimumCacheClearInterval: TimeInterval = 5.0 // seconds
        
        // Reference to caches that can be cleared
        private let sampleCache: Crvs.LRUCache<String, [Float]>
        private let paramCache: [String: Any]
        
        public init(sampleCache: Crvs.LRUCache<String, [Float]>, paramCache: [String: Any]) {
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
            os_log("Memory usage: %.2f%%", log: memoryLogger, type: .debug, memoryUsage * 100)
            
            // Check if we need to clear caches
            if memoryUsage > memoryWarningThreshold {
                clearCachesIfNeeded()
            }
        }
        
        /// Handle memory warning notification
        @objc private func handleMemoryWarning() {
            os_log("Memory warning received", log: memoryLogger, type: .error)
            clearCaches()
        }
        
        /// Clear caches if enough time has passed since last clear
        private func clearCachesIfNeeded() {
            let now = Date()
            if now.timeIntervalSince(lastCacheClear) > minimumCacheClearInterval {
                clearCaches()
            }
        }
        
        /// Clear all caches
        private func clearCaches() {
            os_log("Clearing caches", log: memoryLogger, type: .info)
            
            // Clear sample cache
            sampleCache.clear()
            
            // Record the time
            lastCacheClear = Date()
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
    public class AudioThreadSafeBuffer {
        private let buffer: UnsafeMutablePointer<Float>
        private let size: Int
        private let underrunValue: Float
        
        private var writeIndex: UnsafeMutablePointer<Int32>
        private var readIndex: UnsafeMutablePointer<Int32>
        
        public init(size: Int, underrunValue: Float = 0.0) {
            self.size = size
            self.underrunValue = underrunValue
            
            // Allocate circular buffer
            buffer = UnsafeMutablePointer<Float>.allocate(capacity: size)
            buffer.initialize(repeating: underrunValue, count: size)
            
            // Allocate atomic indices
            writeIndex = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
            readIndex = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
            writeIndex.initialize(to: 0)
            readIndex.initialize(to: 0)
        }
        
        /// Write samples to the buffer (non-audio thread)
        public func write(_ samples: [Float]) {
            let count = min(samples.count, size)
            
            // Get current write index atomically
            let writePos = Int(OSAtomicAdd32Barrier(0, writeIndex))
            
            for i in 0..<count {
                let bufferIndex = (writePos + i) % size
                buffer[bufferIndex] = samples[i]
            }
            
            // Update write index atomically
            OSAtomicAdd32Barrier(Int32(count), writeIndex)
        }
        
        /// Read samples from the buffer (audio thread)
        public func read(into destination: UnsafeMutablePointer<Float>, count: Int) {
            // Get indices atomically
            let readPos = Int(OSAtomicAdd32Barrier(0, readIndex))
            let writePos = Int(OSAtomicAdd32Barrier(0, writeIndex))
            
            // Calculate available samples
            let available = (writePos - readPos + size) % size
            
            if available >= count {
                // We have enough samples
                for i in 0..<count {
                    let bufferIndex = (readPos + i) % size
                    destination[i] = buffer[bufferIndex]
                }
                
                // Update read index atomically
                OSAtomicAdd32Barrier(Int32(count), readIndex)
            } else {
                // Underrun - not enough samples available
                for i in 0..<count {
                    destination[i] = underrunValue
                }
            }
        }
        
        deinit {
            buffer.deallocate()
            writeIndex.deallocate()
            readIndex.deallocate()
        }
    }
}
