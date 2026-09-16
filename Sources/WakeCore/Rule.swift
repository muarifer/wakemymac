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
        self.label = label
        self.action = action
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays.filter { (1...7).contains($0) }.sorted()
        self.enabled = enabled
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

    public func weekdaysDescription(calendar: Calendar = .current) -> String {
        let days = Set(weekdays)
        if days == Set(1...7) { return "Every day" }
        if days == Set(2...6) { return "Weekdays" }
        if days == Set([1, 7]) { return "Weekends" }
        let symbols = calendar.shortWeekdaySymbols
        return weekdays.map { symbols[$0 - 1] }.joined(separator: " ")
    }

    public var effectiveLabel: String {
        label.isEmpty ? "\(action.displayName) at \(timeString)" : label
    }
}
