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
                    .font(.caption)

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
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if historyVM.filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No request history yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(historyVM.filteredItems) { item in
                        Button(action: {
                            onSelectHistoryItem(item.request)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.request.method.rawValue)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(methodColor(item.request.method))
                                        .padding(.horizontal, 4)
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
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(.primary)

                                HStack {
                                    Text(String(format: "%.0f ms", item.latencyMs))
                                    Spacer()
                                    Text(item.formattedSize)
                                }
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 1)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    }
                }
                .listStyle(.sidebar)
                .environment(\.defaultMinListRowHeight, 22)
            }
        }
        .frame(minWidth: 200)
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
