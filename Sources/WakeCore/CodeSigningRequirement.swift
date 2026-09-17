import Foundation
import Security
import os

/// Code signing requirements that pin both ends of the XPC connection.
///
/// The daemon needs this because a Mach service in the system domain is
/// reachable by every local process: without a requirement, anything running on
/// the Mac could schedule a shutdown or wipe the user's rules. The app uses it
/// so it will only talk to a daemon signed by us.
public enum CodeSigningRequirement {
    private static let log = Logger(subsystem: DaemonConstants.machServiceName, category: "codesign")

    /// Requirement the menu bar app must satisfy (used by the daemon).
    public static func forApp() -> String {
        pinned(identifier: DaemonConstants.appBundleID)
    }

    /// Requirement the daemon must satisfy (used by the app).
    public static func forDaemon() -> String {
        pinned(identifier: DaemonConstants.machServiceName)
    }

    /// Mirrors how the calling binary itself was signed. A Developer ID build
    /// pins the peer to the same team; an ad-hoc local build has no team to pin,
    /// so it can only require a matching identifier — otherwise a plain
    /// `./build.sh` result could never talk to the daemon it ships with.
    ///
    /// Built only from compile-time constants and a team identifier read out of
    /// our own signature, never from anything a peer sends:
    /// `setCodeSigningRequirement` raises an uncatchable exception on a
    /// malformed requirement string.
    private static func pinned(identifier: String) -> String {
        guard let team = ownTeamIdentifier(), isPlausibleTeamID(team) else {
            log.warning("No Developer ID team in own signature; pinning by identifier only (development build)")
            return "identifier \"\(identifier)\""
        }
        return "anchor apple generic and identifier \"\(identifier)\""
            + " and certificate leaf[subject.OU] = \"\(team)\""
    }

    /// Apple team identifiers are 10 alphanumeric characters. Checked so an
    /// unexpected value can never produce a malformed requirement string.
    private static func isPlausibleTeamID(_ team: String) -> Bool {
        team.count == 10 && team.allSatisfy { $0.isLetter || $0.isNumber }
    }

    private static func ownTeamIdentifier() -> String? {
        var selfCode: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &selfCode) == errSecSuccess,
              let selfCode
        else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode
        else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
                staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any]
        else { return nil }

        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
