import Foundation

/// A recurring schedule rule ("weekdays at 07:00, wake"). The daemon collapses
/// each rule to its single next occurrence and hands that to
/// IOPMSchedulePowerEvent as a one-shot event.
public struct Rule: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var action: PowerAction
    /// Hour of day, 0...23, in the machine's local time zone.
    public var hour: Int
    /// Minute, 0...59.
    public var minute: Int
    /// Calendar weekday numbers, 1 = Sunday ... 7 = Saturday. Kept sorted.
    /// All seven days means "daily".
    public var weekdays: [Int]
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
        weekdays: [Int] = Array(1...7),
        enabled: Bool = true
    ) {
        self.id = id
        self.label = String(label.prefix(Limits.maxLabelLength))
        self.action = action
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.weekdays = Set(weekdays.filter { (1...7).contains($0) }).sorted()
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
            weekdays: try container.decodeIfPresent([Int].self, forKey: .weekdays) ?? [],
            enabled: try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        )
    }

    /// The next time this rule fires strictly after `date`.
    /// Returns nil for a rule with no weekdays selected.
    public func nextOccurrence(after date: Date, calendar: Calendar = .current) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let days = Set(weekdays)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let candidate = calendar.date(
                      bySettingHour: hour, minute: minute, second: 0, of: day)
            else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if candidate > date, days.contains(weekday) {
                return candidate
            }
        }
        return nil
    }

    public var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public var effectiveLabel: String {
        label.isEmpty ? "\(action.displayName) at \(timeString)" : label
    }
}
