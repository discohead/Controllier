//
//  Timeline.swift
//  Controllier
//
//  Created by Jared McFarland on 3/27/25.
//

import Foundation

// Typealias for a closure that can be scheduled on the timeline
public typealias ScheduledClosure = (GlobalState, ScheduledAction) -> Void

// Typealias for a handler that can reschedule an action
public typealias RescheduleHandler = (GlobalState, ScheduledAction) -> ScheduledAction?

// Typealias for ScheduledAction condition closure
public typealias ConditionClosure = () -> Bool

/// A simple global state container. You can expand this with any properties you need.
public class GlobalState {
    public var someParameter: Double = 0.0
    // Add additional state properties here.
    
    public init() { }
}

/// An action that can be scheduled to occur at a specific musical position
public class ScheduledAction {
    /// The beat position when this action should execute
    public var scheduledBeat: Double
    
    /// The code to execute when this action is triggered
    public let closure: ScheduledClosure
    
    /// Optional condition that must be true for the action to execute
    public let condition: ConditionClosure?
    
    /// Probability (0.0-1.0) that the action will execute
    public let probability: Double
    
    /// Execute only every Nth time this action is processed
    public let every: Int
    
    /// Counter for tracking executions
    public var counter: Int = 0
    
    /// Handler that can reschedule this action after execution
    public var rescheduleHandler: RescheduleHandler?
    
    /// Custom state dictionary for this action
    public var state: [AnyHashable: Any]
    
    /// Initialize a scheduled action with musical timing
    /// - Parameters:
    ///   - scheduledBeat: The musical beat position when this action should execute
    ///   - state: Optional custom state to store with this action
    ///   - condition: Optional condition that must be true for execution
    ///   - probability: Probability (0.0-1.0) that the action will execute
    ///   - every: Execute only every Nth time (default: 1 = every time)
    ///   - rescheduleHandler: Optional handler for rescheduling
    ///   - closure: The code to execute when triggered
    public init(
        scheduledBeat: Double,
        state: [AnyHashable: Any] = [:],
        condition: ConditionClosure?,
        probability: Double = 1.0,
        every: Int = 1,
        rescheduleHandler: RescheduleHandler? = nil,
        closure: @escaping ScheduledClosure
    ) {
        self.scheduledBeat = scheduledBeat
        self.state = state
        self.condition = condition
        self.probability = probability
        self.every = max(every, 1)
        self.rescheduleHandler = rescheduleHandler
        self.closure = closure
    }
}

/// Timeline for scheduling musical events in terms of beats
public class Timeline {
    /// Actions that are scheduled to execute
    private var actions: [ScheduledAction] = []
    
    /// Processed action IDs to prevent duplicates
    private var processedActions: Set<ObjectIdentifier> = []
    
    /// Thread safety for timeline operations
    private let queue = DispatchQueue(label: "com.example.timeline")
    
    /// The global state shared between the Timeline and its actions
    public let globalState: GlobalState
    
    /// The current beat position in the timeline
    private var _currentBeat: Double = 0.0
    
    /// Public access to the current beat position
    public var currentBeat: Double {
        get { _currentBeat }
    }
    
    /// Initialize the timeline with an optional global state
    /// - Parameter globalState: The global state to use (creates a new one if nil)
    public init(globalState: GlobalState? = nil) {
        self.globalState = globalState ?? GlobalState()
    }
    
    /// Update the current beat position
    /// - Parameter beat: The new beat position
    public func updateBeatPosition(_ beat: Double) {
        _currentBeat = beat
        processEventsAtCurrentBeat()
    }
    
    /// Schedule an action to execute at a specific beat
    /// - Parameter action: The action to schedule
    public func schedule(action: ScheduledAction) {
        queue.async {
            self.actions.append(action)
            self.actions.sort { $0.scheduledBeat < $1.scheduledBeat }
        }
    }
    
    /// Process any events that are due to execute at the current beat position
    public func processEventsAtCurrentBeat() {
        queue.async {
            self.processEvents()
        }
    }
    
    /// Process events up to the current beat position
    private func processEvents() {
        let currentBeatPosition = _currentBeat
        
        // Process actions that are due
        while let firstAction = actions.first, firstAction.scheduledBeat <= currentBeatPosition {
            let action = actions.removeFirst()
            
            // Skip if we've already processed this action
            let actionId = ObjectIdentifier(action)
            if processedActions.contains(actionId) {
                continue
            }
            
            action.counter += 1
            
            // Check conditions for execution
            if let condition = action.condition, !condition() {
                continue
            }
            
            if action.counter % action.every != 0 {
                continue
            }
            
            // Apply probability
            let roll = Double.random(in: 0.0...1.0)
            if roll <= action.probability {
                action.closure(globalState, action)
                processedActions.insert(actionId)
            }
            
            // Handle rescheduling if needed
            if let rescheduler = action.rescheduleHandler,
               let newAction = rescheduler(globalState, action) {
                actions.append(newAction)
                actions.sort { $0.scheduledBeat < $1.scheduledBeat }
            }
        }
        
        // Periodically clean up the processed actions set to prevent unbounded growth
        if processedActions.count > 1000 {
            processedActions.removeAll()
        }
    }
    
    /// Reset the timeline, clearing all scheduled actions
    public func reset() {
        queue.async {
            self.actions.removeAll()
            self.processedActions.removeAll()
            self._currentBeat = 0.0
        }
    }
    
    /// Get a list of upcoming events for the next specified number of beats
    /// - Parameter beats: Number of beats to look ahead
    /// - Returns: Array of scheduled actions within the specified range
    public func upcomingEvents(forBeats beats: Double) -> [ScheduledAction] {
        let endBeat = _currentBeat + beats
        
        return actions.filter {
            $0.scheduledBeat >= _currentBeat && $0.scheduledBeat < endBeat
        }
    }
}
