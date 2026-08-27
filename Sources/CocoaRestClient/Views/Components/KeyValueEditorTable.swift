//
//  KeyValueEditorTable.swift
//  CocoaRestClient
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
        commonKeys: [String] = CommonHeaders.standardHeaderKeys
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

                // Quick Presets Menu
                if !commonKeys.isEmpty {
                    Menu {
                        ForEach(commonKeys, id: \.self) { preset in
                            Button(preset) {
                                items.append(KeyValuePair(key: preset, value: defaultForPreset(preset), isEnabled: true))
                            }
                        }
                    } label: {
                        Label("Add Preset Header", systemImage: "list.bullet")
                    }
                    .menuStyle(.borderlessButton)
                    .font(.caption)
                }

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

                            // Key field with quick preset menu
                            HStack(spacing: 0) {
                                TextField(keyPlaceholder, text: $item.key)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                if !commonKeys.isEmpty {
                                    Menu {
                                        ForEach(commonKeys.filter { $0 != item.key }, id: \.self) { k in
                                            Button(k) {
                                                item.key = k
                                                if item.value.isEmpty {
                                                    item.value = defaultForPreset(k)
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                    }
                                    .menuStyle(.borderlessButton)
                                    .frame(width: 20)
                                }
                            }

                            // Value field with content-type suggestions when appropriate
                            HStack(spacing: 0) {
                                TextField(valuePlaceholder, text: $item.value)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                if item.key.caseInsensitiveCompare("Content-Type") == .orderedSame ||
                                   item.key.caseInsensitiveCompare("Accept") == .orderedSame {
                                    Menu {
                                        ForEach(CommonHeaders.standardContentTypes, id: \.self) { ct in
                                            Button(ct) {
                                                item.value = ct
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                    }
                                    .menuStyle(.borderlessButton)
                                    .frame(width: 20)
                                }
                            }

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

    private func defaultForPreset(_ key: String) -> String {
        switch key.lowercased() {
        case "content-type": return "application/json"
        case "accept": return "*/*"
        case "accept-encoding": return "gzip, deflate, br"
        case "user-agent": return "CocoaRestClient"
        case "cache-control": return "no-cache"
        default: return ""
        }
    }

    private func addRow() {
        items.append(KeyValuePair(key: "", value: "", isEnabled: true))
    }

    private func deleteItem(_ id: UUID) {
        items.removeAll(where: { $0.id == id })
    }
}
