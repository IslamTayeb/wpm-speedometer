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

    // MonkeyType algorithm variables
    private var currentKeypressCount: Int = 0
    private var timer: Timer?
    private let intervalMs: TimeInterval = 1.0 // 1 second intervals

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
        print("WPM monitoring stopped")
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: intervalMs, repeats: true) { [weak self] _ in
            self?.calculateWPM()
        }

        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// MonkeyType's exact per-second Raw WPM calculation
    private func calculateWPM() {
        // Raw WPM = (keypresses_in_second ÷ 5) × 60
        let rawWPM = Double((currentKeypressCount * 60) / 5)
        currentWPM = rawWPM

        // Reset counter for next second
        currentKeypressCount = 0

        print("WPM: \(Int(rawWPM))")
    }

    /// Core input method - call this on every keystroke
    private func onKeystroke() {
        guard isMonitoring else { return }
        currentKeypressCount += 1
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

        // Count this keystroke
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
