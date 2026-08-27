//
//  FilesTableView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct FilesTableView: View {
    @Binding public var files: [FileAttachment]

    public init(files: Binding<[FileAttachment]>) {
        self._files = files
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(files.count) file attachment(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: addFile) {
                    Label("Add File", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach($files) { $file in
                        HStack(spacing: 8) {
                            Toggle("", isOn: $file.isEnabled)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                .frame(width: 20)

                            TextField("Field Name", text: $file.key)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)

                            Text(file.fileName.isEmpty ? "No file selected" : file.fileName)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)

                            Button("Browse...") {
                                chooseFile(for: $file)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Toggle("Gzip", isOn: $file.isGzipped)
                                .toggleStyle(.checkbox)
                                .font(.caption)

                            Button(action: { deleteFile(file.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }

                    if files.isEmpty {
                        Text("No file attachments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
            }
        }
    }

    private func addFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            files.append(FileAttachment(key: "file", filePath: url.path, isGzipped: false, isEnabled: true))
        }
    }

    private func chooseFile(for file: Binding<FileAttachment>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            file.wrappedValue.filePath = url.path
        }
    }

    private func deleteFile(_ id: UUID) {
        files.removeAll(where: { $0.id == id })
    }
}
