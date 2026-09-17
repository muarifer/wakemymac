// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import Foundation
import IOKit.pwr_mgt
import WakeCore

/// Thin wrapper over IOPMSchedulePowerEvent / IOPMCancelScheduledPowerEvent /
/// IOPMCopyScheduledPowerEvents. Requires root for wake/poweron events, which
/// is why this lives in the launchd daemon.
enum PowerEventScheduler {
    // Dictionary keys used by IOPMCopyScheduledPowerEvents
    // (kIOPMPowerEventTimeKey / AppNameKey / TypeKey).
    private static let timeKey = "time"
    private static let ownerKey = "scheduledby"
    private static let typeKey = "eventtype"

    struct SystemEvent {
        let date: Date
        let owner: String
        let type: String
    }

    enum Failure: Error, CustomStringConvertible {
        case ioError(IOReturn, String)

        var description: String {
            switch self {
            case .ioError(let code, let context):
                return "\(context) failed: IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16))"
            }
        }
    }

    static func schedule(_ action: PowerAction, at date: Date, owner: String) throws {
        let result = IOPMSchedulePowerEvent(
            date as CFDate, owner as CFString, action.rawValue as CFString)
        guard result == kIOReturnSuccess else {
            throw Failure.ioError(result, "IOPMSchedulePowerEvent(\(action.rawValue))")
        }
    }

    static func cancel(_ event: SystemEvent) {
        // Best-effort; the event may already have fired.
        _ = IOPMCancelScheduledPowerEvent(
            event.date as CFDate, event.owner as CFString, event.type as CFString)
    }

    /// All power events currently registered with powerd, systemwide.
    static func allEvents() -> [SystemEvent] {
        guard let raw = IOPMCopyScheduledPowerEvents()?.takeRetainedValue() as? [[String: Any]]
        else { return [] }
        return raw.compactMap { dict in
            guard let date = dict[timeKey] as? Date,
                  let owner = dict[ownerKey] as? String,
                  let type = dict[typeKey] as? String
            else { return nil }
            return SystemEvent(date: date, owner: owner, type: type)
        }
    }

    /// Cancels every event previously scheduled under our owner string.
    static func cancelOwnedEvents(owner: String) {
        for event in allEvents() where event.owner == owner {
            cancel(event)
        }
    }
}
