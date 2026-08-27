//
//  ExportImportSheetView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore
import UniformTypeIdentifiers
import AppKit

public struct ExportImportSheetView: View {
    @ObservedObject public var savedVM: SavedRequestsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var importStatusMessage: String?
    @State private var isError: Bool = false

    public init(savedVM: SavedRequestsViewModel) {
        self.savedVM = savedVM
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Import & Export Collections")
                .font(.headline)

            Text("Export your saved requests collection to JSON for backup or team sharing, or import an existing collection file.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 20) {
                // Export Card
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)

                    Text("Export Requests")
                        .fontWeight(.semibold)

                    Text("\(savedVM.rootFolder.totalRequestCount) total requests in collection")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Export to JSON...") {
                        exportRequests()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(width: 200, height: 180)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // Import Card
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)

                    Text("Import Requests")
                        .fontWeight(.semibold)

                    Text("Supports JSON collections")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Import File...") {
                        importRequests()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(width: 200, height: 180)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }

            if let msg = importStatusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(isError ? .red : .green)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500, height: 340)
    }

    private func exportRequests() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "CocoaRestClient-Collection.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try SavedRequestsStore.shared.exportFolder(savedVM.rootFolder, to: url)
                importStatusMessage = "Successfully exported to \(url.lastPathComponent)"
                isError = false
            } catch {
                importStatusMessage = "Export failed: \(error.localizedDescription)"
                isError = true
            }
        }
    }

    private func importRequests() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let importedFolder = try SavedRequestsStore.shared.importFolder(from: url)
                savedVM.rootFolder.append(.folder(importedFolder))
                savedVM.persist()
                importStatusMessage = "Successfully imported \(importedFolder.name) (\(importedFolder.totalRequestCount) requests)"
                isError = false
            } catch {
                importStatusMessage = "Import failed: \(error.localizedDescription)"
                isError = true
            }
        }
    }
}
