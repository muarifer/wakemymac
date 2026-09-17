import SwiftUI

@main
struct WakeMyMacApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(state)
                .frame(width: 320)
        } label: {
            Image(nsImage: AppInfo.menuBarImage)
        }
        .menuBarExtraStyle(.window)
    }
}
