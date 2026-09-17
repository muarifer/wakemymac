// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import Foundation

public enum DaemonConstants {
    /// launchd label, Mach service name, and daemon plist name all share this.
    public static let machServiceName = "com.muarifer.wakemymac.daemon"
    public static let daemonPlistName = machServiceName + ".plist"
    public static let appBundleID = "com.muarifer.wakemymac"

    /// Owner string attached to every power event we schedule; shows up in
    /// `pmset -g sched` as "scheduled by", and is how we find and cancel our
    /// own events without touching anyone else's.
    public static let powerEventOwner = "com.muarifer.wakemymac"

    /// Where the daemon persists the rule list (root-owned).
    public static let rulesDirectory = "/Library/Application Support/WakeMyMac"
    public static let rulesFileName = "rules.json"

    public static let version = "1.0.0"
}

/// Bounds enforced on anything crossing XPC or coming off disk. Each rule turns
/// into a real system power event, so an unbounded list would flood powerd.
public enum Limits {
    public static let maxRules = 100
    public static let maxLabelLength = 100
    public static let maxPayloadBytes = 256 * 1024
}
