import SwiftUI

@main
struct WakeMyMacApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("WakeMyMac", systemImage: "clock.badge.checkmark") {
            MenuView()
                .environmentObject(state)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
}
