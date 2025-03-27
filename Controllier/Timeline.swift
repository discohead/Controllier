//
//  Timeline.swift
//  Controllier
//
//  Created by Jared McFarland on 3/27/25.
//

import Foundation

/// A simple global state container. You can expand this with any properties you need.
public class GlobalState {
    public var someParameter: Double = 0.0
    // Add additional state properties here.
    
    public init() { }
}

// MARK: - Clock Protocol and InternalClock Implementation

/// A protocol defining a clock source that drives tick events.
public protocol Clock {
    /// The number of ticks per beat (resolution).
    var ticksPerBeat: Int { get set }
    
    /// The tempo in beats per minute.
    var tempo: Double { get set }
    
    /// A closure that is called on every tick.
    var tickHandler: (() -> Void)? { get set }
    
    /// Start the clock.
    func start()
    
    /// Stop the clock.
    func stop()
}

/// The default internal clock implementation using DispatchSourceTimer.
class InternalClock: Clock {
    var ticksPerBeat: Int
    var tempo: Double {
        didSet {
            updateTickInterval()
        }
    }
    var tickHandler: (() -> Void)?
    
    private let queue = DispatchQueue(label: "com.example.clock")
    private var timer: DispatchSourceTimer?
    private var tickInterval: DispatchTimeInterval
    
    /// Initializes an internal clock with the given ticks per beat and tempo.
    ///
    /// - Parameters:
    ///   - ticksPerBeat: The number of ticks per beat (default 480, ~1ms resolution at 120 BPM).
    ///   - tempo: The tempo in BPM (default 120 BPM).
    init(ticksPerBeat: Int = 480, tempo: Double = 120.0) {
        self.ticksPerBeat = ticksPerBeat
        self.tempo = tempo
        // Calculate tick interval: one beat = 60 / tempo seconds, divided by ticksPerBeat.
        let beatDuration = 60.0 / tempo
        let tickDuration = beatDuration / Double(ticksPerBeat)
        self.tickInterval = DispatchTimeInterval.nanoseconds(Int(tickDuration * 1_000_000_000))
    }
    
    /// Updates the tick interval when the tempo changes.
    private func updateTickInterval() {
        let beatDuration = 60.0 / tempo
        let tickDuration = beatDuration / Double(ticksPerBeat)
        self.tickInterval = DispatchTimeInterval.nanoseconds(Int(tickDuration * 1_000_000_000))
        // In a production system, you might consider restarting the timer with the new interval.
    }
    
    func start() {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: tickInterval, leeway: .microseconds(100))
        timer?.setEventHandler { [weak self] in
            self?.tickHandler?()
        }
        timer?.resume()
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
}

public class ScheduledAction {
    public var scheduledTime: TimeInterval
    public let closure: (GlobalState, ScheduledAction) -> Void
    public let condition: () -> Bool
    public let probability: Double
    public let every: Int
    public var counter: Int = 0
    public var rescheduleHandler: ((GlobalState, ScheduledAction) -> ScheduledAction?)?
    public var state: [AnyHashable: Any]
    
    public init(scheduledTime: TimeInterval,
                state: [AnyHashable: Any] = [:],
                condition: @escaping () -> Bool = { true },
                probability: Double = 1.0,
                every: Int = 1,
                rescheduleHandler: ((GlobalState, ScheduledAction) -> ScheduledAction?)? = nil,
                closure: @escaping (GlobalState, ScheduledAction) -> Void) {
        self.scheduledTime = scheduledTime
        self.state = state
        self.condition = condition
        self.probability = probability
        self.every = max(every, 1)
        self.rescheduleHandler = rescheduleHandler
        self.closure = closure
    }
}

public class Timeline {
    var clock: Clock
    private var actions: [ScheduledAction] = []
    private var startTime: DispatchTime?
    private let queue = DispatchQueue(label: "com.example.timeline")
    
    /// The global state shared between the Timeline and its actions.
    let globalState: GlobalState
    
    public init(clock: Clock? = nil, globalState: GlobalState) {
        self.clock = clock ?? InternalClock()
        self.globalState = globalState
    }
    
    var currentTime: TimeInterval {
        guard let start = startTime else { return 0 }
        let now = DispatchTime.now()
        return Double(now.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
    }
    
    public func start() {
        startTime = DispatchTime.now()
        clock.tickHandler = { [weak self] in
            self?.queue.async {
                self?.tick()
            }
        }
        clock.start()
    }
    
    public func stop() {
        clock.stop()
    }
    
    public func schedule(action: ScheduledAction) {
        queue.async {
            self.actions.append(action)
            self.actions.sort { $0.scheduledTime < $1.scheduledTime }
        }
    }
    
    private func tick() {
        let now = currentTime
        while let action = actions.first, action.scheduledTime <= now {
            _ = actions.removeFirst()
            action.counter += 1
            if !action.condition() {
                continue
            }
            if action.counter % action.every != 0 {
                continue
            }
            let roll = Double.random(in: 0.0...1.0)
            if roll <= action.probability {
                action.closure(globalState, action)
            }
            if let rescheduler = action.rescheduleHandler,
               let newAction = rescheduler(globalState, action) {
                actions.append(newAction)
                actions.sort { $0.scheduledTime < $1.scheduledTime }
            }
        }
    }
}
