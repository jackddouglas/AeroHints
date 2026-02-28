import AppKit
import Combine

/// Monitors for left option key hold to trigger showing the overlay.
final class KeyMonitor {
    private var globalMonitor: Any?
    private var holdTimer: DispatchWorkItem?
    private var holdTriggered = false
    private let holdDelay: TimeInterval

    let onHoldTriggered = PassthroughSubject<Void, Never>()
    let onReleased = PassthroughSubject<Void, Never>()

    private static let leftOptionKeyCode: UInt16 = 58 // kVK_Option

    init(holdDelay: TimeInterval = 0.3) {
        self.holdDelay = holdDelay
    }

    deinit {
        stop()
    }

    func start() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        if globalMonitor == nil {
            NSLog("AeroHints: Failed to register global event monitor. Is Accessibility permission granted?")
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        cancelHoldTimer()
    }

    // MARK: - Private

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == Self.leftOptionKeyCode else { return }

        if event.modifierFlags.contains(.option) {
            holdTriggered = false
            startHoldTimer()
        } else {
            cancelHoldTimer()
            // Only send release if the hold actually triggered the overlay
            if holdTriggered {
                holdTriggered = false
                onReleased.send()
            }
        }
    }

    private func startHoldTimer() {
        cancelHoldTimer()
        let timer = DispatchWorkItem { [weak self] in
            self?.holdTriggered = true
            self?.onHoldTriggered.send()
        }
        holdTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: timer)
    }

    private func cancelHoldTimer() {
        holdTimer?.cancel()
        holdTimer = nil
    }

    /// Check if accessibility permissions are granted. Prompts the user if not.
    static func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
