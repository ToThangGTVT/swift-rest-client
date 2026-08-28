//
//  WorkspaceManagerSheetView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

/// Plain-language description of where a workspace's data lives, derived from
/// the workspace's remote URL plus the on-disk git status.
private struct SyncSummary {
    let icon: String
    let color: Color
    let headline: String
    let detail: String?
}

public struct WorkspaceManagerSheetView: View {
    @ObservedObject public var wsManagerVM = WorkspaceManagerViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWorkspaceId: UUID?
    @State private var showingNewWorkspaceDialog: Bool = false
    @State private var newWorkspaceName: String = ""
    @State private var newWorkspaceDesc: String = ""
    @State private var newWorkspaceGitUrl: String = ""

    // Repository fields for the workspace selected in the list.
    @State private var repoUrlInput: String = ""
    @State private var branchInput: String = ""
    @State private var authorNameInput: String = ""
    @State private var authorEmailInput: String = ""
    @State private var showingAdvanced: Bool = false

    @State private var commitMessage: String = "Update API workspace"
    @State private var workspacePendingDeletion: WorkspaceModel?

    public init() {}

    private var selectedWorkspace: WorkspaceModel? {
        wsManagerVM.workspaces.first(where: { $0.id == selectedWorkspaceId })
            ?? wsManagerVM.workspaces.first
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                workspaceList
                    .frame(width: 240)

                Divider()

                if let ws = selectedWorkspace {
                    detailPanel(for: ws)
                } else {
                    Spacer()
                }
            }

            statusBanner
        }
        .frame(width: 860, height: 620)
        .onAppear {
            selectedWorkspaceId = wsManagerVM.activeWorkspace.id
            loadRepoFields()
            // Publishes a status for every workspace (and shells out to git for each
            // one), so keep it off the update that presents the sheet.
            DispatchQueue.main.async {
                wsManagerVM.refreshAllStatuses()
            }
        }
        .onChange(of: selectedWorkspaceId) { _ in
            loadRepoFields()
        }
        .sheet(isPresented: $showingNewWorkspaceDialog) {
            newWorkspaceSheet
        }
        .alert(
            "Remove \(workspacePendingDeletion?.name ?? "")?",
            isPresented: Binding(
                get: { workspacePendingDeletion != nil },
                set: { if !$0 { workspacePendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { workspacePendingDeletion = nil }
            Button("Remove", role: .destructive) {
                if let ws = workspacePendingDeletion {
                    wsManagerVM.deleteWorkspace(id: ws.id)
                    selectedWorkspaceId = wsManagerVM.activeWorkspace.id
                    loadRepoFields()
                }
                workspacePendingDeletion = nil
            }
        } message: {
            Text("This removes the workspace from CocoaRestClient. The folder and its Git repository stay on disk.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundColor(.accentColor)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Workspaces")
                    .font(.system(size: 16, weight: .semibold))
                Text("Every workspace is a folder of requests that syncs to its own Git repository.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Workspace List

    private var workspaceList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(wsManagerVM.workspaces) { ws in
                        workspaceRow(ws)
                    }
                }
                .padding(8)
            }

            Divider()

            VStack(spacing: 6) {
                Button(action: {
                    newWorkspaceName = ""
                    newWorkspaceDesc = ""
                    newWorkspaceGitUrl = ""
                    showingNewWorkspaceDialog = true
                }) {
                    Label("New Workspace", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    wsManagerVM.showingCloneWorkspaceSheet = true
                }) {
                    Label("Add from Repository", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    private func workspaceRow(_ ws: WorkspaceModel) -> some View {
        let isSelected = ws.id == selectedWorkspace?.id
        let isActive = ws.id == wsManagerVM.activeWorkspace.id

        return Button(action: { selectedWorkspaceId = ws.id }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ws.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if isActive {
                        Text("OPEN")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                    }
                    Spacer()
                }

                HStack(spacing: 4) {
                    Image(systemName: ws.isGitConfigured ? "arrow.triangle.2.circlepath" : "externaldrive")
                        .font(.system(size: 9))
                    Text(ws.isGitConfigured ? shortRepoName(ws.gitRemoteUrl) : "This Mac only")
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .cornerRadius(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Panel

    private func detailPanel(for ws: WorkspaceModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                workspaceHeading(ws)
                syncCard(ws)
                if ws.isGitConfigured {
                    syncActionsCard(ws)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func workspaceHeading(_ ws: WorkspaceModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(ws.name)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                if ws.id != wsManagerVM.activeWorkspace.id {
                    Button("Open This Workspace") {
                        wsManagerVM.switchWorkspace(to: ws)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if !ws.description.isEmpty {
                Text(ws.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(ws.directoryPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button("Reveal") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: ws.directoryPath)
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Spacer()

                if wsManagerVM.workspaces.count > 1 {
                    Button("Remove") {
                        workspacePendingDeletion = ws
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Sync Card

    private func syncCard(_ ws: WorkspaceModel) -> some View {
        let summary = syncSummary(for: ws)

        return VStack(alignment: .leading, spacing: 12) {
            // Where this workspace syncs, in one sentence.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: summary.icon)
                    .font(.system(size: 18))
                    .foregroundColor(summary.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.headline)
                        .font(.system(size: 14, weight: .medium))
                    if let detail = summary.detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { wsManagerVM.refreshStatus(for: ws) }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Check the repository again")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Repository URL")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("https://github.com/my-org/api-specs.git", text: $repoUrlInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                Text("Leave this empty to keep the workspace on this Mac only.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Branch")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("main", text: $branchInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: 220)
            }

            DisclosureGroup(isExpanded: $showingAdvanced) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name on commits")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        TextField("John Doe", text: $authorNameInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email on commits")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        TextField("john@example.com", text: $authorEmailInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Commit identity")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack {
                Button(saveButtonTitle(for: ws)) {
                    wsManagerVM.saveRepositorySettings(
                        for: ws.id,
                        remoteUrl: repoUrlInput,
                        branch: branchInput,
                        authorName: authorNameInput,
                        authorEmail: authorEmailInput
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasRepoEdits(for: ws))

                if hasRepoEdits(for: ws) {
                    Button("Revert") {
                        loadRepoFields()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Sync Actions

    private func syncActionsCard(_ ws: WorkspaceModel) -> some View {
        let isActive = ws.id == wsManagerVM.activeWorkspace.id

        return VStack(alignment: .leading, spacing: 10) {
            Text("Sync Now")
                .font(.system(size: 14, weight: .medium))

            if isActive {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Describe what changed")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("Update API workspace", text: $commitMessage)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                HStack(spacing: 12) {
                    Button(action: {
                        wsManagerVM.commitAndPush(message: commitMessage)
                    }) {
                        Label(
                            wsManagerVM.isSyncing ? "Working..." : "Save & Push to Repository",
                            systemImage: "arrow.up.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(wsManagerVM.isSyncing)

                    Button(action: {
                        wsManagerVM.pullRemote()
                    }) {
                        Label("Get Latest", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(wsManagerVM.isSyncing)
                }
            } else {
                // Push/pull act on the requests currently loaded in the app, so
                // they only make sense for the workspace that is open.
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("Open this workspace to push or pull its changes.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Button("Open This Workspace") {
                        wsManagerVM.switchWorkspace(to: ws)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        if let msg = wsManagerVM.syncStatusMessage {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: bannerIcon)
                    .foregroundColor(bannerColor)
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(wsManagerVM.syncSeverity == .error ? .red : .primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(bannerColor.opacity(0.1))
        }
    }

    private var bannerIcon: String {
        switch wsManagerVM.syncSeverity {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private var bannerColor: Color {
        switch wsManagerVM.syncSeverity {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    // MARK: - New Workspace Sheet

    private var newWorkspaceSheet: some View {
        VStack(spacing: 16) {
            Text("New Workspace")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name *")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("e.g. E-Commerce APIs", text: $newWorkspaceName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description (optional)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("What this workspace is for...", text: $newWorkspaceDesc)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL (optional)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("https://github.com/org/repo.git", text: $newWorkspaceGitUrl)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    Text("You can add this later.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)

            HStack {
                Button("Cancel") {
                    showingNewWorkspaceDialog = false
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Create") {
                    wsManagerVM.createWorkspace(
                        name: newWorkspaceName,
                        description: newWorkspaceDesc,
                        gitRemoteUrl: newWorkspaceGitUrl
                    )
                    showingNewWorkspaceDialog = false
                    selectedWorkspaceId = wsManagerVM.activeWorkspace.id
                    loadRepoFields()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    // MARK: - Helpers

    private func loadRepoFields() {
        guard let ws = selectedWorkspace else { return }
        repoUrlInput = ws.gitRemoteUrl
        branchInput = ws.gitBranch
        authorNameInput = ws.gitAuthorName
        authorEmailInput = ws.gitAuthorEmail
        showingAdvanced = !ws.gitAuthorName.isEmpty || !ws.gitAuthorEmail.isEmpty
    }

    private func hasRepoEdits(for ws: WorkspaceModel) -> Bool {
        let url = repoUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = branchInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return url != ws.gitRemoteUrl
            || (branch.isEmpty ? "main" : branch) != ws.gitBranch
            || authorNameInput.trimmingCharacters(in: .whitespacesAndNewlines) != ws.gitAuthorName
            || authorEmailInput.trimmingCharacters(in: .whitespacesAndNewlines) != ws.gitAuthorEmail
    }

    private func saveButtonTitle(for ws: WorkspaceModel) -> String {
        let url = repoUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty && ws.isGitConfigured {
            return "Stop Syncing"
        }
        return ws.isGitConfigured ? "Save Repository Settings" : "Connect Repository"
    }

    private func shortRepoName(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.split(separator: "/").last else { return trimmed }
        return String(last.hasSuffix(".git") ? last.dropLast(4) : last)
    }

    private func syncSummary(for ws: WorkspaceModel) -> SyncSummary {
        let status = wsManagerVM.status(for: ws)

        guard ws.isGitConfigured else {
            return SyncSummary(
                icon: "externaldrive",
                color: .secondary,
                headline: "Saved on this Mac only",
                detail: "Add a repository URL below to sync this workspace."
            )
        }

        guard status.isGitRepo else {
            return SyncSummary(
                icon: "arrow.triangle.2.circlepath",
                color: .accentColor,
                headline: "Ready to sync",
                detail: ws.gitRemoteUrl
            )
        }

        let pending = status.hasUncommittedChanges || status.unpushedCommitCount > 0
        if pending {
            var parts: [String] = []
            if status.hasUncommittedChanges { parts.append("unsaved edits") }
            if status.unpushedCommitCount > 0 {
                parts.append("\(status.unpushedCommitCount) commit\(status.unpushedCommitCount == 1 ? "" : "s") not pushed")
            }
            return SyncSummary(
                icon: "arrow.up.circle",
                color: .orange,
                headline: "Changes waiting to be pushed",
                detail: "\(parts.joined(separator: ", ")) · \(ws.gitRemoteUrl) · \(status.currentBranch)"
            )
        }

        return SyncSummary(
            icon: "checkmark.circle.fill",
            color: .green,
            headline: "Everything is pushed",
            detail: "\(ws.gitRemoteUrl) · \(status.currentBranch)"
        )
    }
}
