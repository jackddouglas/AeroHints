import AppKit
import Combine

/// Entry point for AeroHints.
/// --notify: CLI mode to post distributed notifications, then exit.
/// No args: daemon mode as a background agent.
@main
struct AeroHintsApp {
    static func main() {
        let args = CommandLine.arguments

        if args.contains("--notify") {
            handleCLI(args: args)
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private static func handleCLI(args: [String]) {
        guard let notifyIndex = args.firstIndex(of: "--notify"),
              notifyIndex + 1 < args.count
        else {
            fputs("Usage: AeroHints --notify <mode-enter MODE|mode-exit|reload>\n", stderr)
            exit(1)
        }

        let command = args[notifyIndex + 1]

        switch command {
        case "mode-enter":
            guard notifyIndex + 2 < args.count else {
                fputs("Usage: AeroHints --notify mode-enter <mode-name>\n", stderr)
                exit(1)
            }
            NotificationListener.postModeEnter(mode: args[notifyIndex + 2])
        case "mode-exit":
            NotificationListener.postModeExit()
        case "reload":
            NotificationListener.postReload()
        default:
            fputs("Unknown notify command: \(command)\n", stderr)
            exit(1)
        }

        // Brief pause for notification delivery
        Thread.sleep(forTimeInterval: 0.05)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayController?
    private var keyMonitor: KeyMonitor?
    private var notificationListener: NotificationListener?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !KeyMonitor.checkAccessibility() {
            NSLog("AeroHints: Accessibility permission not yet granted. Key hold detection disabled until granted in System Settings.")
        }

        let overlay = OverlayController(showDelay: 0.3)
        let keys = KeyMonitor(holdDelay: 0.3)
        let notifications = NotificationListener()

        keys.onHoldTriggered
            .receive(on: DispatchQueue.main)
            .sink { [weak overlay] in overlay?.requestShowMain() }
            .store(in: &cancellables)

        keys.onReleased
            .receive(on: DispatchQueue.main)
            .sink { [weak overlay] in
                if overlay?.isMainMode == true { overlay?.dismiss() }
            }
            .store(in: &cancellables)

        notifications.onModeEnter
            .receive(on: DispatchQueue.main)
            .sink { [weak overlay] mode in overlay?.requestShowMode(mode) }
            .store(in: &cancellables)

        notifications.onModeExit
            .receive(on: DispatchQueue.main)
            .sink { [weak overlay] in overlay?.dismiss() }
            .store(in: &cancellables)

        notifications.onReload
            .receive(on: DispatchQueue.main)
            .sink { [weak overlay] in overlay?.reloadConfig() }
            .store(in: &cancellables)

        keys.start()
        notifications.start()

        self.overlayController = overlay
        self.keyMonitor = keys
        self.notificationListener = notifications

        NSLog("AeroHints: Daemon started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyMonitor?.stop()
        notificationListener?.stop()
    }
}
