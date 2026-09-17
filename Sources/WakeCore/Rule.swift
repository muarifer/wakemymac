// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import Foundation

/// How a rule recurs. The time of day lives on `Rule` itself because both
/// cases need one; only the choice of *days* differs.
public enum RepeatMode: Codable, Equatable, Hashable, Sendable {
    /// Every week on these Calendar weekday numbers (1 = Sunday ... 7 = Saturday).
    case weekly(weekdays: [Int])
    /// Once on this calendar day. Stored as year/month/day rather than an
    /// absolute Date so it keeps meaning local wall-clock time, like the
    /// weekly case does — an absolute instant would drift if the time zone
    /// changed between creating the rule and firing it.
    case once(year: Int, month: Int, day: Int)

    public var isOnce: Bool {
        if case .once = self { return true }
        return false
    }

    public var weekdays: [Int] {
        if case .weekly(let days) = self { return days }
        return []
    }
}

/// A schedule rule ("weekdays at 07:00, wake" or "once on 18 Sep at 06:00").
/// The daemon collapses each rule to its single next occurrence and hands that
/// to IOPMSchedulePowerEvent, which only ever takes one-shot events.
public struct Rule: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var action: PowerAction
    /// Hour of day, 0...23, in the machine's local time zone.
    public var hour: Int
    /// Minute, 0...59.
    public var minute: Int
    public var repeats: RepeatMode
    public var enabled: Bool

    /// Enforces the type's invariants: hour/minute in range, weekdays valid,
    /// deduplicated and sorted, label bounded. Every path that builds a Rule —
    /// including `init(from:)` below — goes through here, so a value that exists
    /// is always safe to index a weekday symbol array with.
    public init(
        id: UUID = UUID(),
        label: String = "",
        action: PowerAction = .wakeOrPowerOn,
        hour: Int = 7,
        minute: Int = 0,
        repeats: RepeatMode = .weekly(weekdays: Array(1...7)),
        enabled: Bool = true
    ) {
        self.id = id
        self.label = String(label.prefix(Limits.maxLabelLength))
        self.action = action
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        switch repeats {
        case .weekly(let days):
            self.repeats = .weekly(weekdays: Set(days.filter { (1...7).contains($0) }).sorted())
        case .once:
            self.repeats = repeats
        }
        self.enabled = enabled
    }

    /// Synthesized decoding would assign the stored properties directly and skip
    /// the validation above, so a hand-edited or hostile rules.json could carry
    /// a weekday like 0 or 8 and crash the UI on symbol lookup. Delegating to the
    /// designated initializer keeps the invariants for decoded values too.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            label: try container.decodeIfPresent(String.self, forKey: .label) ?? "",
            action: try container.decode(PowerAction.self, forKey: .action),
            hour: try container.decode(Int.self, forKey: .hour),
            minute: try container.decode(Int.self, forKey: .minute),
            repeats: try container.decodeIfPresent(RepeatMode.self, forKey: .repeats)
                ?? .weekly(weekdays: []),
            enabled: try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        )
    }

    /// The next time this rule fires strictly after `date`.
    /// Returns nil for a weekly rule with no days, or a one-time rule whose
    /// moment has passed.
    public func nextOccurrence(after date: Date, calendar: Calendar = .current) -> Date? {
        switch repeats {
        case .once:
            guard let when = scheduledDate(calendar: calendar) else { return nil }
            return when > date ? when : nil

        case .weekly(let weekdays):
            guard !weekdays.isEmpty else { return nil }
            let days = Set(weekdays)
            for offset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                      let candidate = calendar.date(
                          bySettingHour: hour, minute: minute, second: 0, of: day)
                else { continue }
                if candidate > date, days.contains(calendar.component(.weekday, from: candidate)) {
                    return candidate
                }
            }
            return nil
        }
    }

    /// The absolute moment a one-time rule fires; nil for a weekly rule.
    public func scheduledDate(calendar: Calendar = .current) -> Date? {
        guard case .once(let year, let month, let day) = repeats else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }

    /// True once a one-time rule's moment has passed. Weekly rules never expire.
    /// The daemon uses this to switch a spent rule off instead of leaving it
    /// enabled but permanently silent.
    public func isExpired(at now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard repeats.isOnce else { return false }
        guard let when = scheduledDate(calendar: calendar) else { return true }
        return when <= now
    }

    public var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public var effectiveLabel: String {
        label.isEmpty ? "\(action.displayName) at \(timeString)" : label
    }
}
