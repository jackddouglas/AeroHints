import Foundation

/// A named aerospace mode with its keybindings.
struct Mode: Identifiable {
    let id: String  // mode name: "main", "goto", "resize", "service"
    let name: String // display name
    let bindings: [KeyBinding]

    /// Bindings grouped by category, preserving category order.
    var groupedBindings: [(category: BindingCategory, bindings: [KeyBinding])] {
        var groups: [BindingCategory: [KeyBinding]] = [:]
        for binding in bindings {
            groups[binding.category, default: []].append(binding)
        }
        return BindingCategory.allCases.compactMap { cat in
            guard let bindings = groups[cat], !bindings.isEmpty else { return nil }
            return (category: cat, bindings: bindings)
        }
    }
}
