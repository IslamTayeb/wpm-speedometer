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
            HStack(spacing: 2) {
                Text("\(Int(wpmManager.currentWPM))")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text("WPM")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}
