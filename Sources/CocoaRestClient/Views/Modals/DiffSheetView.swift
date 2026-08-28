//
//  DiffSheetView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct DiffSheetView: View {
    @ObservedObject public var workspaceVM: WorkspaceViewModel
    @StateObject private var diffVM = DiffViewModel()
    @Environment(\.dismiss) private var dismiss

    public init(workspaceVM: WorkspaceViewModel) {
        self.workspaceVM = workspaceVM
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: Source Selection
            HStack(spacing: 12) {
                Text("Compare Responses")
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()

                Spacer()

                // Left Tab Picker
                Picker("Left:", selection: $diffVM.leftTabId) {
                    Text("Select Left Tab").tag(Optional<UUID>.none)
                    ForEach(workspaceVM.tabs) { tab in
                        Text(tab.tabTitle).tag(Optional(tab.id))
                    }
                }
                .frame(width: 220)

                // Right Tab Picker
                Picker("Right:", selection: $diffVM.rightTabId) {
                    Text("Select Right Tab").tag(Optional<UUID>.none)
                    ForEach(workspaceVM.tabs) { tab in
                        Text(tab.tabTitle).tag(Optional(tab.id))
                    }
                }
                .frame(width: 220)

                Button("Compare") {
                    diffVM.computeDiff(tabs: workspaceVM.tabs)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Diff Result View
            if diffVM.diffLines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.split.2x1")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Select two tabs with responses above and click Compare.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(diffVM.diffLines) { line in
                            HStack(spacing: 8) {
                                Text(line.leftLineNumber.map { "\($0)" } ?? "")
                                    .frame(width: 35, alignment: .trailing)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Text(line.rightLineNumber.map { "\($0)" } ?? "")
                                    .frame(width: 35, alignment: .trailing)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Text(prefixForType(line.type))
                                    .frame(width: 14)
                                    .fontWeight(.bold)
                                    .foregroundColor(colorForType(line.type))

                                Text(line.text)
                                    .font(.system(size: 12, design: .monospaced))
                                    .lineLimit(1)
                                    .frame(width: textColumnWidth, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(backgroundColorForType(line.type))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(10)
        }
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            // diffVM is observed by this view, so seeding it inline would publish
            // from inside the update that presents the sheet.
            DispatchQueue.main.async {
                if workspaceVM.tabs.count >= 2 {
                    diffVM.leftTabId = workspaceVM.tabs[0].id
                    diffVM.rightTabId = workspaceVM.tabs[1].id
                    diffVM.computeDiff(tabs: workspaceVM.tabs)
                } else if let first = workspaceVM.tabs.first {
                    diffVM.leftTabId = first.id
                }
            }
        }
    }

    /// Width of the diff text column, measured from the longest line.
    ///
    /// The rows sit in a two-axis ScrollView, which proposes no width to its
    /// content: `maxWidth: .infinity` resolves to nothing there and every line
    /// collapses to a single character. Measuring keeps the rows lazy and gives them
    /// all the same width, so the per-line backgrounds line up.
    private var textColumnWidth: CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let advance = ("0" as NSString).size(withAttributes: [.font: font]).width
        let longest = diffVM.diffLines.map(\.text.count).max() ?? 0
        return max(320, CGFloat(longest) * advance + 8)
    }

    private func prefixForType(_ type: DiffLineType) -> String {
        switch type {
        case .inserted: return "+"
        case .deleted: return "-"
        case .unchanged: return " "
        }
    }

    private func colorForType(_ type: DiffLineType) -> Color {
        switch type {
        case .inserted: return .green
        case .deleted: return .red
        case .unchanged: return .secondary
        }
    }

    private func backgroundColorForType(_ type: DiffLineType) -> Color {
        switch type {
        case .inserted: return Color.green.opacity(0.12)
        case .deleted: return Color.red.opacity(0.12)
        case .unchanged: return Color.clear
        }
    }
}
