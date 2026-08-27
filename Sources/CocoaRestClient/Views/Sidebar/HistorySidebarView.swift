//
//  HistorySidebarView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct HistorySidebarView: View {
    @ObservedObject public var historyVM: HistoryViewModel
    public var onSelectHistoryItem: (RestRequest) -> Void

    public init(
        historyVM: HistoryViewModel = HistoryViewModel.shared,
        onSelectHistoryItem: @escaping (RestRequest) -> Void
    ) {
        self.historyVM = historyVM
        self.onSelectHistoryItem = onSelectHistoryItem
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search & Clear Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("Search history...", text: $historyVM.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                if !historyVM.searchText.isEmpty {
                    Button(action: { historyVM.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: { historyVM.clearAll() }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear History")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if historyVM.filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("No request history yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(historyVM.filteredItems) { item in
                            CompactHistoryRow(
                                item: item,
                                onSelect: { onSelectHistoryItem(item.request) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 200)
    }
}

private struct CompactHistoryRow: View {
    let item: HistoryItem
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.request.method.rawValue)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(methodColor(item.request.method))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(methodColor(item.request.method).opacity(0.15))
                        .cornerRadius(3)

                    Text(item.formattedTime)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(item.statusCode)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(item.statusCode >= 200 && item.statusCode < 300 ? .green : .red)
                }

                Text(item.request.url)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)

                HStack {
                    Text(String(format: "%.0f ms", item.latencyMs))
                    Spacer()
                    Text(item.formattedSize)
                }
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .green
        case .post: return .blue
        case .put: return .orange
        case .delete: return .red
        default: return .gray
        }
    }
}
