//
//  KeyValueEditorTable.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct KeyValueEditorTable: View {
    @Binding public var items: [KeyValuePair]
    public var keyPlaceholder: String
    public var valuePlaceholder: String
    public var commonKeys: [String]

    public init(
        items: Binding<[KeyValuePair]>,
        keyPlaceholder: String = "Key",
        valuePlaceholder: String = "Value",
        commonKeys: [String] = []
    ) {
        self._items = items
        self.keyPlaceholder = keyPlaceholder
        self.valuePlaceholder = valuePlaceholder
        self.commonKeys = commonKeys
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header bar
            HStack {
                Text("\(items.count) item(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: addRow) {
                    Label("Add Row", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !items.isEmpty {
                    Button("Clear All", role: .destructive) {
                        items.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            // Table list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach($items) { $item in
                        HStack(spacing: 8) {
                            Toggle("", isOn: $item.isEnabled)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .frame(width: 20)

                            TextField(keyPlaceholder, text: $item.key)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            TextField(valuePlaceholder, text: $item.value)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            Button(action: { deleteItem(item.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Delete Row")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }

                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Text("No items added yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Add First Item", action: addRow)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func addRow() {
        items.append(KeyValuePair(key: "", value: "", isEnabled: true))
    }

    private func deleteItem(_ id: UUID) {
        items.removeAll(where: { $0.id == id })
    }
}
