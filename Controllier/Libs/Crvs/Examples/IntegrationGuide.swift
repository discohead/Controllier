import Foundation

/*
# Integration Guide for Crvs in iOS/macOS Apps

This guide outlines best practices for integrating the optimized Crvs
library into your iOS and macOS applications.
*/

// MARK: - Setup and Initialization

class CrvsSetupGuide {
    
    // MARK: - Initialization Patterns
    
    /// Recommended initialization pattern for apps
    static func setupForApp() {
        // 1. Detect platform capabilities
        let capabilities = PlatformCapabilityAnalyzer.detectCapabilities()
        
        // 2. Create the appropriate processor based on intended use
        let mainProcessor = PlatformOptimizedFactory.createOptimalProcessor()
        let audioProcessor = PlatformOptimizedFactory.createAudioOptimizedProcessor()
        let visualProcessor = PlatformOptimizedFactory.createVisualOptimizedProcessor()
        
        // 3. Initialize shared resources and caches
        let sharedResources = SharedCrvsResources.standard
        sharedResources.initialize(capabilities: capabilities)
        
        // 4. Set up memory management
        setupMemoryManagement()
        
        // 5. Register for app lifecycle notifications
        registerForLifecycleNotifications()
    }
    
    /// Setup memory management
    private static func setupMemoryManagement() {
        #if os(iOS) || os(tvOS)
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
        
        // Configure automatic cache purging
        SharedCrvsResources.standard.configureAutomaticCachePurging(
            minimumPurgeInterval: 30.0, // seconds
            thresholdPercentage: 0.8    // 80% memory usage triggers purge
        )
    }
    
    /// Register for app lifecycle notifications
    private static func registerForLifecycleNotifications() {
        #if os(iOS) || os(tvOS)
        // Background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        #elseif os(macOS)
        // Similar notifications for macOS
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        #endif
    }
    
    // MARK: - Lifecycle Handlers
    
    /// Handle memory warnings
    @objc private static func handleMemoryWarning() {
        // Clear caches and release non-essential resources
        SharedCrvsResources.standard.clearAllCaches()
    }
    
    /// Handle app entering background
    @objc private static func applicationDidEnterBackground() {
        // Reduce resource usage
        SharedCrvsResources.standard.reduceResourceUsage()
    }
    
    /// Handle app returning to foreground
    @objc private static func applicationWillEnterForeground() {
        // Restore optimal performance
        SharedCrvsResources.standard.restoreOptimalPerformance()
    }
    
    /// Handle app termination
    @objc private static func applicationWillTerminate() {
        // Clean up resources
        SharedCrvsResources.standard.cleanup()
    }
}

// MARK: - Shared Resources Management

/// Manages shared resources for Crvs library
public class SharedCrvsResources {
    
    /// Singleton instance
    public static let standard = SharedCrvsResources()
    
    /// Resource usage mode
    public enum ResourceMode {
        case minimal    // Lowest resource usage
        case normal     // Standard resource usage
        case maximum    // Maximum performance, higher resource usage
    }
    
    // Private properties
    private var isInitialized = false
    private var resourceMode: ResourceMode = .normal
    private var sampleCache: Crvs.LRUCache<String, [Float]>?
    private var processors: [String: WaveformProcessorProtocol] = [:]
    private var memoryMonitor: MemoryMonitor?
    
    // Non-singleton initialization
    private init() {}
    
    /// Initialize shared resources
    public func initialize(capabilities: PlatformCapabilityAnalyzer.PlatformCapabilities) {
        guard !isInitialized else { return }
        
        // Create cache sized appropriately for device memory
        let cacheSize = calculateOptimalCacheSize(memoryLimit: capabilities.memoryLimit)
        sampleCache = Crvs.LRUCache<String, [Float]>(capacity: cacheSize)
        
        // Initialize memory monitor
        memoryMonitor = MemoryMonitor(warningThreshold: 0.8, criticalThreshold: 0.9)
        
        isInitialized = true
    }
    
    /// Configure automatic cache purging
    public func configureAutomaticCachePurging(minimumPurgeInterval: TimeInterval, thresholdPercentage: Double) {
        guard let memoryMonitor = memoryMonitor else { return }
        
        memoryMonitor.configure(
            checkInterval: 10.0, // Check every 10 seconds
            minimumPurgeInterval: minimumPurgeInterval,
            warningThreshold: thresholdPercentage,
            criticalThreshold: thresholdPercentage + 0.1,
            onWarningCallback: { [weak self] in
                self?.purgeCaches(aggressive: false)
            },
            onCriticalCallback: { [weak self] in
                self?.purgeCaches(aggressive: true)
            }
        )
        
        memoryMonitor.startMonitoring()
    }
    
    /// Get a processor by type
    public func processor(for type: String) -> WaveformProcessorProtocol {
        if let processor = processors[type] {
            return processor
        }
        
        // Create a new processor if one doesn't exist
        let newProcessor: WaveformProcessorProtocol
        
        switch type {
        case "audio":
            newProcessor = PlatformOptimizedFactory.createAudioOptimizedProcessor()
        case "visual":
            newProcessor = PlatformOptimizedFactory.createVisualOptimizedProcessor()
        default:
            newProcessor = PlatformOptimizedFactory.createOptimalProcessor()
        }
        
        processors[type] = newProcessor
        return newProcessor
    }
    
    /// Clear all caches
    public func clearAllCaches() {
        sampleCache?.clear()
    }
    
    /// Purge caches based on current memory pressure
    public func purgeCaches(aggressive: Bool) {
        if aggressive {
            // Clear everything in high memory pressure
            clearAllCaches()
        } else {
            // Partial clear based on age/size in medium memory pressure
            // This would involve more sophisticated cache management
        }
    }
    
    /// Reduce resource usage when app is in background
    public func reduceResourceUsage() {
        resourceMode = .minimal
        
        // Release non-essential resources
        memoryMonitor?.pauseMonitoring()
        
        // Reduce cache size
        sampleCache?.resizeCapacity(newCapacity: 10)
    }
    
    /// Restore optimal performance when app is in foreground
    public func restoreOptimalPerformance() {
        resourceMode = .normal
        
        // Restore resources
        let capabilities = PlatformCapabilityAnalyzer.detectCapabilities()
        let cacheSize = calculateOptimalCacheSize(memoryLimit: capabilities.memoryLimit)
        sampleCache?.resizeCapacity(newCapacity: cacheSize)
        
        // Resume monitoring
        memoryMonitor?.startMonitoring()
    }
    
    /// Clean up resources before app termination
    public func cleanup() {
        memoryMonitor?.stopMonitoring()
        clearAllCaches()
        processors.removeAll()
    }
    
    /// Calculate optimal cache size based on available memory
    private func calculateOptimalCacheSize(memoryLimit: UInt64) -> Int {
        // Allocate approximately 10% of available memory for caching
        let cacheMemory = Double(memoryLimit) * 0.1
        
        // Estimate average sample array size (assume 10KB per sample array)
        let estimatedSampleSize = 10 * 1024
        
        // Calculate cache capacity
        let capacity = Int(cacheMemory / Double(estimatedSampleSize))
        
        // Ensure reasonable bounds
        return min(1000, max(20, capacity))
    }
}

// MARK: - Memory Monitor

/// Monitors memory usage and triggers callbacks at specified thresholds
public class MemoryMonitor {
    private var timer: Timer?
    private var lastPurgeTime: Date = Date()
    private var minimumPurgeInterval: TimeInterval = 30.0
    private var warningThreshold: Double
    private var criticalThreshold: Double
    private var onWarningCallback: (() -> Void)?
    private var onCriticalCallback: (() -> Void)?
    
    public init(warningThreshold: Double, criticalThreshold: Double) {
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
    }
    
    /// Configure memory monitoring
    public func configure(
        checkInterval: TimeInterval,
        minimumPurgeInterval: TimeInterval,
        warningThreshold: Double,
        criticalThreshold: Double,
        onWarningCallback: @escaping () -> Void,
        onCriticalCallback: @escaping () -> Void
    ) {
        self.minimumPurgeInterval = minimumPurgeInterval
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.onWarningCallback = onWarningCallback
        self.onCriticalCallback = onCriticalCallback
        
        // Update timer if running
        if timer != nil {
            stopMonitoring()
            startMonitoring(interval: checkInterval)
        }
    }
    
    /// Start memory monitoring
    public func startMonitoring(interval: TimeInterval = 10.0) {
        stopMonitoring()
        
        timer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(checkMemoryUsage),
            userInfo: nil,
            repeats: true
        )
    }
    
    /// Pause memory monitoring
    public func pauseMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Stop memory monitoring
    public func stopMonitoring() {
        pauseMonitoring()
    }
    
    /// Check current memory usage
    @objc private func checkMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        
        // Check if enough time has passed since last purge
        let now = Date()
        let timeSinceLastPurge = now.timeIntervalSince(lastPurgeTime)
        
        if timeSinceLastPurge >= minimumPurgeInterval {
            if memoryUsage >= criticalThreshold {
                // Critical threshold reached
                onCriticalCallback?()
                lastPurgeTime = now
            } else if memoryUsage >= warningThreshold {
                // Warning threshold reached
                onWarningCallback?()
                lastPurgeTime = now
            }
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
}

// MARK: - Extension for LRU Cache

extension Crvs.LRUCache {
    
    /// Resize the cache capacity
    public func resizeCapacity(newCapacity: Int) {
        // Implementation would resize the cache while preserving
        // as many items as possible
    }
}

// MARK: - Integration Examples

/*
# Common Integration Patterns

Here are examples of how to integrate Crvs in different application types:
*/

// MARK: - Audio Application Integration

class AudioAppIntegrationExample {
    
    func setupAudioEngine() {
        // 1. Initialize Crvs resources
        OfxCrvsSetupGuide.setupForApp()
        
        // 2. Get an audio-optimized processor
        let audioProcessor = SharedCrvsResources.standard.processor(for: "audio")
        
        // 3. Configure audio settings
        let sampleRate: Float = 44100.0
        let bufferSize = 1024
        
        // 4. Set up audio engine (using AVAudioEngine or similar)
        setupAudioEngine(sampleRate: sampleRate, bufferSize: bufferSize)
        
        // 5. Set up render callback
        setupRenderCallback { [weak self] (bufferPtr, numberOfFrames) in
            self?.renderAudio(to: bufferPtr, frameCount: numberOfFrames, processor: audioProcessor)
        }
    }
    
    func setupAudioEngine(sampleRate: Float, bufferSize: Int) {
        // Implementation would set up AVAudioEngine or similar
    }
    
    func setupRenderCallback(callback: @escaping (UnsafeMutablePointer<Float>, Int) -> Void) {
        // Implementation would set up audio callback
    }
    
    func renderAudio(to buffer: UnsafeMutablePointer<Float>, frameCount: Int, 
                    processor: WaveformProcessorProtocol) {
        // Generate waveforms for active voices
        let activeVoices = getActiveVoices()
        
        // Clear buffer
        memset(buffer, 0, frameCount * MemoryLayout<Float>.size)
        
        // Process each voice
        for voice in activeVoices {
            // Generate waveform for this voice
            let samples = processor.generateWaveform(
                type: voice.waveformType,
                params: [
                    "frequency": voice.frequency / 44100.0 * Float(frameCount),
                    "phase": voice.phase
                ],
                count: frameCount
            )
            
            // Mix into output buffer
            for i in 0..<frameCount {
                buffer[i] += samples[i] * voice.amplitude
            }
            
            // Update voice phase for next buffer
            voice.updatePhase(frameCount: frameCount)
        }
    }
    
    func getActiveVoices() -> [SynthVoice] {
        // Implementation would return active synthesis voices
        return []
    }
    
    class SynthVoice {
        var waveformType: String = "sine"
        var frequency: Float = 440.0
        var phase: Float = 0.0
        var amplitude: Float = 0.5
        
        func updatePhase(frameCount: Int) {
            // Update phase for next buffer
            let phaseIncrement = (frequency / 44100.0) * Float(frameCount)
            phase = (phase + phaseIncrement).truncatingRemainder(dividingBy: 1.0)
        }
    }
}

// MARK: - UI/Animation Integration

class UIAnimationIntegrationExample {
    
    func setupAnimationSystem() {
        // 1. Initialize Crvs resources
        OfxCrvsSetupGuide.setupForApp()
        
        // 2. Get a visual-optimized processor
        let visualProcessor = SharedCrvsResources.standard.processor(for: "visual")
        
        // 3. Create animation curves
        let curves = createAnimationCurves(processor: visualProcessor)
        
        // 4. Set up UI components
        setupUIComponents(with: curves)
    }
    
    func createAnimationCurves(processor: WaveformProcessorProtocol) -> [String: [Float]] {
        // Generate common animation curves
        let curves: [String: [String: Float]] = [
            "easeIn": ["type": "easeIn", "exponent": 2.5],
            "easeOut": ["type": "easeOut", "exponent": 2.5],
            "easeInOut": ["type": "easeInOut", "exponent": 2.5],
            "bounce": ["type": "bounce", "bounces": 3.0],
            "elastic": ["type": "elastic", "oscillations": 3.0, "damping": 0.7]
        ]
        
        // Generate 100 samples for each curve (enough for smooth animation)
        var curveData: [String: [Float]] = [:]
        
        for (name, params) in curves {
            curveData[name] = processor.generateWaveform(
                type: params["type"] ?? "easeInOut",
                params: params,
                count: 100
            )
        }
        
        return curveData
    }
    
    func setupUIComponents(with curves: [String: [Float]]) {
        // Implementation would set up UI components with animation curves
    }
    
    func animateView(view: UIView, curve: String, duration: TimeInterval, fromPosition: CGPoint, toPosition: CGPoint) {
        guard let curveData = getCurveData(for: curve) else {
            // Fall back to standard animation
            UIView.animate(withDuration: duration) {
                view.center = toPosition
            }
            return
        }
        
        // Create custom animation using curve data
        let startTime = CACurrentMediaTime()
        let displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink.add(to: .current, forMode: .common)
        
        // Store animation data (in a real implementation, use a proper animation system)
        let animationData = AnimationData(
            view: view,
            startTime: startTime,
            duration: duration,
            fromPosition: fromPosition,
            toPosition: toPosition,
            curveData: curveData,
            displayLink: displayLink
        )
        
        activeAnimations.append(animationData)
    }
    
    @objc func updateAnimation() {
        let currentTime = CACurrentMediaTime()
        
        // Update all active animations
        for (index, animation) in activeAnimations.enumerated().reversed() {
            let elapsed = currentTime - animation.startTime
            
            if elapsed >= animation.duration {
                // Animation complete
                animation.view.center = animation.toPosition
                animation.displayLink.invalidate()
                activeAnimations.remove(at: index)
            } else {
                // Animation in progress
                let progress = min(1.0, Float(elapsed / animation.duration))
                
                // Look up progress in curve data
                let curveIndex = Int(progress * Float(animation.curveData.count - 1))
                let curvedProgress = animation.curveData[curveIndex]
                
                // Interpolate position
                let newX = animation.fromPosition.x + CGFloat(curvedProgress) * (animation.toPosition.x - animation.fromPosition.x)
                let newY = animation.fromPosition.y + CGFloat(curvedProgress) * (animation.toPosition.y - animation.fromPosition.y)
                
                animation.view.center = CGPoint(x: newX, y: newY)
            }
        }
    }
    
    func getCurveData(for curve: String) -> [Float]? {
        // Implementation would return curve data
        return nil
    }
    
    // Active animations
    var activeAnimations: [AnimationData] = []
    
    // Animation data structure
    struct AnimationData {
        let view: UIView
        let startTime: TimeInterval
        let duration: TimeInterval
        let fromPosition: CGPoint
        let toPosition: CGPoint
        let curveData: [Float]
        let displayLink: CADisplayLink
    }
}

// MARK: - Data Visualization Integration

class DataVisualizationIntegrationExample {
    
    func setupVisualization() {
        // 1. Initialize Crvs resources
        OfxCrvsSetupGuide.setupForApp()
        
        // 2. Get a visual-optimized processor
        let visualProcessor = SharedCrvsResources.standard.processor(for: "visual")
        
        // 3. Set up visualization
        setupDataVisualization(processor: visualProcessor)
    }
    
    func setupDataVisualization(processor: WaveformProcessorProtocol) {
        // Implementation would set up data visualization
    }
    
    func generateSmoothCurve(fromData data: [Float], smoothness: Float = 0.5) -> [CGPoint] {
        // Get processor
        let processor = SharedCrvsResources.standard.processor(for: "visual")
        
        // Normalize data to 0-1 range
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let range = maxValue - minValue
        
        let normalizedData = data.map { ($0 - minValue) / range }
        
        // Create breakpoints for the data
        var breakpoints: [String: Float] = [:]
        for (index, value) in normalizedData.enumerated() {
            breakpoints["point\(index)"] = value
        }
        
        // Generate smoothed curve with many points
        let pointCount = 200
        let smoothedData = processor.generateWaveform(
            type: "smooth",
            params: [
                "smoothness": smoothness,
                "dataPoints": Float(data.count)
            ],
            count: pointCount
        )
        
        // Convert to CGPoints
        var points = [CGPoint]()
        for i in 0..<pointCount {
            let x = CGFloat(i) / CGFloat(pointCount - 1)
            let normalizedY = smoothedData[i]
            let y = normalizedY * CGFloat(range) + CGFloat(minValue)
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
}
