//
//  WPMManager.swift
//  wpm-speedometer
//
//  Created by Islam on 8/12/25.
//

import Foundation
import Cocoa
import CoreGraphics

// MARK: - Simple Live WPM Calculator

@MainActor
class WPMManager: ObservableObject {
    static let shared = WPMManager()

    // Published properties for UI
    @Published var currentWPM: Double = 0
    @Published var isMonitoring: Bool = false

    // High-frequency rolling window variables
    private var keystrokeTimestamps: [CFAbsoluteTime] = []
    private var timer: Timer?
    private let updateInterval: TimeInterval = 0.02 // 50 times per second (20ms)
    private let rollingWindowDuration: TimeInterval = 2.0 // 2 second rolling window

    // System monitoring
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Typing key detection (optimized set lookup)
    private let typingKeyCodes: Set<UInt16> = {
        var keys: Set<UInt16> = Set(0...50) // Most typing keys are in this range

        // Remove non-typing keys
        let excludedKeys: Set<UInt16> = [
            // Modifier keys
            56, 58, 59, 60, 61, 62, 63, 64,
            // Function keys
            122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
            // Arrow keys
            123, 124, 125, 126,
            // Other non-typing
            53, 71, 114, 115, 117, 119, 121,
        ]

        keys.subtract(excludedKeys)
        keys.insert(49) // Include space

        return keys
    }()

    private init() {}

    // MARK: - Core MonkeyType Algorithm

    func startMonitoring() {
        guard !isMonitoring else { return }

        requestAccessibilityPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupEventTap()
                    self?.startTimer()
                    self?.isMonitoring = true
                    print("WPM monitoring started")
                } else {
                    print("Accessibility permission denied")
                }
            }
        }
    }

        func stopMonitoring() {
        guard isMonitoring else { return }

        teardownEventTap()
        stopTimer()
        isMonitoring = false
        currentWPM = 0
        keystrokeTimestamps.removeAll()
        print("WPM monitoring stopped")
    }

        private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.calculateRollingWPM()
        }

        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

        /// High-frequency rolling window WPM calculation (100 updates per second)
    private func calculateRollingWPM() {
        let now = CFAbsoluteTimeGetCurrent()
        let windowStart = now - rollingWindowDuration

        // Remove timestamps outside the 1-second rolling window
        keystrokeTimestamps = keystrokeTimestamps.filter { $0 >= windowStart }

        // Calculate WPM based on keystrokes in the rolling window
        let keystrokesInWindow = keystrokeTimestamps.count
        let words = Double(keystrokesInWindow) / 5.0 // 5 characters = 1 word
        let minutes = rollingWindowDuration / 60.0 // Convert 1 second to minutes
        let rawWPM = words / minutes

        // Update published property
        currentWPM = rawWPM

        // Optional: Less frequent console output to avoid spam
        if Int(now * 10) % 10 == 0 { // Print every 100ms instead of every 10ms
            print("WPM: \(Int(rawWPM)) (from \(keystrokesInWindow) keystrokes)")
        }
    }

    /// Core input method - call this on every keystroke
    private func onKeystroke() {
        guard isMonitoring else { return }

        let now = CFAbsoluteTimeGetCurrent()
        keystrokeTimestamps.append(now)

        // Memory optimization: Keep only recent timestamps (shouldn't be needed due to filtering, but safety)
        let maxTimestamps = 1000 // Theoretical max: 250 WPM = ~21 keystrokes/second = ~21 timestamps
        if keystrokeTimestamps.count > maxTimestamps {
            keystrokeTimestamps.removeFirst(keystrokeTimestamps.count - maxTimestamps)
        }
    }

    // MARK: - Event Handling

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, refcon in
                let manager = Unmanaged<WPMManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleKeyEvent(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func teardownEventTap() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }

        private func handleKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Fast lookup for typing keys only
        guard typingKeyCodes.contains(keyCode) else {
            return Unmanaged.passRetained(event)
        }

        // Check for modifier keys - exclude keyboard shortcuts
        let flags = event.flags

        // Exclude if Command (⌘), Control (⌃), or Option (⌥) is pressed
        if flags.contains(.maskCommand) ||
           flags.contains(.maskControl) ||
           flags.contains(.maskAlternate) {
            return Unmanaged.passRetained(event) // Don't count keyboard shortcuts
        }

        // Count this keystroke only if no modifiers are pressed
        onKeystroke()

        return Unmanaged.passRetained(event)
    }

    // MARK: - Helper Methods

    private func requestAccessibilityPermission(completion: @escaping (Bool) -> Void) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        completion(trusted)
    }
}
