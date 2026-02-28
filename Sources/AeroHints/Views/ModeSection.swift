import SwiftUI

/// A section showing bindings for one category within a mode.
struct ModeSection: View {
    let title: String
    let bindings: [KeyBinding]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .default).weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)

            ForEach(bindings) { binding in
                BindingRow(binding: binding)
            }
        }
    }
}
