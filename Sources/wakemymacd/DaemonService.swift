import Foundation
import os
import WakeCore

/// Exported XPC object; one instance per connection.
final class DaemonService: NSObject, WakeDaemonProtocol {
    private let engine: SchedulerEngine

    init(engine: SchedulerEngine) {
        self.engine = engine
    }

    func ping(reply: @escaping @Sendable (String) -> Void) {
        reply(DaemonConstants.version)
    }

    func setRules(_ rulesJSON: Data, reply: @escaping @Sendable (String?) -> Void) {
        let rules: [Rule]
        do {
            rules = try JSONCodec.decode([Rule].self, from: rulesJSON)
        } catch {
            reply("Malformed rules payload: \(error.localizedDescription)")
            return
        }
        reply(engine.updateRules(rules))
    }

    func getRules(reply: @escaping @Sendable (Data?) -> Void) {
        reply(try? JSONCodec.encode(engine.currentRules()))
    }

    func getScheduledEvents(reply: @escaping @Sendable (Data?) -> Void) {
        reply(try? JSONCodec.encode(engine.scheduledEvents()))
    }
}

final class XPCListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let engine: SchedulerEngine
    private let log = Logger(subsystem: DaemonConstants.machServiceName, category: "xpc")

    init(engine: SchedulerEngine) {
        self.engine = engine
    }

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // TODO(hardening): before shipping outside our own machines, pin the
        // client with setCodeSigningRequirement(_:) to our Developer ID /
        // bundle ID so arbitrary local processes can't drive a root daemon.
        newConnection.exportedInterface = NSXPCInterface(with: WakeDaemonProtocol.self)
        newConnection.exportedObject = DaemonService(engine: engine)
        newConnection.resume()
        log.info("Accepted XPC connection from pid \(newConnection.processIdentifier)")
        return true
    }
}
