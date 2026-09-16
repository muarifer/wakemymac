import Foundation

/// Loads/saves the rule list as JSON at a fixed path. The daemon uses the
/// root-owned default location; tests point it at a temp directory.
public struct RuleStore: Sendable {
    public let fileURL: URL

    public init(directory: String = DaemonConstants.rulesDirectory,
                fileName: String = DaemonConstants.rulesFileName) {
        self.fileURL = URL(fileURLWithPath: directory).appendingPathComponent(fileName)
    }

    public func load() -> [Rule] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONCodec.decode([Rule].self, from: data)) ?? []
    }

    public func save(_ rules: [Rule]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755])
        let data = try JSONCodec.encode(rules)
        try data.write(to: fileURL, options: .atomic)
    }
}
