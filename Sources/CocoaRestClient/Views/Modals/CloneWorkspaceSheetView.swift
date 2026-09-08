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
    @State private var token: String = ""
    @State private var username: String = ""
    @State private var authorName: String = ""
    @State private var authorEmail: String = ""
    @State private var showingAuthAndIdentity: Bool = false

    public init() {}

    private var hasStoredCredentialsForUrl: Bool {
        wsManagerVM.hasStoredCredentials(forRemoteUrl: repoUrl)
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clone Git Repository as Workspace")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Download and link an existing REST Client / API workspace from GitHub, GitLab, etc.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL *")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    TextField("https://github.com/organization/api-workspace.git", text: $repoUrl)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    if hasStoredCredentialsForUrl {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("Saved Keychain credentials will be used for this host")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 1)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Branch (Optional, defaults to main)")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    TextField("main", text: $branch)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                DisclosureGroup(isExpanded: $showingAuthAndIdentity) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Credentials
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personal Access Token (for private repositories)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                TextField("Username (optional)", text: $username)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                    .frame(width: 140)

                                SecureField("ghp_... or access token", text: $token)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                            }
                            Text("Will be saved securely to Keychain for future syncs.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        // Author identity
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name on commits")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                TextField(WorkspaceManagerViewModel.defaultAuthorName, text: $authorName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email on commits")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                TextField(WorkspaceManagerViewModel.defaultAuthorEmail, text: $authorEmail)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Authentication & Commit Identity (Optional)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            if let msg = wsManagerVM.syncStatusMessage {
                HStack {
                    Image(systemName: wsManagerVM.syncSeverity == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(wsManagerVM.syncSeverity == .success ? .green : .red)
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundColor(wsManagerVM.syncSeverity == .error ? .red : .primary)
                    Spacer()
                }
                .padding(8)
                .background(wsManagerVM.syncSeverity == .success ? Color.green.opacity(0.08) : Color.red.opacity(0.1))
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
                            branch: branch.isEmpty ? nil : branch,
                            token: token.isEmpty ? nil : token,
                            username: username.isEmpty ? nil : username,
                            authorName: authorName,
                            authorEmail: authorEmail
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
        .frame(width: 560)
    }
}
