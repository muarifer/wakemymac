import XCTest
@testable import WakeCore

final class SchedulingTests: XCTestCase {
    // Fixed calendar so results don't depend on the machine's locale/zone.
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    /// Tuesday 2026-09-15 10:30 Istanbul time.
    private var tuesdayMorning: Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 15, hour: 10, minute: 30))!
    }

    private func components(_ date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
    }

    func testDailyRuleLaterToday() {
        let rule = Rule(action: .sleep, hour: 23, minute: 0)
        let next = rule.nextOccurrence(after: tuesdayMorning, calendar: calendar)!
        let c = components(next)
        XCTAssertEqual([c.day, c.hour, c.minute], [15, 23, 0])
    }

    func testDailyRuleRollsToTomorrow() {
        let rule = Rule(action: .wake, hour: 7, minute: 0)
        let next = rule.nextOccurrence(after: tuesdayMorning, calendar: calendar)!
        let c = components(next)
        XCTAssertEqual([c.day, c.hour, c.minute], [16, 7, 0])
    }

    func testWeekdayRuleSkipsWeekend() {
        // Friday 2026-09-18 08:00; weekday rule at 07:00 → Monday the 21st.
        let friday = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 18, hour: 8, minute: 0))!
        let rule = Rule(action: .powerOn, hour: 7, minute: 0, weekdays: Array(2...6))
        let next = rule.nextOccurrence(after: friday, calendar: calendar)!
        let c = components(next)
        XCTAssertEqual(c.day, 21)
        XCTAssertEqual(c.weekday, 2)  // Monday
        XCTAssertEqual(c.hour, 7)
    }

    func testSingleDayRuleWrapsFullWeek() {
        // Tuesday rule at 09:00, asked right after Tuesday 10:30 → next Tuesday.
        let rule = Rule(action: .restart, hour: 9, minute: 0, weekdays: [3])
        let next = rule.nextOccurrence(after: tuesdayMorning, calendar: calendar)!
        let c = components(next)
        XCTAssertEqual(c.day, 22)
        XCTAssertEqual(c.weekday, 3)
    }

    func testExactBoundaryIsStrictlyAfter() {
        // "after 23:00 exactly" must not return 23:00 today.
        let at2300 = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 15, hour: 23, minute: 0))!
        let rule = Rule(action: .sleep, hour: 23, minute: 0)
        let next = rule.nextOccurrence(after: at2300, calendar: calendar)!
        XCTAssertEqual(components(next).day, 16)
    }

    func testNoWeekdaysMeansNoOccurrence() {
        let rule = Rule(action: .wake, hour: 7, minute: 0, weekdays: [])
        XCTAssertNil(rule.nextOccurrence(after: tuesdayMorning, calendar: calendar))
    }

    func testInvalidWeekdaysAreDropped() {
        let rule = Rule(action: .wake, weekdays: [0, 3, 8, 15])
        XCTAssertEqual(rule.weekdays, [3])
    }

    func testRuleRoundTripsThroughJSON() throws {
        let rules = [
            Rule(label: "Morning", action: .wakeOrPowerOn, hour: 7, minute: 0, weekdays: Array(2...6)),
            Rule(label: "Night", action: .sleep, hour: 23, minute: 30, enabled: false),
        ]
        let data = try JSONCodec.encode(rules)
        let decoded = try JSONCodec.decode([Rule].self, from: data)
        XCTAssertEqual(decoded, rules)
    }

    func testRuleStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wakemymac-tests-\(UUID().uuidString)")
        let store = RuleStore(directory: dir.path)
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertEqual(store.load(), [])
        let rules = [Rule(label: "Test", action: .shutdown, hour: 22, minute: 15)]
        try store.save(rules)
        XCTAssertEqual(store.load(), rules)
    }
}
