//
//  WorkspaceManagerViewModel.swift
//  CocoaRestClient
//

import Foundation
import SwiftUI
import CocoaRestClientCore
import AppKit

public enum SyncSeverity: Sendable {
    case success
    case warning
    case error
}

@MainActor
public final class WorkspaceManagerViewModel: ObservableObject {
    public static let shared = WorkspaceManagerViewModel()

    @Published public var workspaces: [WorkspaceModel] = []
    @Published public var activeWorkspace: WorkspaceModel
    @Published public var gitStatus: GitSyncStatus = GitSyncStatus()
    @Published public var isSyncing: Bool = false
    @Published public var syncStatusMessage: String?
    @Published public var syncSeverity: SyncSeverity = .success

    /// Git status per workspace, so the manager can describe every workspace's
    /// repository — not only the one currently open.
    @Published public var statusByWorkspace: [UUID: GitSyncStatus] = [:]

    @Published public var showingWorkspaceManagerSheet: Bool = false
    @Published public var showingCloneWorkspaceSheet: Bool = false

    private let store = WorkspaceStore.shared

    public init() {
        let list = store.loadWorkspaces()
        self.workspaces = list
        let activeId = store.getActiveWorkspaceId()
        let active = list.first(where: { $0.id == activeId }) ?? list.first ?? WorkspaceModel()
        self.activeWorkspace = active
        refreshAllStatuses()
    }

    public func refreshWorkspaces() {
        self.workspaces = store.loadWorkspaces()
        let activeId = store.getActiveWorkspaceId()
        if let found = workspaces.first(where: { $0.id == activeId }) {
            self.activeWorkspace = found
        }
        refreshGitStatus()
    }

    public func switchWorkspace(to workspace: WorkspaceModel) {
        self.activeWorkspace = workspace
        store.setActiveWorkspaceId(workspace.id)

        // Reload Collections into SavedRequestsViewModel
        let folder = store.loadCollections(for: workspace)
        SavedRequestsViewModel.shared.rootFolder = folder

        // Reload Environments into EnvironmentViewModel
        let envs = store.loadEnvironments(for: workspace)
        EnvironmentViewModel.shared.environments = envs
        EnvironmentViewModel.shared.selectedEnvironmentId = envs.first?.id

        refreshGitStatus()
    }

    public func refreshGitStatus() {
        guard !activeWorkspace.directoryPath.isEmpty else { return }
        let status = GitSyncService.getStatus(inDirectory: activeWorkspace.directoryPath)
        self.gitStatus = status
        self.statusByWorkspace[activeWorkspace.id] = status
    }

    public func status(for workspace: WorkspaceModel) -> GitSyncStatus {
        statusByWorkspace[workspace.id] ?? GitSyncStatus()
    }

    public func refreshStatus(for workspace: WorkspaceModel) {
        guard !workspace.directoryPath.isEmpty else { return }
        let status = GitSyncService.getStatus(inDirectory: workspace.directoryPath)
        statusByWorkspace[workspace.id] = status
        if workspace.id == activeWorkspace.id {
            gitStatus = status
        }
    }

    public func refreshAllStatuses() {
        for ws in workspaces {
            refreshStatus(for: ws)
        }
    }

    private func report(_ message: String, _ severity: SyncSeverity) {
        syncStatusMessage = message
        syncSeverity = severity
    }

    // MARK: - Repository Settings

    /// Single entry point for "this workspace syncs to this repository".
    /// Creates the local repo on demand so the user never has to run an
    /// explicit init step first. An empty `remoteUrl` unlinks the workspace.
    @discardableResult
    public func saveRepositorySettings(
        for workspaceId: UUID,
        remoteUrl: String,
        branch: String,
        authorName: String,
        authorEmail: String
    ) -> Bool {
        guard let idx = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return false }

        let url = remoteUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)

        var ws = workspaces[idx]
        ws.gitRemoteUrl = url
        ws.gitBranch = trimmedBranch.isEmpty ? "main" : trimmedBranch
        ws.gitAuthorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        ws.gitAuthorEmail = authorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        ws.updatedAt = Date()

        workspaces[idx] = ws
        if activeWorkspace.id == ws.id {
            activeWorkspace = ws
        }
        store.saveWorkspaces(workspaces)
        store.saveWorkspaceManifest(ws)

        guard !url.isEmpty else {
            GitSyncService.removeRemote(inDirectory: ws.directoryPath)
            refreshStatus(for: ws)
            report("\(ws.name) no longer syncs anywhere — it stays on this Mac.", .warning)
            return true
        }

        // A workspace that syncs needs a local repository to push from.
        if !GitSyncService.isRepository(atDirectory: ws.directoryPath) {
            _ = GitSyncService.initRepository(inDirectory: ws.directoryPath, defaultBranch: ws.gitBranch)
            _ = GitSyncService.commitAll(
                message: "Initial workspace setup for \(ws.name)",
                inDirectory: ws.directoryPath,
                authorName: ws.gitAuthorName,
                authorEmail: ws.gitAuthorEmail
            )
        }

        let res = GitSyncService.setRemote(url: url, inDirectory: ws.directoryPath)
        refreshStatus(for: ws)

        guard res.isSuccess else {
            report("Could not link the repository: \(res.error.isEmpty ? res.output : res.error)", .error)
            return false
        }

        report("\(ws.name) now syncs to \(url)", .success)
        return true
    }

    public func saveActiveWorkspaceData() {
        store.saveCollections(SavedRequestsViewModel.shared.rootFolder, for: activeWorkspace)
        store.saveEnvironments(EnvironmentViewModel.shared.environments, for: activeWorkspace)
        store.saveWorkspaceManifest(activeWorkspace)
        refreshGitStatus()
    }

    // MARK: - Workspace Operations

    public func createWorkspace(
        name: String,
        description: String = "",
        customDirectory: String? = nil,
        gitRemoteUrl: String = "",
        gitBranch: String = "main",
        authorName: String = "",
        authorEmail: String = ""
    ) {
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let dirPath: String
        if let custom = customDirectory, !custom.isEmpty {
            dirPath = custom
        } else {
            dirPath = store.defaultWorkspacesRootDirectory.appendingPathComponent(safeName, isDirectory: true).path
        }

        let newWorkspace = WorkspaceModel(
            name: safeName,
            description: description,
            directoryPath: dirPath,
            gitRemoteUrl: gitRemoteUrl,
            gitBranch: gitBranch.isEmpty ? "main" : gitBranch,
            gitAuthorName: authorName,
            gitAuthorEmail: authorEmail
        )

        // Create directory & files
        let emptyFolder = RequestFolder(name: "\(safeName) Collection")
        store.saveCollections(emptyFolder, for: newWorkspace)

        let defaultEnvs = [
            EnvironmentProfile(name: "Development", variables: [
                KeyValuePair(key: "baseUrl", value: "https://httpbin.org", isEnabled: true)
            ])
        ]
        store.saveEnvironments(defaultEnvs, for: newWorkspace)
        store.saveWorkspaceManifest(newWorkspace)

        // Init Git Repo
        _ = GitSyncService.initRepository(inDirectory: dirPath, defaultBranch: newWorkspace.gitBranch)
        if !gitRemoteUrl.isEmpty {
            _ = GitSyncService.setRemote(url: gitRemoteUrl, inDirectory: dirPath)
        }
        _ = GitSyncService.commitAll(message: "Initial workspace setup for \(safeName)", inDirectory: dirPath, authorName: authorName, authorEmail: authorEmail)

        workspaces.append(newWorkspace)
        store.saveWorkspaces(workspaces)
        switchWorkspace(to: newWorkspace)
    }

    public func cloneWorkspace(
        repoUrl: String,
        targetDirectory: String? = nil,
        branch: String? = nil
    ) async -> Bool {
        isSyncing = true
        syncStatusMessage = "Cloning repository..."
        syncSeverity = .success

        let repoName = URL(string: repoUrl)?.deletingPathExtension().lastPathComponent ?? "Cloned Workspace"
        let destPath = targetDirectory ?? store.defaultWorkspacesRootDirectory.appendingPathComponent(repoName, isDirectory: true).path

        let cloneRes = GitSyncService.clone(repoUrl: repoUrl, destination: destPath, branch: branch)

        isSyncing = false
        if cloneRes.isSuccess {
            let workspace = WorkspaceModel(
                name: repoName,
                description: "Cloned from \(repoUrl)",
                directoryPath: destPath,
                gitRemoteUrl: repoUrl,
                gitBranch: branch ?? "main"
            )
            store.saveWorkspaceManifest(workspace)

            workspaces.append(workspace)
            store.saveWorkspaces(workspaces)
            switchWorkspace(to: workspace)

            refreshStatus(for: workspace)
            report("Cloned \(repoName) — it now syncs to \(repoUrl)", .success)
            return true
        } else {
            report("Clone failed: \(cloneRes.error)", .error)
            return false
        }
    }

    public func deleteWorkspace(id: UUID) {
        guard workspaces.count > 1 else { return }
        guard let idx = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces.remove(at: idx)
        store.saveWorkspaces(workspaces)

        if activeWorkspace.id == id {
            switchWorkspace(to: workspaces[0])
        }
    }

    // MARK: - Git Sync Operations

    public func commitAndPush(message: String) {
        guard !activeWorkspace.directoryPath.isEmpty else { return }
        isSyncing = true
        syncStatusMessage = "Saving and pushing changes..."
        syncSeverity = .success

        // 1. Save all active workspace files first
        saveActiveWorkspaceData()

        // 2. Commit all changes
        let commitRes = GitSyncService.commitAll(
            message: message,
            inDirectory: activeWorkspace.directoryPath,
            authorName: activeWorkspace.gitAuthorName,
            authorEmail: activeWorkspace.gitAuthorEmail
        )

        guard commitRes.isSuccess || commitRes.output.contains("nothing to commit") else {
            isSyncing = false
            report("Could not save changes: \(commitRes.error)", .error)
            return
        }

        // 3. Push if remote is configured
        if activeWorkspace.isGitConfigured {
            let pushRes = GitSyncService.push(
                inDirectory: activeWorkspace.directoryPath,
                branch: activeWorkspace.gitBranch
            )
            isSyncing = false
            if pushRes.isSuccess {
                report("Pushed to \(activeWorkspace.gitRemoteUrl)", .success)
            } else {
                report("Push failed: \(pushRes.error.isEmpty ? pushRes.output : pushRes.error)", .error)
            }
        } else {
            isSyncing = false
            report("Saved on this Mac only — no repository is linked to \(activeWorkspace.name) yet.", .warning)
        }

        refreshGitStatus()
    }

    public func pullRemote() {
        guard !activeWorkspace.directoryPath.isEmpty && activeWorkspace.isGitConfigured else { return }
        isSyncing = true
        syncStatusMessage = "Pulling latest changes..."
        syncSeverity = .success

        let pullRes = GitSyncService.pull(
            inDirectory: activeWorkspace.directoryPath,
            branch: activeWorkspace.gitBranch
        )

        isSyncing = false
        if pullRes.isSuccess {
            // Reload updated files into UI
            let folder = store.loadCollections(for: activeWorkspace)
            SavedRequestsViewModel.shared.rootFolder = folder

            let envs = store.loadEnvironments(for: activeWorkspace)
            EnvironmentViewModel.shared.environments = envs

            report("Pulled the latest changes from the repository.", .success)
        } else {
            report("Pull failed: \(pullRes.error.isEmpty ? pullRes.output : pullRes.error)", .error)
        }

        refreshGitStatus()
    }

    public func openDirectoryInFinder() {
        let url = URL(fileURLWithPath: activeWorkspace.directoryPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
