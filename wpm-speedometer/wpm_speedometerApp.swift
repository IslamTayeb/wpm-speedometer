//
//  wpm_speedometerApp.swift
//  wpm-speedometer
//
//  Created by Islam on 8/12/25.
//

import SwiftUI

@main
struct wpm_speedometerApp: App {
    @StateObject private var wpmManager = WPMManager.shared

    init() {
        // Start monitoring when app launches
        Task {
            await MainActor.run {
                WPMManager.shared.startMonitoring()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            EmptyView()
        } label: {
            Text("\(Int(wpmManager.currentWPM)) WPM")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
    }
}
