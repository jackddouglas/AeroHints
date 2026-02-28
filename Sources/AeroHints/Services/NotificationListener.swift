import Combine
import Foundation

/// Listens for distributed notifications from aerospace (via exec-and-forget)
/// and provides a CLI interface for posting them.
final class NotificationListener {
    static let modeEnterName = NSNotification.Name("com.aerohints.mode.enter")
    static let modeExitName = NSNotification.Name("com.aerohints.mode.exit")
    static let reloadName = NSNotification.Name("com.aerohints.reload")

    let onModeEnter = PassthroughSubject<String, Never>()
    let onModeExit = PassthroughSubject<Void, Never>()
    let onReload = PassthroughSubject<Void, Never>()

    func start() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(handleModeEnter(_:)), name: Self.modeEnterName, object: nil)
        center.addObserver(self, selector: #selector(handleModeExit(_:)), name: Self.modeExitName, object: nil)
        center.addObserver(self, selector: #selector(handleReload(_:)), name: Self.reloadName, object: nil)
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Handlers (called on posting thread, forward to subscribers)

    @objc private func handleModeEnter(_ notification: Notification) {
        let mode = notification.userInfo?["mode"] as? String ?? "main"
        onModeEnter.send(mode)
    }

    @objc private func handleModeExit(_ notification: Notification) {
        onModeExit.send()
    }

    @objc private func handleReload(_ notification: Notification) {
        onReload.send()
    }

    // MARK: - CLI posting (used when binary is invoked with --notify)

    static func postModeEnter(mode: String) {
        DistributedNotificationCenter.default().postNotificationName(
            modeEnterName, object: nil,
            userInfo: ["mode": mode], deliverImmediately: true
        )
    }

    static func postModeExit() {
        DistributedNotificationCenter.default().postNotificationName(
            modeExitName, object: nil,
            userInfo: nil, deliverImmediately: true
        )
    }

    static func postReload() {
        DistributedNotificationCenter.default().postNotificationName(
            reloadName, object: nil,
            userInfo: nil, deliverImmediately: true
        )
    }
}
