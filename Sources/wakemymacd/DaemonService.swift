// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

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
        guard rulesJSON.count <= Limits.maxPayloadBytes else {
            reply("Rules payload too large")
            return
        }
        let rules: [Rule]
        do {
            rules = try JSONCodec.decode([Rule].self, from: rulesJSON)
        } catch {
            reply("Malformed rules payload: \(error.localizedDescription)")
            return
        }
        guard rules.count <= Limits.maxRules else {
            reply("Too many rules (limit is \(Limits.maxRules))")
            return
        }
        reply(engine.updateRules(rules))
    }

    func prepareForRemoval(reply: @escaping @Sendable (String?) -> Void) {
        reply(engine.prepareForRemoval())
        // Unregistering only removes the launchd job; observed behaviour is that
        // the already-running process keeps going, leaving a root daemon alive
        // after the user thought they removed it. Exit ourselves, after a beat
        // so the reply above is actually delivered.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            Logger(subsystem: DaemonConstants.machServiceName, category: "xpc")
                .notice("Exiting after removal request")
            exit(0)
        }
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
    private let clientRequirement: String
    private let log = Logger(subsystem: DaemonConstants.machServiceName, category: "xpc")

    init(engine: SchedulerEngine) {
        self.engine = engine
        // Computed once: reading our own signature per connection would be
        // wasted work, and the answer cannot change while we run.
        self.clientRequirement = CodeSigningRequirement.forApp()
    }

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Must be set before resume(), and only once per connection. A client
        // that fails the requirement has its connection invalidated by XPC
        // rather than reaching DaemonService.
        newConnection.setCodeSigningRequirement(clientRequirement)
        newConnection.exportedInterface = NSXPCInterface(with: WakeDaemonProtocol.self)
        newConnection.exportedObject = DaemonService(engine: engine)
        newConnection.resume()
        log.notice("Accepted XPC connection from pid \(newConnection.processIdentifier)")
        return true
    }
}
