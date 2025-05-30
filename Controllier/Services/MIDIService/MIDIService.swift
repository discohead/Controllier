import MIDIKit
import SwiftUI
import Combine

protocol MIDIServiceProtocol: AnyObject {
    /// Sends a MIDI event to the configured output(s)
    func send(_ event: MIDIEvent) throws
    
    /// A publisher that emits all incoming MIDI events
    var incomingMIDIEvents: AnyPublisher<MIDIEvent, Never> { get }
}

/// Receiving MIDI happens on an asynchronous background thread. That means it cannot update
/// SwiftUI view state directly. Therefore, we need a helper class marked with `@Observable`
/// which contains properties that SwiftUI can use to update views.
@Observable final class MIDIService: MIDIServiceProtocol {
    
    private let midiManager: ObservableMIDIManager?
    private weak var globalState: GlobalState?
    
    private let midiSubject = PassthroughSubject<MIDIEvent, Never>()
    var incomingMIDIEvents: AnyPublisher<MIDIEvent, Never> {
        midiSubject.eraseToAnyPublisher()
    }
    
    public init(globalState: GlobalState? = nil) {
        self.globalState = globalState
        self.midiManager = ObservableMIDIManager(
            clientName: "ControllierMIDIManager",
            model: "Controllier",
            manufacturer: "JaredMcFarland"
        )
        do {
            print("Starting MIDI services.")
            try self.midiManager?.start()
            print("MIDI ENDPOINTS: ")
            print(self.midiManager?.endpoints ?? "WARNING: No endpoints found!")
        } catch {
            print("Error starting MIDI services:", error.localizedDescription)
        }
        setupConnections()
    }
    
    func setGlobalState(_ state: GlobalState) {
        self.globalState = state
    }
    
    // MARK: - Connections
    
    static let inputConnectionName = "Controllier Input Connection"
    static let outputConnectionName = "Controllier Output Connection"
    
    @Sendable private func inputEventsHandler(events: [MIDIEvent], timeStamp: CoreMIDITimeStamp, source: MIDIOutputEndpoint?) {
        for event in events {
            handleMIDI(event: event)
        }
    }
    
    private func setupConnections() {
        guard let midiManager else { return }
        
        do {
            // "iPad" is the name of the MIDI input and output that iOS creates
            // on the iOS device once a user has clicked 'Enable' in Audio MIDI Setup on the Mac
            // to establish the USB audio/MIDI connection to the iOS device.
            
            print("Creating MIDI input connection.")
            try midiManager.addInputConnection(
                to: .outputs(matching: [.name("Electra Port 1")]),
                tag: Self.inputConnectionName,
                receiver: .events(options: [
                    .bundleRPNAndNRPNDataEntryLSB,
                    .filterActiveSensingAndClock,
                    .translateMIDI1NoteOnZeroVelocityToNoteOff
                ], inputEventsHandler)
            )
            
            print("Creating MIDI output connection.")
            try midiManager.addOutputConnection(
                to: .inputs(matching: [.name("Bus 1")]),
                tag: Self.outputConnectionName
            )
        } catch {
            print("Error creating MIDI output connection:", error.localizedDescription)
        }
    }
    
    /// Convenience accessor for created MIDI Output Connection.
    var outputConnection: MIDIOutputConnection? {
        midiManager?.managedOutputConnections[Self.outputConnectionName]
    }
    
    func send(_ event: MIDIEvent) throws {
        try? outputConnection?.send(event: event)
    }
    
    func sendNoteOn(noteNum: UInt7, velocity: UInt7, channel: UInt4) {
        try? send(.noteOn(
            noteNum,
            velocity: .midi1(velocity),
            channel: channel
        ))
    }
    
    func sendNoteOff(noteNum: UInt7, channel: UInt4) {
        try? send(.noteOff(
            noteNum,
            velocity: .midi1(0),
            channel: channel
        ))
    }
    
    func sendCC(ccNum: UInt7, value: UInt7, channel: UInt4) {
        try? send(.cc(
            ccNum,
            value: .midi1(value),
            channel: channel
        ))
    }
    
    func handleMIDI(event: MIDIEvent) {
        switch event {
        case let .noteOn(payload):
            print(
                "Note On:",
                "\n  Note: \(payload.note.number.intValue) (\(payload.note.stringValue()))",
                "\n  Velocity (MIDI1 7-bit):",
                payload.velocity.midi1Value,
                "\n  Velocity (MIDI2 16-bit):",
                payload.velocity.midi2Value,
                "\n  Velocity (Unit Interval):",
                payload.velocity.unitIntervalValue,
                "\n  Attribute (MIDI2):",
                payload.attribute,
                "\n  Channel:",
                payload.channel.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .noteOff(payload):
            print(
                "Note Off:",
                "\n  Note: \(payload.note.number.intValue) (\(payload.note.stringValue()))",
                "\n  Velocity (MIDI1 7-bit):",
                payload.velocity.midi1Value,
                "\n  Velocity (MIDI2 16-bit):",
                payload.velocity.midi2Value,
                "\n  Velocity (Unit Interval):",
                payload.velocity.unitIntervalValue,
                "\n  Attribute (MIDI2):",
                payload.attribute,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .noteCC(payload):
            print(
                "Per-Note CC (MIDI 2.0 Only):",
                "\n  Note: \(payload.note.number.intValue) (\(payload.note.stringValue()))",
                "\n  Controller:",
                payload.controller,
                "\n  Value (MIDI2 32-bit):",
                payload.value.midi2Value,
                "\n  Value (Unit Interval):",
                payload.value.unitIntervalValue,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .notePitchBend(payload):
            print(
                "Per-Note Pitch Bend (MIDI 2.0 Only):",
                "\n  Note: \(payload.note.number.intValue) (\(payload.note.stringValue()))",
                "\n  Value (MIDI2 32-bit):",
                payload.value.midi2Value,
                "\n  Value (Unit Interval):",
                payload.value.unitIntervalValue,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .notePressure(payload):
            print(
                "Per-Note Pressure (a.k.a. Polyphonic Aftertouch):",
                "\n  Note: \(payload.note.number.intValue) (\(payload.note.stringValue()))",
                "\n  Amount (MIDI1 7-bit):",
                payload.amount.midi1Value,
                "\n  Amount (MIDI2 32-bit):",
                payload.amount.midi2Value,
                "\n  Amount (Unit Interval):",
                payload.amount.unitIntervalValue,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .noteManagement(payload):
            print(
                "Per-Note Management (MIDI 2.0 Only):",
                "\n  Note: \(payload.note.number.intValue) (\(payload.note.stringValue()))",
                "\n  Option Flags:",
                payload.flags,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .cc(payload):
            print(
                "Control Change (CC):",
                "\n  Controller:",
                payload.controller,
                "\n  Value (MIDI1 7-bit):",
                payload.value.midi1Value,
                "\n  Value (MIDI2 32-bit):",
                payload.value.midi2Value,
                "\n  Value (Unit Interval):",
                payload.value.unitIntervalValue,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            self.globalState?.controllerState.modify { $0.updateIfChanged(cc: payload) }
            
        case let .programChange(payload):
            print(
                "Program Change:",
                "\n  Program:",
                payload.program.intValue,
                "\n  Bank Select:",
                payload.bank,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .pitchBend(payload):
            print(
                "Channel Pitch Bend:",
                "\n  Value (MIDI1 14-bit):",
                payload.value.midi1Value,
                "\n  Value (MIDI2 32-bit):",
                payload.value.midi2Value,
                "\n  Value (Unit Interval):",
                payload.value.unitIntervalValue,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .pressure(payload):
            print(
                "Channel Pressure (a.k.a. Aftertouch):",
                "\n  Amount (MIDI1 7-bit):",
                payload.amount.midi1Value,
                "\n  Amount (MIDI2 32-bit):",
                payload.amount.midi2Value,
                "\n  Amount (Unit Interval):",
                payload.amount.unitIntervalValue,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .rpn(payload):
            print(
                "Registered Parameter Number (RPN) (a.k.a. Registered Controller):",
                "\n  Parameter:",
                payload.parameter,
                "\n  Change Type (Only applicable for MIDI 2.0; MIDI 1.0 is always absolute):",
                payload.change,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .nrpn(payload):
            print(
                "Non-Registered Parameter Number (NRPN) (a.k.a. Assignable Controller):",
                "\n  Parameter:",
                payload.parameter,
                "\n  Change Type (Only applicable for MIDI 2.0; MIDI 1.0 is always absolute):",
                payload.change,
                "\n  Channel:",
                payload.channel.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .sysEx7(payload):
            print(
                "System Exclusive 7:",
                "\n  Manufacturer:",
                payload.manufacturer,
                "\n  Data (\(payload.data.count) bytes):",
                payload.data.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .universalSysEx7(payload):
            print(
                "Universal System Exclusive 7:",
                "\n  Type:",
                payload.universalType,
                "\n  Device ID:",
                payload.deviceID.description,
                "\n  Sub ID #1:",
                payload.subID1.description,
                "\n  Sub ID #2:",
                payload.subID2.description,
                "\n  Data (\(payload.data.count) bytes):",
                payload.data.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .sysEx8(payload):
            print(
                "System Exclusive 8 (MIDI 2.0 Only):",
                "\n  Manufacturer:",
                payload.manufacturer,
                "\n  Data (\(payload.data.count) bytes):",
                payload.data.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .universalSysEx8(payload):
            print(
                "Universal System Exclusive 8 (MIDI 2.0 Only):",
                "\n  Type:",
                payload.universalType,
                "\n  Device ID:",
                payload.deviceID.description,
                "\n  Sub ID #1:",
                payload.subID1.description,
                "\n  Sub ID #2:",
                payload.subID2.description,
                "\n  Data (\(payload.data.count) bytes):",
                payload.data.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .timecodeQuarterFrame(payload):
            print(
                "Timecode Quarter-Frame:",
                "\n  Data Byte:",
                payload.dataByte.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .songPositionPointer(payload):
            print(
                "Song Position Pointer:",
                "\n  MIDI Beat:",
                payload.midiBeat.intValue.description,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .songSelect(payload):
            print(
                "Song Select:",
                "\n  Number:",
                payload.number.intValue,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .tuneRequest(payload):
            print(
                "Tune Request:",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .timingClock(payload):
            print(
                "Timing Clock:",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .start(payload):
            print(
                "Start:",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .continue(payload):
            print(
                "Continue:",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .stop(payload):
            print(
                "Stop:",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .activeSensing(payload):
            print(
                "Active Sensing (Deprecated in MIDI 2.0):",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .systemReset(payload):
            print(
                "System Reset:",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .noOp(payload):
            print(
                "No-Op (MIDI 2.0 Only):",
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .jrClock(payload):
            print(
                "JR Clock - Jitter-Reduction Clock (MIDI 2.0 Only):",
                "\n  Time Value:",
                payload.time,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
            
        case let .jrTimestamp(payload):
            print(
                "JR Timestamp - Jitter-Reduction Timestamp (MIDI 2.0 Only):",
                "\n  Time Value:",
                payload.time,
                "\n  UMP Group (MIDI2):",
                payload.group.intValue.description
            )
        }
        // Send the event to the subject
        midiSubject.send(event)
    }
}
