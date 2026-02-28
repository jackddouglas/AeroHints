import Foundation

/// Queries the aerospace CLI for modes and bindings.
final class AerospaceConfig {
    private let binaryPath: String

    init() {
        let candidates = [
            "/etc/profiles/per-user/\(NSUserName())/bin/aerospace",
            "/usr/local/bin/aerospace",
            "/opt/homebrew/bin/aerospace",
        ]
        self.binaryPath = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? "aerospace"
    }

    /// Load all modes and their bindings from the running aerospace config.
    func loadModes() -> [Mode] {
        let modeNames = fetchModeNames()
        return modeNames.compactMap { loadMode(name: $0) }
    }

    // MARK: - Private

    private func fetchModeNames() -> [String] {
        guard let output = runAerospace(["list-modes", "--json"]),
              let data = output.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else {
            NSLog("AeroHints: Failed to fetch mode names, falling back to [main]")
            return ["main"]
        }
        return array.compactMap { $0["mode-id"] }
    }

    private func loadMode(name: String) -> Mode? {
        guard let output = runAerospace(["config", "--get", "mode.\(name).binding", "--json"]),
              let data = output.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            NSLog("AeroHints: Failed to load bindings for mode '%@'", name)
            return nil
        }

        let bindings = dict.compactMap { (key, value) -> KeyBinding? in
            parseBinding(key: key, rawValue: value, modeName: name)
        }
        let collapsed = collapseBindings(bindings).sorted { $0.displayKey < $1.displayKey }

        let displayName = name == "main" ? "Main" : name.capitalized
        return Mode(id: name, name: displayName, bindings: collapsed)
    }

    private func parseBinding(key: String, rawValue: String, modeName: String) -> KeyBinding? {
        let commands = rawValue.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }

        // Filter out noise: sketchybar triggers, AeroHints notifications, bare "mode main"
        let meaningful = commands.filter { cmd in
            !cmd.contains("sketchybar --trigger") &&
            !cmd.contains("AeroHints") &&
            cmd != "mode main"
        }

        let displayLabel: String
        let category: BindingCategory

        if meaningful.isEmpty {
            // Pure exit binding (esc/enter) — only show in sub-modes
            if modeName == "main" { return nil }
            displayLabel = "Back to Main"
            category = .modes
        } else {
            (displayLabel, category) = classifyCommand(meaningful[0])
        }

        return KeyBinding(
            key: key,
            displayKey: formatKey(key),
            displayLabel: displayLabel,
            category: category
        )
    }

    // MARK: - Collapsing redundant bindings

    /// Groups bindings that follow numeric (0-9) or directional (h/j/k/l) patterns
    /// into single representative rows.
    private func collapseBindings(_ bindings: [KeyBinding]) -> [KeyBinding] {
        // Group by (category, modifier prefix)
        // e.g. all "⌥0"..."⌥9" share category=.workspaces and modifier prefix="⌥"
        var groups: [String: [KeyBinding]] = [:]
        var ungrouped: [KeyBinding] = []

        for binding in bindings {
            let (prefix, suffix) = splitModifierAndKey(binding.key)
            let isNumeric = suffix.count == 1 && suffix.first?.isNumber == true
            let isDirectional = ["h", "j", "k", "l"].contains(suffix)

            if isNumeric || isDirectional {
                let groupKey = "\(binding.category.rawValue)|\(prefix)|\(isNumeric ? "num" : "dir")"
                groups[groupKey, default: []].append(binding)
            } else {
                ungrouped.append(binding)
            }
        }

        var result = ungrouped

        for (_, group) in groups {
            if group.count >= 4 {
                // Collapse this group into one representative binding
                if let collapsed = collapseGroup(group) {
                    result.append(collapsed)
                } else {
                    result.append(contentsOf: group)
                }
            } else {
                result.append(contentsOf: group)
            }
        }

        return result
    }

    /// Split a raw key like "alt-shift-h" into modifier prefix ("alt-shift") and key suffix ("h").
    private func splitModifierAndKey(_ key: String) -> (prefix: String, suffix: String) {
        let modifiers = Set(["alt", "shift", "ctrl", "cmd"])
        let parts = key.split(separator: "-").map(String.init)
        var modParts: [String] = []
        var keyPart = ""

        for part in parts {
            if modifiers.contains(part) {
                modParts.append(part)
            } else {
                keyPart = part
            }
        }
        return (modParts.joined(separator: "-"), keyPart)
    }

    /// Collapse a group of bindings (e.g. Workspace 0-9) into a single row.
    private func collapseGroup(_ group: [KeyBinding]) -> KeyBinding? {
        guard let first = group.first else { return nil }
        let (prefix, suffix) = splitModifierAndKey(first.key)

        let isNumeric = suffix.count == 1 && suffix.first?.isNumber == true
        let formattedPrefix = prefix.isEmpty ? "" : formatKey(prefix + "-_").dropLast()
        // formatKey on "alt-shift-_" gives "⌥⇧_", we drop the trailing placeholder

        if isNumeric {
            // Numeric group: "⌥0-9" with label like "Workspace 0-9"
            let displayKey = "\(formattedPrefix)0-9"
            let baseLabel = collapseNumericLabel(group)
            return KeyBinding(
                key: first.key,
                displayKey: displayKey,
                displayLabel: baseLabel,
                category: first.category
            )
        } else {
            // Directional group: "⌥H/J/K/L" with label like "Focus Direction"
            let displayKey = "\(formattedPrefix)H/J/K/L"
            let baseLabel = collapseDirectionalLabel(group)
            return KeyBinding(
                key: first.key,
                displayKey: displayKey,
                displayLabel: baseLabel,
                category: first.category
            )
        }
    }

    /// Find common prefix in numeric group labels.
    /// e.g. ["Workspace 0", "Workspace 1", ...] → "Workspace 0-9"
    private func collapseNumericLabel(_ group: [KeyBinding]) -> String {
        // Find the shared label prefix before the number
        let labels = group.map(\.displayLabel)
        guard let first = labels.first else { return "" }

        // Try to find where the number starts at the end
        var prefixEnd = first.endIndex
        for char in first.reversed() {
            if char.isNumber || char == " " {
                prefixEnd = first.index(before: prefixEnd)
            } else {
                break
            }
        }

        let commonPrefix = String(first[first.startIndex...prefixEnd]).trimmingCharacters(in: .whitespaces)
        return "\(commonPrefix) 0-9"
    }

    /// Derive a collapsed label for directional groups.
    /// e.g. ["Focus Left", "Focus Right", "Focus Up", "Focus Down"] → "Focus H/J/K/L"
    private func collapseDirectionalLabel(_ group: [KeyBinding]) -> String {
        let labels = group.map(\.displayLabel)
        let directions = Set(["Left", "Right", "Up", "Down"])

        // Find common prefix by stripping direction words
        for label in labels {
            let words = label.split(separator: " ").map(String.init)
            let prefix = words.filter { !directions.contains($0) }.joined(separator: " ")
            if !prefix.isEmpty {
                return "\(prefix) H/J/K/L"
            }
        }

        return labels.first ?? ""
    }

    // MARK: - Command classification

    private func classifyCommand(_ command: String) -> (label: String, category: BindingCategory) {
        // App launch: exec-and-forget open -a 'AppName'
        if command.contains("open -a") {
            let appName = command
                .replacingOccurrences(of: "exec-and-forget", with: "")
                .replacingOccurrences(of: "open -a", with: "")
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            return (appName, .apps)
        }

        // Directory open: exec-and-forget open <path>
        if command.hasPrefix("exec-and-forget") && command.contains("open ") && !command.contains("open -a") {
            let path = command
                .replacingOccurrences(of: "exec-and-forget", with: "")
                .replacingOccurrences(of: "open ", with: "")
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "\\ ", with: " ")
            return (friendlyPathName(path), .navigation)
        }

        // Focus
        if command.hasPrefix("focus") {
            let direction = command
                .replacingOccurrences(of: "focus --boundaries-action wrap-around-the-workspace ", with: "")
                .replacingOccurrences(of: "focus ", with: "")
                .capitalized
            return ("Focus \(direction)", .focus)
        }

        // Move window
        if command.hasPrefix("move left") || command.hasPrefix("move right")
            || command.hasPrefix("move up") || command.hasPrefix("move down")
        {
            let direction = command.replacingOccurrences(of: "move ", with: "").capitalized
            return ("Move \(direction)", .move)
        }

        // Move node to workspace
        if command.hasPrefix("move-node-to-workspace") {
            let ws = command
                .replacingOccurrences(of: "move-node-to-workspace ", with: "")
                .replacingOccurrences(of: " --focus-follows-window", with: "")
            return ("Move to WS \(ws)", .workspaces)
        }

        // Move workspace to monitor
        if command.hasPrefix("move-workspace-to-monitor") {
            return ("Move WS to Next Monitor", .workspaces)
        }

        // Workspace switch
        if command.hasPrefix("workspace") && !command.contains("move") {
            if command == "workspace-back-and-forth" {
                return ("Previous Workspace", .workspaces)
            }
            let ws = command.replacingOccurrences(of: "workspace ", with: "")
            return ("Workspace \(ws)", .workspaces)
        }

        // Layout
        if command.hasPrefix("layout") {
            if command.contains("tiles") { return ("Tiling Layout", .layout) }
            if command.contains("accordion") { return ("Accordion Layout", .layout) }
            if command.contains("floating") { return ("Toggle Floating", .layout) }
            return ("Layout", .layout)
        }

        // Simple command mappings
        let simpleCommands: [String: (String, BindingCategory)] = [
            "fullscreen": ("Fullscreen", .layout),
            "balance-sizes": ("Balance Sizes", .layout),
            "flatten-workspace-tree": ("Flatten Tree", .layout),
            "close-all-windows-but-current": ("Close Other Windows", .other),
            "reload-config": ("Reload Config", .other),
        ]
        if let match = simpleCommands[command] { return match }

        // Resize
        if command.hasPrefix("resize") {
            let parts = command.replacingOccurrences(of: "resize ", with: "")
            return ("Resize \(parts)", .layout)
        }

        // Sketchybar
        if command.contains("sketchybar") {
            if command.contains("--reload") { return ("Reload Sketchybar", .other) }
            return ("Sketchybar", .other)
        }

        // Mode switch
        if command.hasPrefix("mode ") {
            let mode = command.replacingOccurrences(of: "mode ", with: "").capitalized
            return ("\(mode) Mode", .modes)
        }

        // Join
        if command.hasPrefix("join-with") {
            let direction = command.replacingOccurrences(of: "join-with ", with: "").capitalized
            return ("Join \(direction)", .layout)
        }

        return (command, .other)
    }

    // MARK: - Path display names

    private func friendlyPathName(_ path: String) -> String {
        if path == "~" || path == "/" + NSHomeDirectory() { return "Home" }
        if path == "/" { return "Computer" }

        let knownPaths: [(String, String)] = [
            ("~/Desktop", "Desktop"),
            ("~/Downloads", "Downloads"),
            ("~/Documents", "Documents"),
            ("~/Library/Mobile Documents/com~apple~CloudDocs", "iCloud Drive"),
            ("~/Library/Mobile\\ Documents/com~apple~CloudDocs", "iCloud Drive"),
        ]
        for (known, name) in knownPaths {
            if path.contains(known) { return name }
        }

        // CloudStorage providers
        if path.contains("CloudStorage") {
            let providers: [(String, String)] = [
                ("ProtonDrive", "Proton Drive"),
                ("GoogleDrive", "Google Drive"),
                ("OneDrive", "OneDrive"),
                ("Dropbox", "Dropbox"),
            ]
            for (key, name) in providers {
                if path.contains(key) { return name }
            }
        }

        // Fall back to last path component
        let lastComponent = (path as NSString).lastPathComponent
        if !lastComponent.isEmpty && lastComponent != "~" {
            return lastComponent
        }
        return path
    }

    // MARK: - Key formatting

    private func formatKey(_ key: String) -> String {
        let parts = key.split(separator: "-").map(String.init)
        var modifiers: [String] = []
        var keyPart = ""

        for part in parts {
            switch part {
            case "alt": modifiers.append("⌥")
            case "shift": modifiers.append("⇧")
            case "ctrl": modifiers.append("⌃")
            case "cmd": modifiers.append("⌘")
            default: keyPart = formatKeyName(part)
            }
        }

        let modStr = modifiers.joined()
        return modStr.isEmpty ? keyPart : "\(modStr) \(keyPart)"
    }

    private static let keyNameMap: [String: String] = [
        "enter": "↩", "esc": "⎋", "tab": "⇥", "space": "␣",
        "backspace": "⌫", "delete": "⌦", "slash": "/", "comma": ",",
        "semicolon": ";", "period": ".", "left": "←", "right": "→",
        "up": "↑", "down": "↓",
    ]

    private func formatKeyName(_ name: String) -> String {
        Self.keyNameMap[name] ?? name.uppercased()
    }

    // MARK: - Process execution

    private func runAerospace(_ args: [String], timeout: TimeInterval = 5) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            NSLog("AeroHints: Failed to run aerospace %@: %@", args.joined(separator: " "), error.localizedDescription)
            return nil
        }

        // Timeout: terminate if process hangs
        let deadline = DispatchTime.now() + timeout
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if process.isRunning {
                NSLog("AeroHints: aerospace process timed out after %.0fs, terminating", timeout)
                process.terminate()
            }
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            NSLog("AeroHints: aerospace %@ exited with status %d: %@",
                  args.joined(separator: " "), process.terminationStatus, errStr)
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
