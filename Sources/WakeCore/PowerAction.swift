import Foundation

/// A schedulable power event. Raw values are exactly the IOPMLib event type
/// strings (kIOPMAutoWake & friends), so `rawValue` can be passed straight to
/// IOPMSchedulePowerEvent.
public enum PowerAction: String, Codable, CaseIterable, Sendable {
    case wake = "wake"
    case powerOn = "poweron"
    case wakeOrPowerOn = "wakepoweron"
    case sleep = "sleep"
    case shutdown = "shutdown"
    case restart = "restart"

    public var displayName: String {
        switch self {
        case .wake: return "Wake"
        case .powerOn: return "Power On"
        case .wakeOrPowerOn: return "Wake or Power On"
        case .sleep: return "Sleep"
        case .shutdown: return "Shut Down"
        case .restart: return "Restart"
        }
    }

    public var symbolName: String {
        switch self {
        case .wake: return "sun.max"
        case .powerOn: return "power"
        case .wakeOrPowerOn: return "power.circle"
        case .sleep: return "moon.zzz"
        case .shutdown: return "power.dotted"
        case .restart: return "arrow.clockwise"
        }
    }
}
