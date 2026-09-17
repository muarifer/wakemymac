// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

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
