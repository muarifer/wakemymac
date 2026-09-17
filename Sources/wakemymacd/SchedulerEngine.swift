// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import Foundation
import os
import WakeCore

/// The daemon's core loop: collapse each enabled rule to its next occurrence,
/// register those as one-shot system power events, and re-arm after each event
/// passes. IOPMSchedulePowerEvent has no recurrence, so recurrence lives here.
final class SchedulerEngine {
    private let queue = DispatchQueue(label: "com.muarifer.wakemymac.scheduler")
    private let store: RuleStore
    private let owner = DaemonConstants.powerEventOwner
    private let log = Logger(subsystem: DaemonConstants.machServiceName, category: "engine")

    /// Events must be at least this far in the future or powerd may drop them.
    private let minimumLeadTime: TimeInterval = 60
    /// After the earliest event's time passes, wait this long before
    /// rescheduling, so we compute "next" strictly after the fired occurrence.
    private let rearmDelay: TimeInterval = 30
    /// When enabled rules exist but nothing could be registered, try again on
    /// this interval instead of going silent until the next restart.
    private let retryDelay: TimeInterval = 300

    private var timer: DispatchSourceTimer?
    private var scheduled: [ScheduledEventInfo] = []  // guarded by `queue`

    init(store: RuleStore = RuleStore()) {
        self.store = store
    }

    func start() {
        queue.async { self.reschedule() }
    }

    // MARK: - XPC-facing API (thread-safe)

    func currentRules() -> [Rule] {
        queue.sync { store.load() }
    }

    func updateRules(_ rules: [Rule]) -> String? {
        queue.sync {
            do {
                try store.save(rules)
            } catch {
                log.error("Failed to persist rules: \(error.localizedDescription)")
                return "Failed to persist rules: \(error.localizedDescription)"
            }
            reschedule()
            return nil
        }
    }

    func scheduledEvents() -> [ScheduledEventInfo] {
        queue.sync { scheduled }
    }

    /// Unwinds everything this daemon put into the system: launchd stopping the
    /// process would otherwise leave our already-registered events in powerd,
    /// so the Mac would still shut down at 23:00 with the app long gone.
    func prepareForRemoval() -> String? {
        queue.sync {
            timer?.cancel()
            timer = nil
            PowerEventScheduler.cancelOwnedEvents(owner: owner)
            scheduled = []
            do {
                try store.delete()
            } catch {
                log.error("Could not delete rules file: \(error.localizedDescription)")
                return "Scheduled events were cancelled, but the rules file could not be removed: \(error.localizedDescription)"
            }
            log.info("Prepared for removal: events cancelled and rules deleted")
            return nil
        }
    }

    // MARK: - Scheduling loop (always on `queue`)

    private func reschedule() {
        PowerEventScheduler.cancelOwnedEvents(owner: owner)
        scheduled = []

        let rules = Array(store.load().filter(\.enabled).prefix(Limits.maxRules))
        let floor = Date().addingTimeInterval(minimumLeadTime)

        for rule in rules {
            guard let next = rule.nextOccurrence(after: floor) else {
                log.warning("Rule \(rule.id) has no next occurrence, skipping")
                continue
            }
            do {
                try PowerEventScheduler.schedule(rule.action, at: next, owner: owner)
                scheduled.append(ScheduledEventInfo(
                    date: next, action: rule.action,
                    ruleID: rule.id, ruleLabel: rule.effectiveLabel))
                log.info("Scheduled \(rule.action.rawValue) at \(next, privacy: .public) for rule \(rule.effectiveLabel, privacy: .public)")
            } catch {
                log.error("Could not schedule \(rule.action.rawValue) at \(next): \(String(describing: error))")
            }
        }

        armRearmTimer(hasPendingRules: !rules.isEmpty)
    }

    /// Fires shortly after the earliest scheduled event so that occurrence's
    /// rule gets its *next* one-shot registered. Uses a wall-clock deadline so
    /// the timer still fires promptly after the machine wakes from sleep.
    private func armRearmTimer(hasPendingRules: Bool) {
        timer?.cancel()
        timer = nil

        let delay: TimeInterval
        if let earliest = scheduled.map(\.date).min() {
            delay = earliest.timeIntervalSinceNow + rearmDelay
        } else if hasPendingRules {
            // Enabled rules exist but none reached powerd. Without this the
            // schedule would stay dead until the daemon restarted.
            log.warning("No events registered despite enabled rules; retrying in \(self.retryDelay, privacy: .public)s")
            delay = retryDelay
        } else {
            return
        }

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(wallDeadline: .now() + delay)
        t.setEventHandler { [weak self] in
            self?.log.info("Re-arm timer fired, rescheduling")
            self?.reschedule()
        }
        t.resume()
        timer = t
    }
}
