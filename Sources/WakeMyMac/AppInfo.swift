import AppKit
import WakeCore

enum AppInfo {
    /// Bundle version when running from WakeMyMac.app; falls back to the
    /// shared constant when running the bare binary during development.
    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? DaemonConstants.version
    }

    /// Menu bar symbol: our own template image from the bundle, falling back to
    /// an SF Symbol when running the bare binary outside the .app.
    static var menuBarImage: NSImage {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        return NSImage(systemSymbolName: "clock.badge.checkmark",
                       accessibilityDescription: "WakeMyMac")!
    }

    @MainActor
    static func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: L10n.aboutCredits + "\ngithub.com/muarifer/wakemymac · MIT",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "WakeMyMac",
            .applicationVersion: version,
            .credits: credits,
        ])
    }
}
