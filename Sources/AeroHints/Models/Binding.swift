import Foundation

/// A single keyboard binding: a key combination and what it does.
struct KeyBinding: Identifiable {
    let id = UUID()
    let key: String         // raw key from aerospace, e.g. "alt-h", "h", "esc"
    let displayKey: String  // formatted for display, e.g. "⌥H", "H", "⎋"
    let displayLabel: String // human-readable action, e.g. "Focus Left", "Home"
    let category: BindingCategory
}

enum BindingCategory: String, CaseIterable {
    case apps = "Apps"
    case focus = "Focus"
    case move = "Move"
    case workspaces = "Workspaces"
    case layout = "Layout"
    case modes = "Modes"
    case navigation = "Navigation"
    case other = "Other"
}
