//
//  LiveConnection.swift
//
//  Created by Jared on 3/23/25
//
//  This file implements the central OSC connection manager for controlling
//  Ableton Live via the AbletonOSC script. It is analogous to PyLive’s Query class.
//

import Foundation
import OSCKit

/// The main OSC connection for sending commands to and receiving replies/events from Ableton Live.
public final class LiveConnection: @unchecked Sendable {
    
    // MARK: - Public Properties
    
    /// The IP or hostname where AbletonOSC is running (typically "127.0.0.1").
    public let host: String
    
    /// The port AbletonOSC listens on (default 11000).
    public let sendPort: Int
    
    /// The port this client listens on for replies (default 11001).
    public let receivePort: Int
    
    /// Whether we've successfully opened our OSC socket.
    public private(set) var isConnected: Bool = false
    
    /// Optional toggle for debug logging. If true, logs all incoming/outgoing messages.
    public var enableLogging: Bool = false
    
    // MARK: - Private Properties
    
    /// The primary OSCSocket from OSCKit handling bidirectional traffic.
    private var oscSocket: OSCSocket?
    
    /// Tracks pending queries, keyed by OSC address. We only allow one pending query per unique address.
    /// The continuation is resumed once we get a matching reply or a timeout occurs.
    private var pendingRequests: [String: CheckedContinuation<[Any], Error>] = [:]
    
    /// A serial dispatch queue to synchronize access to `pendingRequests`.
    private let syncQueue = DispatchQueue(label: "LiveConnection.pendingRequests")
    
    // MARK: - Initialization
    
    /// Creates a new connection to AbletonOSC (host:port) and sets up a listening socket on receivePort.
    public init(
        host: String = "127.0.0.1",
        sendPort: Int = LiveDefaults.defaultSendPort,
        receivePort: Int = LiveDefaults.defaultReceivePort
    ) {
        self.host = host
        self.sendPort = sendPort
        self.receivePort = receivePort
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    /// Opens the OSC socket for bidirectional communication. Call once before sending commands.
    public func connect() throws {
        guard !isConnected else { return }
        
        // Create an OSCSocket that sends to (host, sendPort) and listens on receivePort.
        let socket = OSCSocket(
            localPort: UInt16(receivePort),
            remoteHost: host,
            remotePort: UInt16(sendPort),
            handler: { [weak self] (message: OSCMessage, timeTag: OSCTimeTag, senderHost: String, senderPort: UInt16) in
                self?.handleIncomingMessage(message)
            }
        )
        
        // Attempt to start the socket (bind to local receivePort).
        try socket.start()
        
        self.oscSocket = socket
        self.isConnected = true
        
        if enableLogging {
            print("[LiveConnection] Connected on port \(receivePort), sending to \(host):\(sendPort)")
        }
    }
    
    /// Closes the socket and releases resources.
    public func disconnect() {
        guard let sock = oscSocket, isConnected else { return }
        sock.stop()
        oscSocket = nil
        isConnected = false
        if enableLogging {
            print("[LiveConnection] Disconnected.")
        }
    }
    
    // MARK: - Sending Commands
    
    /// Sends an OSC message for commands that do not require a response (fire-and-forget).
    /// This is analogous to PyLive's `cmd(...)`.
    ///
    /// - Parameters:
    ///   - address: The OSC address path (e.g. "/live/song/set/tempo")
    ///   - arguments: The arguments for the message (optional).
    public func send(
        address: String,
        arguments: [any OSCValue] = []  // Assuming now we pass native Swift types
    ) {
        guard isConnected, let sock = oscSocket else {
            if enableLogging {
                print("[LiveConnection] Not connected. Can't send \(address)")
            }
            return
        }
        
        let message = OSCMessage(address, values: arguments)
        
        if enableLogging {
            print("[LiveConnection] -> Sending to \(address) args: \(arguments)")
        }
        
        do {
            try sock.send(message)
        } catch {
            if enableLogging {
                print("[LiveConnection] Error sending OSC message to \(address): \(error)")
            }
        }
    }
    
    
    // MARK: - Query / Response
    
    /// Sends an OSC message and awaits a single reply on the *same* OSC address.
    /// If no reply is received within `timeout` seconds, throws `LiveError.timeout`.
    ///
    /// This is analogous to PyLive's `query(...)`.
    ///
    /// - Parameters:
    ///   - address: The OSC address to send (and to expect in a reply).
    ///   - arguments: Any arguments for the outgoing OSC message.
    ///   - timeout: The time to wait for a response (default 3s).
    /// - Returns: The OSC arguments from the reply message.
    public func query(
        _ address: String,
        arguments: OSCValues = [],
        timeout: TimeInterval = 3.0
    ) async throws -> [Any] {
        guard isConnected else {
            throw LiveError.notConnected
        }
        
        // Check if there's already a pending request for this address
        var alreadyPending = false
        syncQueue.sync {
            if pendingRequests[address] != nil {
                alreadyPending = true
            }
        }
        
        if alreadyPending {
            throw LiveError.oscError("Another request for \(address) is already pending.")
        }
        
        if enableLogging {
            print("[LiveConnection] -> Query \(address) args: \(arguments)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Insert the continuation into the dictionary.
            syncQueue.sync {
                pendingRequests[address] = continuation
            }
            
            // Create the OSC message
            let message = OSCMessage(address, values: arguments)
            
            // Send the message inside a do-catch block
            do {
                try oscSocket?.send(message)
            } catch {
                syncQueue.sync {
                    if let cont = pendingRequests.removeValue(forKey: address) {
                        cont.resume(throwing: error)
                    }
                }
                return
            }
            
            // Set up a timeout
            let deadline = DispatchTime.now() + timeout
            syncQueue.asyncAfter(deadline: deadline) { [weak self] in
                guard let self = self else { return }
                if let cont = self.pendingRequests.removeValue(forKey: address) {
                    cont.resume(throwing: LiveError.timeout)
                    if self.enableLogging {
                        print("[LiveConnection] X Query TIMED OUT: \(address)")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Private Incoming Message Handler
    
    /// Called whenever an OSC message arrives on the socket.
    /// If it matches a pending query address, we resume the awaiting continuation.
    /// Otherwise, we can dispatch it as an event or ignore it.
    private func handleIncomingMessage(_ msg: OSCMessage) {
        // For example, if a query is waiting for this address, resume it.
        let address = msg.addressPattern
        
        syncQueue.sync {
            // Check if we have a waiting continuation
            if let continuation = pendingRequests.removeValue(forKey: address.stringValue) {
                if enableLogging {
                    print("[LiveConnection] <- Reply from \(address) args: \(msg.values)")
                }
                // Resume the query with the returned arguments
                continuation.resume(returning: msg.values)
            } else {
                // No pending query found. This might be an unsolicited event or a beat callback, etc.
                if enableLogging {
                    print("[LiveConnection] <- Unsolicited message on \(address) args: \(msg.values)")
                }
                // You could handle other event callbacks here if needed.
            }
        }
    }
}
