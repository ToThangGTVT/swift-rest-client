//
//  CloneWorkspaceSheetView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct CloneWorkspaceSheetView: View {
    @ObservedObject public var wsManagerVM = WorkspaceManagerViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var repoUrl: String = ""
    @State private var branch: String = ""
    @State private var targetDir: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clone Git Repository as Workspace")
                        .font(.headline)
                    Text("Download and link an existing REST Client / API workspace from GitHub, GitLab, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL *")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("https://github.com/organization/api-workspace.git", text: $repoUrl)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Branch (Optional, defaults to main)")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("main", text: $branch)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let msg = wsManagerVM.syncStatusMessage {
                HStack {
                    Image(systemName: wsManagerVM.syncIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(wsManagerVM.syncIsError ? .red : .green)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(wsManagerVM.syncIsError ? .red : .primary)
                    Spacer()
                }
                .padding(8)
                .background(wsManagerVM.syncIsError ? Color.red.opacity(0.1) : Color.green.opacity(0.08))
                .cornerRadius(6)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Clone Workspace") {
                    Task {
                        let success = await wsManagerVM.cloneWorkspace(
                            repoUrl: repoUrl,
                            branch: branch.isEmpty ? nil : branch
                        )
                        if success {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || wsManagerVM.isSyncing)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
