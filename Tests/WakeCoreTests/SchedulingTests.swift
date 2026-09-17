// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

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
        let rule = Rule(action: .powerOn, hour: 7, minute: 0, repeats: .weekly(weekdays: Array(2...6)))
        let next = rule.nextOccurrence(after: friday, calendar: calendar)!
        let c = components(next)
        XCTAssertEqual(c.day, 21)
        XCTAssertEqual(c.weekday, 2)  // Monday
        XCTAssertEqual(c.hour, 7)
    }

    func testSingleDayRuleWrapsFullWeek() {
        // Tuesday rule at 09:00, asked right after Tuesday 10:30 → next Tuesday.
        let rule = Rule(action: .restart, hour: 9, minute: 0, repeats: .weekly(weekdays: [3]))
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
        let rule = Rule(action: .wake, hour: 7, minute: 0, repeats: .weekly(weekdays: []))
        XCTAssertNil(rule.nextOccurrence(after: tuesdayMorning, calendar: calendar))
    }

    func testInvalidWeekdaysAreDropped() {
        let rule = Rule(action: .wake, repeats: .weekly(weekdays: [0, 3, 8, 15]))
        XCTAssertEqual(rule.repeats.weekdays, [3])
    }

    func testRuleRoundTripsThroughJSON() throws {
        let rules = [
            Rule(label: "Morning", action: .wakeOrPowerOn, hour: 7, minute: 0, repeats: .weekly(weekdays: Array(2...6))),
            Rule(label: "Night", action: .sleep, hour: 23, minute: 30, enabled: false),
        ]
        let data = try JSONCodec.encode(rules)
        let decoded = try JSONCodec.decode([Rule].self, from: data)
        XCTAssertEqual(decoded, rules)
    }

    // MARK: - Validation
    //
    // Synthesized Codable decoding skips the designated initializer, so before
    // Rule got an explicit init(from:) a hand-edited or hostile rules.json could
    // carry weekday 0 or 8 and crash the menu bar app on symbol lookup.

    func testDecodingSanitizesOutOfRangeValues() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","label":"x","action":"shutdown",
          "hour":99,"minute":-5,"enabled":true,
          "repeats":{"weekly":{"weekdays":[0,3,8]}}}]
        """
        let rules = try JSONCodec.decode([Rule].self, from: Data(json.utf8))
        XCTAssertEqual(rules[0].repeats.weekdays, [3])
        XCTAssertEqual(rules[0].hour, 23)
        XCTAssertEqual(rules[0].minute, 0)
    }

    func testDecodedWeekdaysAreAlwaysValidSymbolIndices() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","action":"wake","hour":7,"minute":0,
          "repeats":{"weekly":{"weekdays":[-3,0,1,7,8,99]}}}]
        """
        let rules = try JSONCodec.decode([Rule].self, from: Data(json.utf8))
        let symbols = calendar.shortWeekdaySymbols
        for day in rules[0].repeats.weekdays {
            XCTAssertTrue(symbols.indices.contains(day - 1), "weekday \(day) out of range")
        }
    }

    // MARK: - One-time rules

    func testOneTimeRuleFiresAtItsMoment() {
        // Tuesday 2026-09-15 10:30 → a one-time rule on the 18th at 06:00.
        let rule = Rule(action: .wakeOrPowerOn, hour: 6, minute: 0,
                        repeats: .once(year: 2026, month: 9, day: 18))
        let next = rule.nextOccurrence(after: tuesdayMorning, calendar: calendar)!
        let c = components(next)
        XCTAssertEqual([c.day, c.hour, c.minute], [18, 6, 0])
    }

    func testOneTimeRuleDoesNotRepeat() {
        let rule = Rule(hour: 6, minute: 0, repeats: .once(year: 2026, month: 9, day: 18))
        let afterItFired = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 18, hour: 6, minute: 1))!
        XCTAssertNil(rule.nextOccurrence(after: afterItFired, calendar: calendar))
    }

    func testOneTimeRuleExpiresAfterItsMoment() {
        let rule = Rule(hour: 6, minute: 0, repeats: .once(year: 2026, month: 9, day: 18))
        let before = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 18, hour: 5, minute: 59))!
        let after = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 18, hour: 6, minute: 1))!
        XCTAssertFalse(rule.isExpired(at: before, calendar: calendar))
        XCTAssertTrue(rule.isExpired(at: after, calendar: calendar))
    }

    func testWeeklyRulesNeverExpire() {
        let rule = Rule(hour: 6, minute: 0, repeats: .weekly(weekdays: [3]))
        XCTAssertFalse(rule.isExpired(at: .distantFuture, calendar: calendar))
    }

    func testOneTimeRuleRoundTripsThroughJSON() throws {
        let rules = [Rule(label: "Flight", action: .wakeOrPowerOn, hour: 5, minute: 30,
                          repeats: .once(year: 2026, month: 12, day: 24))]
        let decoded = try JSONCodec.decode([Rule].self, from: JSONCodec.encode(rules))
        XCTAssertEqual(decoded, rules)
    }

    func testDuplicateWeekdaysCollapse() {
        XCTAssertEqual(Rule(repeats: .weekly(weekdays: [3, 3, 1, 3])).repeats.weekdays, [1, 3])
    }

    func testLabelIsBounded() {
        let rule = Rule(label: String(repeating: "a", count: Limits.maxLabelLength + 500))
        XCTAssertEqual(rule.label.count, Limits.maxLabelLength)
    }

    func testMissingOptionalFieldsGetDefaults() throws {
        let json = """
        [{"id":"\(UUID().uuidString)","action":"sleep","hour":1,"minute":2}]
        """
        let rules = try JSONCodec.decode([Rule].self, from: Data(json.utf8))
        XCTAssertEqual(rules[0].label, "")
        XCTAssertTrue(rules[0].enabled)
        XCTAssertEqual(rules[0].repeats.weekdays, [])
    }

    func testRuleStoreDelete() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wakemymac-tests-\(UUID().uuidString)")
        let store = RuleStore(directory: dir.path)
        defer { try? FileManager.default.removeItem(at: dir) }

        try store.save([Rule(label: "Test")])
        XCTAssertEqual(store.load().count, 1)
        try store.delete()
        XCTAssertEqual(store.load(), [])
        XCTAssertNoThrow(try store.delete(), "deleting a missing file should be a no-op")
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
