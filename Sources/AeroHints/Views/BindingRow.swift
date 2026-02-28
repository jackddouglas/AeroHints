import SwiftUI

/// A single row showing a key badge and its action label.
struct BindingRow: View {
    let binding: KeyBinding

    var body: some View {
        HStack(spacing: 8) {
            Text(binding.displayKey)
                .font(.system(.caption, design: .default).weight(.semibold))
                .foregroundStyle(.primary)
                .frame(minWidth: 32)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.white.opacity(0.1))
                )

            Text(binding.displayLabel)
                .font(.system(.body, design: .default))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 1)
    }
}
