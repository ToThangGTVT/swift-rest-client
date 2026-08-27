//
//  WorkspaceManagerSheetView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct WorkspaceManagerSheetView: View {
    @ObservedObject public var wsManagerVM = WorkspaceManagerViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0
    @State private var showingNewWorkspaceDialog: Bool = false
    @State private var newWorkspaceName: String = ""
    @State private var newWorkspaceDesc: String = ""
    @State private var newWorkspaceGitUrl: String = ""

    // Git Tab state
    @State private var customCommitMessage: String = "Sync workspace updates"
    @State private var gitRemoteUrlInput: String = ""
    @State private var gitBranchInput: String = ""
    @State private var gitAuthorNameInput: String = ""
    @State private var gitAuthorEmailInput: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workspace & Git Sync Manager")
                        .font(.headline)
                    Text("Manage isolated project workspaces and synchronize API specs with Git repositories.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Segmented Tabs
            Picker("", selection: $selectedTab) {
                Text("Workspaces (\(wsManagerVM.workspaces.count))").tag(0)
                Text("Git Sync & Repository").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Tab Content
            if selectedTab == 0 {
                workspacesListView
            } else {
                gitSyncSettingsView
            }

            // Sync Status Message Banner
            if let msg = wsManagerVM.syncStatusMessage {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: wsManagerVM.syncIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(wsManagerVM.syncIsError ? .red : .green)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(wsManagerVM.syncIsError ? .red : .primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(wsManagerVM.syncIsError ? Color.red.opacity(0.1) : Color.green.opacity(0.08))
            }
        }
        .frame(width: 650, height: 480)
        .onAppear {
            loadActiveWorkspaceGitFields()
        }
        .sheet(isPresented: $showingNewWorkspaceDialog) {
            newWorkspaceSheet
        }
    }

    // MARK: - Workspaces List Tab

    private var workspacesListView: some View {
        VStack(spacing: 12) {
            // Action Bar
            HStack {
                Button(action: {
                    newWorkspaceName = ""
                    newWorkspaceDesc = ""
                    newWorkspaceGitUrl = ""
                    showingNewWorkspaceDialog = true
                }) {
                    Label("New Workspace", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: {
                    wsManagerVM.showingCloneWorkspaceSheet = true
                }) {
                    Label("Clone Git Repo...", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Workspaces List
            List {
                ForEach(wsManagerVM.workspaces) { ws in
                    HStack(spacing: 12) {
                        Image(systemName: ws.id == wsManagerVM.activeWorkspace.id ? "checkmark.circle.fill" : "folder")
                            .foregroundColor(ws.id == wsManagerVM.activeWorkspace.id ? .green : .secondary)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(ws.name)
                                    .fontWeight(.medium)
                                if ws.id == wsManagerVM.activeWorkspace.id {
                                    Text("ACTIVE")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(3)
                                }
                            }

                            if !ws.description.isEmpty {
                                Text(ws.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(ws.directoryPath)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if ws.id != wsManagerVM.activeWorkspace.id {
                            Button("Switch") {
                                wsManagerVM.switchWorkspace(to: ws)
                                loadActiveWorkspaceGitFields()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Menu {
                            Button("Open in Finder") {
                                let url = URL(fileURLWithPath: ws.directoryPath)
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                            }
                            Divider()
                            if wsManagerVM.workspaces.count > 1 {
                                Button("Delete Workspace", role: .destructive) {
                                    wsManagerVM.deleteWorkspace(id: ws.id)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Git Sync Settings Tab

    private var gitSyncSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Workspace info header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active: \(wsManagerVM.activeWorkspace.name)")
                            .font(.headline)
                        Text(wsManagerVM.activeWorkspace.directoryPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Open Folder") {
                        wsManagerVM.openDirectoryInFinder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                // Git Status Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                            .foregroundColor(.accentColor)
                        Text("Git Repository Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { wsManagerVM.refreshGitStatus() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    if wsManagerVM.gitStatus.isGitRepo {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Branch")
                                    .font(.caption2).foregroundColor(.secondary)
                                Text(wsManagerVM.gitStatus.currentBranch)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }

                            VStack(alignment: .leading) {
                                Text("Working Tree")
                                    .font(.caption2).foregroundColor(.secondary)
                                Text(wsManagerVM.gitStatus.hasUncommittedChanges ? "Modified changes" : "Clean")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(wsManagerVM.gitStatus.hasUncommittedChanges ? .orange : .green)
                            }

                            VStack(alignment: .leading) {
                                Text("Unpushed Commits")
                                    .font(.caption2).foregroundColor(.secondary)
                                Text("\(wsManagerVM.gitStatus.unpushedCommitCount)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }

                        if let lastMsg = wsManagerVM.gitStatus.lastCommitMessage {
                            Text("Last commit: \(lastMsg)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("This workspace directory is not initialized with Git yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Initialize Git Repository") {
                            _ = GitSyncService.initRepository(inDirectory: wsManagerVM.activeWorkspace.directoryPath)
                            wsManagerVM.refreshGitStatus()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                // Git Remote & Credentials Configuration
                VStack(alignment: .leading, spacing: 10) {
                    Text("Remote Repository & Author Info")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Git Remote URL (HTTPS or SSH)")
                            .font(.caption).foregroundColor(.secondary)
                        TextField("e.g. https://github.com/my-org/api-specs.git", text: $gitRemoteUrlInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Branch")
                                .font(.caption).foregroundColor(.secondary)
                            TextField("main", text: $gitBranchInput)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Git Author Name")
                                .font(.caption).foregroundColor(.secondary)
                            TextField("John Doe", text: $gitAuthorNameInput)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Git Author Email")
                                .font(.caption).foregroundColor(.secondary)
                            TextField("john@example.com", text: $gitAuthorEmailInput)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Button("Save Git Configuration") {
                        saveGitConfig()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                // Sync Actions (Commit & Push / Pull)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sync Actions")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Commit Message")
                            .font(.caption).foregroundColor(.secondary)
                        TextField("Commit message...", text: $customCommitMessage)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            wsManagerVM.commitAndPush(message: customCommitMessage)
                        }) {
                            Label(wsManagerVM.isSyncing ? "Syncing..." : "Commit & Push", systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(wsManagerVM.isSyncing)

                        Button(action: {
                            wsManagerVM.pullRemote()
                        }) {
                            Label("Pull Remote Changes", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(wsManagerVM.isSyncing || !wsManagerVM.activeWorkspace.isGitConfigured)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .padding(16)
        }
    }

    // MARK: - New Workspace Sheet

    private var newWorkspaceSheet: some View {
        VStack(spacing: 16) {
            Text("Create New Workspace")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workspace Name *")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("e.g. E-Commerce APIs", text: $newWorkspaceName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description (Optional)")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("Project description...", text: $newWorkspaceDesc)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Git Remote URL (Optional)")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("https://github.com/org/repo.git", text: $newWorkspaceGitUrl)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 8)

            HStack {
                Button("Cancel") {
                    showingNewWorkspaceDialog = false
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Create Workspace") {
                    wsManagerVM.createWorkspace(
                        name: newWorkspaceName,
                        description: newWorkspaceDesc,
                        gitRemoteUrl: newWorkspaceGitUrl
                    )
                    showingNewWorkspaceDialog = false
                    loadActiveWorkspaceGitFields()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func loadActiveWorkspaceGitFields() {
        let ws = wsManagerVM.activeWorkspace
        gitRemoteUrlInput = ws.gitRemoteUrl
        gitBranchInput = ws.gitBranch
        gitAuthorNameInput = ws.gitAuthorName
        gitAuthorEmailInput = ws.gitAuthorEmail
    }

    private func saveGitConfig() {
        var ws = wsManagerVM.activeWorkspace
        ws.gitRemoteUrl = gitRemoteUrlInput
        ws.gitBranch = gitBranchInput.isEmpty ? "main" : gitBranchInput
        ws.gitAuthorName = gitAuthorNameInput
        ws.gitAuthorEmail = gitAuthorEmailInput

        if let idx = wsManagerVM.workspaces.firstIndex(where: { $0.id == ws.id }) {
            wsManagerVM.workspaces[idx] = ws
        }
        wsManagerVM.activeWorkspace = ws
        WorkspaceStore.shared.saveWorkspaces(wsManagerVM.workspaces)
        WorkspaceStore.shared.saveWorkspaceManifest(ws)

        if !ws.gitRemoteUrl.isEmpty {
            _ = GitSyncService.setRemote(url: ws.gitRemoteUrl, inDirectory: ws.directoryPath)
        }
        wsManagerVM.refreshGitStatus()
    }
}
