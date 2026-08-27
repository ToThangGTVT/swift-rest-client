//
//  SaveRequestSheetView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct SaveRequestSheetView: View {
    @ObservedObject public var savedVM: SavedRequestsViewModel
    public var requestToSave: RestRequest
    @Environment(\.dismiss) private var dismiss

    @State private var requestName: String = ""
    @State private var selectedFolderId: UUID? = nil

    public init(savedVM: SavedRequestsViewModel, requestToSave: RestRequest) {
        self.savedVM = savedVM
        self.requestToSave = requestToSave
    }

    private var allFolders: [RequestFolder] {
        var list: [RequestFolder] = []
        func collect(from folder: RequestFolder) {
            list.append(folder)
            for item in folder.items {
                if case .folder(let sub) = item {
                    collect(from: sub)
                }
            }
        }
        collect(from: savedVM.rootFolder)
        return list
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Request")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Request Name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("My API Request", text: $requestName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Save into Folder:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $selectedFolderId) {
                    Text("Root (Top Level)").tag(Optional<UUID>.none)
                    ForEach(allFolders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
                .labelsHidden()
            }

            Divider()

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    var req = requestToSave
                    req.name = requestName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (URL(string: req.url)?.host ?? "Saved Request") : requestName
                    savedVM.addRequest(req, intoFolderId: selectedFolderId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            self.requestName = requestToSave.name == "New Request" ? (URL(string: requestToSave.url)?.host ?? "New Request") : requestToSave.name
        }
    }
}
