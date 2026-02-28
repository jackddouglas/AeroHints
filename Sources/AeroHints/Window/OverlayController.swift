import AppKit
import SwiftUI

/// Manages the overlay panel lifecycle: show with delay, hide, animations.
@MainActor
final class OverlayController: ObservableObject {
    @Published var currentMode: Mode?
    @Published var isMainMode: Bool = false

    private var panel: OverlayPanel?
    private var clickMonitor: Any?
    private var showTimer: DispatchWorkItem?
    private let showDelay: TimeInterval

    private let config: AerospaceConfig
    private var modes: [String: Mode] = [:]

    enum State {
        case idle
        case waiting
        case visible
    }
    private(set) var state: State = .idle

    init(showDelay: TimeInterval = 0.3) {
        self.showDelay = showDelay
        self.config = AerospaceConfig()
        reloadConfig()
    }

    func reloadConfig() {
        let loadedModes = config.loadModes()
        modes = Dictionary(uniqueKeysWithValues: loadedModes.map { ($0.id, $0) })
    }

    // MARK: - Show / Hide

    func requestShowMode(_ modeName: String) {
        guard let mode = modes[modeName] else { return }
        currentMode = mode
        isMainMode = modeName == "main"
        requestShow()
    }

    func requestShowMain() {
        guard let mode = modes["main"] else { return }
        currentMode = mode
        isMainMode = true
        requestShow()
    }

    func dismiss() {
        cancelShowTimer()
        guard state != .idle else { return }
        state = .idle
        hidePanel()
    }

    // MARK: - Private

    private func requestShow() {
        cancelShowTimer()
        state = .waiting

        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.state == .waiting else { return }
            self.state = .visible
            self.showPanel()
        }
        showTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: timer)
    }

    private func cancelShowTimer() {
        showTimer?.cancel()
        showTimer = nil
    }

    private func showPanel() {
        let overlayView = OverlayView(mode: currentMode, isMainMode: isMainMode)
            .background(.clear)

        if panel == nil {
            panel = OverlayPanel(contentRect: .zero)
        }
        guard let panel else { return }

        panel.setContent(overlayView)
        panel.sizeToFitContent()
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        startClickMonitor()
    }

    private func hidePanel() {
        stopClickMonitor()
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            guard let self, let panel = self.panel else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                DispatchQueue.main.async { self.dismiss() }
            }
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
