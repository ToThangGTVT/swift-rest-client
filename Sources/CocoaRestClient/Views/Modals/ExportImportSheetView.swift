//
//  ExportImportSheetView.swift
//  CocoaRestClient
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

            Text("Export your collections to JSON, or import existing collections from Postman, OpenAPI / Swagger, or CocoaRestClient.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            HStack(spacing: 16) {
                // 1. Export Card
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)

                    Text("Export")
                        .fontWeight(.semibold)

                    Text("\(savedVM.rootFolder.totalRequestCount) requests in collection")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Export JSON...") {
                        exportRequests()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
                .frame(width: 170, height: 180)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // 2. Postman Import Card
                VStack(spacing: 10) {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)

                    Text("Postman (v2.1)")
                        .fontWeight(.semibold)

                    Text("Import Postman collection JSON")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Import Postman...") {
                        importFile(type: .postman)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
                }
                .padding(12)
                .frame(width: 170, height: 180)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // 3. OpenAPI / Swagger Import Card
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.green)

                    Text("OpenAPI / Swagger")
                        .fontWeight(.semibold)

                    Text("Import OpenAPI 3.0 / Swagger JSON")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Import OpenAPI...") {
                        importFile(type: .openApi)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                }
                .padding(12)
                .frame(width: 170, height: 180)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }

            if let msg = importStatusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(isError ? .red : .green)
                    .padding(.top, 4)
            }

            Divider()

            HStack {
                Button("Auto-Detect File...") {
                    importFile(type: .auto)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 580, height: 360)
    }

    private enum ImportType {
        case auto, postman, openApi
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

    private func importFile(type: ImportType) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url) else {
                importStatusMessage = "Failed to read file at \(url.lastPathComponent)"
                isError = true
                return
            }

            do {
                let folder: RequestFolder
                switch type {
                case .postman:
                    folder = try PostmanImporter.importCollection(from: data)
                case .openApi:
                    folder = try OpenAPIImporter.importSpecification(from: data)
                case .auto:
                    if let f = try? SavedRequestsStore.shared.importFolder(from: url) {
                        folder = f
                    } else if let f = try? PostmanImporter.importCollection(from: data) {
                        folder = f
                    } else if let f = try? OpenAPIImporter.importSpecification(from: data) {
                        folder = f
                    } else {
                        throw NSError(domain: "Import", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unrecognized collection format"])
                    }
                }

                savedVM.rootFolder.append(.folder(folder))
                savedVM.persist()
                importStatusMessage = "Successfully imported \"\(folder.name)\" (\(folder.totalRequestCount) requests)"
                isError = false
            } catch {
                importStatusMessage = "Import failed: \(error.localizedDescription)"
                isError = true
            }
        }
    }
}
