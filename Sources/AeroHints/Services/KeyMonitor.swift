import AppKit
import Combine

/// Monitors for right command + option key hold to trigger showing the overlay.
final class KeyMonitor {
    private var globalMonitor: Any?
    private var holdTimer: DispatchWorkItem?
    private var holdTriggered = false
    private let holdDelay: TimeInterval
    private var pressedKeyCodes: Set<UInt16> = []

    let onHoldTriggered = PassthroughSubject<Void, Never>()
    let onReleased = PassthroughSubject<Void, Never>()

    private static let rightOptionKeyCode: UInt16 = 61
    private static let rightCommandKeyCode: UInt16 = 54
    private static let activationKeyCodes: Set<UInt16> = [rightOptionKeyCode, rightCommandKeyCode]

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
        updatePressedKeyCodes(with: event)

        if Self.activationKeyCodes.isSubset(of: pressedKeyCodes) {
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

    /// Device-specific modifier flag bits from IOKit (NX_DEVICE* masks).
    /// These distinguish right-side modifiers from left-side, unlike the
    /// aggregate `.command` / `.option` flags on NSEvent.ModifierFlags.
    private static let deviceRightCommandMask: UInt64 = 0x0000_0010
    private static let deviceRightOptionMask: UInt64 = 0x0000_0040

    private func updatePressedKeyCodes(with event: NSEvent) {
        guard let cgEvent = event.cgEvent else { return }
        let rawFlags = cgEvent.flags.rawValue

        updatePressedKey(Self.rightCommandKeyCode, isDown: (rawFlags & Self.deviceRightCommandMask) != 0)
        updatePressedKey(Self.rightOptionKeyCode, isDown: (rawFlags & Self.deviceRightOptionMask) != 0)
    }

    private func updatePressedKey(_ keyCode: UInt16, isDown: Bool) {
        if isDown {
            pressedKeyCodes.insert(keyCode)
        } else {
            pressedKeyCodes.remove(keyCode)
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
