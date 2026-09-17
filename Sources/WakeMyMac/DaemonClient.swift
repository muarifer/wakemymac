import Foundation
import WakeCore

/// Async facade over the privileged XPC connection to wakemymacd.
final class DaemonClient {
    private var connection: NSXPCConnection?

    private func proxy() -> WakeDaemonProtocol? {
        if connection == nil {
            let c = NSXPCConnection(
                machServiceName: DaemonConstants.machServiceName, options: .privileged)
            // Only talk to a daemon signed by us. Planting one requires admin
            // rights already, but this costs nothing and closes the other half
            // of the trust relationship.
            c.setCodeSigningRequirement(CodeSigningRequirement.forDaemon())
            c.remoteObjectInterface = NSXPCInterface(with: WakeDaemonProtocol.self)
            c.invalidationHandler = { [weak self] in self?.connection = nil }
            c.resume()
            connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler { [weak self] _ in
            self?.connection?.invalidate()
            self?.connection = nil
        } as? WakeDaemonProtocol
    }

    /// Daemon version, or nil if unreachable.
    func ping() async -> String? {
        await withTimeout { proxy, finish in
            proxy.ping { finish($0) }
        }
    }

    func fetchRules() async -> [Rule]? {
        await withTimeout { proxy, finish in
            proxy.getRules { data in
                finish(data.flatMap { try? JSONCodec.decode([Rule].self, from: $0) })
            }
        }
    }

    func fetchScheduledEvents() async -> [ScheduledEventInfo]? {
        await withTimeout { proxy, finish in
            proxy.getScheduledEvents { data in
                finish(data.flatMap { try? JSONCodec.decode([ScheduledEventInfo].self, from: $0) })
            }
        }
    }

    /// Asks the daemon to cancel its power events and delete stored rules.
    /// Returns an error message, or nil on success.
    func prepareForRemoval() async -> String? {
        let result: String?? = await withTimeout { proxy, finish in
            proxy.prepareForRemoval { finish($0) }
        }
        switch result {
        case .none: return "Daemon is not reachable"
        case .some(let inner): return inner
        }
    }

    /// Returns an error message, or nil on success.
    func pushRules(_ rules: [Rule]) async -> String? {
        guard let data = try? JSONCodec.encode(rules) else { return "Could not encode rules" }
        let result: String?? = await withTimeout { proxy, finish in
            proxy.setRules(data) { finish($0) }
        }
        switch result {
        case .none: return "Daemon is not reachable"
        case .some(let inner): return inner
        }
    }

    /// Runs one XPC round trip with a 5s timeout; nil means no reply
    /// (daemon missing, not approved, or hung).
    private func withTimeout<T: Sendable>(
        _ body: @escaping @Sendable (WakeDaemonProtocol, @escaping @Sendable (T?) -> Void) -> Void
    ) async -> T? {
        guard let proxy = proxy() else { return nil }
        let box = ReplyBox<T>()
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if box.take() { continuation.resume(returning: nil) }
            }
            body(proxy) { value in
                if box.take() { continuation.resume(returning: value) }
            }
        }
    }
}

/// Ensures a continuation resumes exactly once across reply vs. timeout.
private final class ReplyBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var open = true

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard open else { return false }
        open = false
        return true
    }
}
