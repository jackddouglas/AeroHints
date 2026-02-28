import SwiftUI

/// The main overlay content view.
/// Shows a multi-column grouped layout for main mode,
/// or a single-column list for sub-modes (goto, resize, service).
struct OverlayView: View {
    let mode: Mode?
    let isMainMode: Bool

    private let columnMinWidth: CGFloat = 200

    var body: some View {
        if let mode {
            VStack(spacing: 0) {
                // Header
                Text(isMainMode ? "Keyboard Shortcuts" : "\(mode.name) Mode")
                    .font(.system(.title3, design: .default).weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .opacity(0.3)
                    .padding(.horizontal, 16)

                // Content
                if isMainMode {
                    mainModeContent(mode: mode)
                } else {
                    subModeContent(mode: mode)
                }
            }
            .padding(.bottom, 16)
            .frame(minWidth: isMainMode ? 500 : 260)
        }
    }

    // MARK: - Main mode: multi-column grouped layout

    @ViewBuilder
    private func mainModeContent(mode: Mode) -> some View {
        let groups = mode.groupedBindings

        // Split groups into columns
        let columns = distributeIntoColumns(groups, columnCount: columnsForGroups(groups))

        HStack(alignment: .top, spacing: 24) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(column.enumerated()), id: \.offset) { _, group in
                        ModeSection(
                            title: group.category.rawValue,
                            bindings: group.bindings
                        )
                    }
                }
                .frame(minWidth: columnMinWidth)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Sub-mode: single column

    @ViewBuilder
    private func subModeContent(mode: Mode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(mode.bindings) { binding in
                BindingRow(binding: binding)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Column distribution

    private func columnsForGroups(_ groups: [(category: BindingCategory, bindings: [KeyBinding])]) -> Int {
        let totalBindings = groups.reduce(0) { $0 + $1.bindings.count }
        if totalBindings <= 10 { return 1 }
        if totalBindings <= 25 { return 2 }
        return 3
    }

    private func distributeIntoColumns(
        _ groups: [(category: BindingCategory, bindings: [KeyBinding])],
        columnCount: Int
    ) -> [[(category: BindingCategory, bindings: [KeyBinding])]] {
        guard columnCount > 1 else { return [groups] }

        let totalHeight = groups.reduce(0) { $0 + $1.bindings.count + 2 } // +2 for header spacing
        let targetHeight = totalHeight / columnCount

        var columns: [[(category: BindingCategory, bindings: [KeyBinding])]] = []
        var currentColumn: [(category: BindingCategory, bindings: [KeyBinding])] = []
        var currentHeight = 0

        for group in groups {
            let groupHeight = group.bindings.count + 2
            if currentHeight + groupHeight > targetHeight && !currentColumn.isEmpty
                && columns.count < columnCount - 1
            {
                columns.append(currentColumn)
                currentColumn = []
                currentHeight = 0
            }
            currentColumn.append(group)
            currentHeight += groupHeight
        }

        if !currentColumn.isEmpty {
            columns.append(currentColumn)
        }

        return columns
    }
}
