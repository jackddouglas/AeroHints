import AppKit
import SwiftUI

/// A borderless, floating NSPanel with native vibrancy blur.
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.transient, .fullScreenAuxiliary, .canJoinAllSpaces]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false

        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Set the SwiftUI content view with a vibrancy background.
    func setContent<V: View>(_ view: V) {
        let hostingView = NSHostingView(rootView: view.ignoresSafeArea())

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        visualEffect.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        contentView = visualEffect
    }

    /// Center the panel on the screen containing the mouse cursor.
    func centerOnScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let screen else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = frame.size
        let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - panelSize.height) / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Resize the panel to fit its content, then re-center.
    func sizeToFitContent() {
        guard let contentView else { return }
        let fittingSize = contentView.fittingSize
        setFrame(NSRect(origin: frame.origin, size: fittingSize), display: true)
        centerOnScreen()
    }
}
