// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import Foundation
import ServiceManagement
import SwiftUI
import WakeCore

@MainActor
final class AppState: ObservableObject {
    @Published var rules: [Rule] = []
    @Published var scheduledEvents: [ScheduledEventInfo] = []
    @Published var daemonVersion: String?
    @Published var daemonStatus: SMAppService.Status = .notFound
    @Published var lastError: String?
    @Published var launchAtLogin = false

    private let client = DaemonClient()
    private let daemonService = SMAppService.daemon(plistName: DaemonConstants.daemonPlistName)

    var daemonReachable: Bool { daemonVersion != nil }

    var nextEvent: ScheduledEventInfo? {
        scheduledEvents.min(by: { $0.date < $1.date })
    }

    var daemonStatusDescription: String {
        switch daemonStatus {
        case .enabled:
            return daemonReachable ? L10n.statusRunning : L10n.statusNotResponding
        case .requiresApproval: return L10n.statusWaitingApproval
        case .notRegistered: return L10n.statusNotInstalled
        case .notFound: return L10n.statusNotFound
        @unknown default: return L10n.statusUnknown
        }
    }

    func refresh() async {
        daemonStatus = daemonService.status
        launchAtLogin = SMAppService.mainApp.status == .enabled
        daemonVersion = await client.ping()
        if daemonReachable {
            rules = await client.fetchRules() ?? rules
            scheduledEvents = await client.fetchScheduledEvents() ?? []
        }
    }

    func saveRules(_ newRules: [Rule]) async {
        rules = newRules
        lastError = await client.pushRules(newRules)
        if lastError == nil {
            scheduledEvents = await client.fetchScheduledEvents() ?? []
        }
    }

    func toggleRule(_ rule: Rule) async {
        var updated = rules
        guard let idx = updated.firstIndex(where: { $0.id == rule.id }) else { return }
        updated[idx].enabled.toggle()
        await saveRules(updated)
    }

    func deleteRule(_ rule: Rule) async {
        await saveRules(rules.filter { $0.id != rule.id })
    }

    func upsertRule(_ rule: Rule) async {
        var updated = rules
        if let idx = updated.firstIndex(where: { $0.id == rule.id }) {
            updated[idx] = rule
        } else {
            updated.append(rule)
        }
        await saveRules(updated)
    }

    // MARK: - Daemon lifecycle

    func installDaemon() async {
        do {
            try daemonService.register()
        } catch {
            // requiresApproval also lands here; send the user to Settings.
            lastError = error.localizedDescription
        }
        if daemonService.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        await refresh()
    }

    /// Order matters: the daemon must unwind its power events while it is still
    /// running. Unregistering first would stop the process and strand whatever
    /// it had already registered with powerd.
    func uninstallDaemon() async {
        if daemonReachable, let error = await client.prepareForRemoval() {
            lastError = error
        }
        do {
            try await daemonService.unregister()
        } catch {
            lastError = error.localizedDescription
        }
        rules = []
        scheduledEvents = []
        await refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
