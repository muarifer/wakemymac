import Foundation

/// XPC interface between the menu bar app and the root daemon.
/// Payloads cross the wire as JSON Data (JSONCodec below) to keep the
/// NSSecureCoding surface minimal.
@objc public protocol WakeDaemonProtocol {
    /// Returns the daemon version string; used as a liveness check.
    func ping(reply: @escaping @Sendable (String) -> Void)

    /// Replaces the full rule list. `rulesJSON` is a JSON-encoded [Rule].
    /// Persists to disk and reschedules immediately.
    /// Reply carries an error description, or nil on success.
    func setRules(_ rulesJSON: Data, reply: @escaping @Sendable (String?) -> Void)

    /// Returns the persisted rule list as JSON-encoded [Rule].
    func getRules(reply: @escaping @Sendable (Data?) -> Void)

    /// Returns the power events currently registered with the system by this
    /// daemon, as JSON-encoded [ScheduledEventInfo].
    func getScheduledEvents(reply: @escaping @Sendable (Data?) -> Void)
}

/// Snapshot of one power event the daemon has registered with powerd.
public struct ScheduledEventInfo: Codable, Equatable, Sendable {
    public var date: Date
    public var action: PowerAction
    public var ruleID: UUID?
    public var ruleLabel: String?

    public init(date: Date, action: PowerAction, ruleID: UUID? = nil, ruleLabel: String? = nil) {
        self.date = date
        self.action = action
        self.ruleID = ruleID
        self.ruleLabel = ruleLabel
    }
}

/// Shared JSON coding so app and daemon agree on date format.
public enum JSONCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
