//
//  FastSearchSheetView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct FastSearchSheetView: View {
    @ObservedObject public var savedVM: SavedRequestsViewModel
    public var onSelect: (RestRequest) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0

    public init(savedVM: SavedRequestsViewModel, onSelect: @escaping (RestRequest) -> Void) {
        self.savedVM = savedVM
        self.onSelect = onSelect
    }

    private var results: [(path: String, request: RestRequest)] {
        let all = savedVM.rootFolder.allRequests()
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.request.name.localizedCaseInsensitiveContains(query) ||
            $0.request.url.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.secondary)

                TextField("Quick Open Request (Cmd+O)...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit {
                        if !results.isEmpty && selectedIndex < results.count {
                            onSelect(results[selectedIndex].request)
                            dismiss()
                        }
                    }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)

            Divider()

            // Results List
            if results.isEmpty {
                VStack(spacing: 8) {
                    Text("No matching requests found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(0..<results.count, id: \.self) { idx in
                    let item = results[idx]
                    Button(action: {
                        onSelect(item.request)
                        dismiss()
                    }) {
                        HStack(spacing: 10) {
                            Text(item.request.method.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(methodColor(item.request.method).opacity(0.2))
                                .foregroundColor(methodColor(item.request.method))
                                .cornerRadius(4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.request.name)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("\(item.path) • \(item.request.url)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            HStack {
                Text("Press Return to open, Esc to dismiss")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 540, height: 380)
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
