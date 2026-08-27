//
//  WorkspaceManagerViewModel.swift
//  CocoaRestClient
//

import Foundation
import SwiftUI
import CocoaRestClientCore
import AppKit

@MainActor
public final class WorkspaceManagerViewModel: ObservableObject {
    public static let shared = WorkspaceManagerViewModel()

    @Published public var workspaces: [WorkspaceModel] = []
    @Published public var activeWorkspace: WorkspaceModel
    @Published public var gitStatus: GitSyncStatus = GitSyncStatus()
    @Published public var isSyncing: Bool = false
    @Published public var syncStatusMessage: String?
    @Published public var syncIsError: Bool = false

    @Published public var showingWorkspaceManagerSheet: Bool = false
    @Published public var showingCloneWorkspaceSheet: Bool = false

    private let store = WorkspaceStore.shared

    public init() {
        let list = store.loadWorkspaces()
        self.workspaces = list
        let activeId = store.getActiveWorkspaceId()
        let active = list.first(where: { $0.id == activeId }) ?? list.first ?? WorkspaceModel()
        self.activeWorkspace = active
        refreshGitStatus()
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
        syncIsError = false

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

            syncStatusMessage = "Successfully cloned \(repoName)!"
            syncIsError = false
            return true
        } else {
            syncStatusMessage = "Clone failed: \(cloneRes.error)"
            syncIsError = true
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
        syncStatusMessage = "Committing and pushing changes..."
        syncIsError = false

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
            syncStatusMessage = "Commit error: \(commitRes.error)"
            syncIsError = true
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
                syncStatusMessage = "Successfully synced and pushed to remote!"
                syncIsError = false
            } else {
                syncStatusMessage = "Push warning: \(pushRes.error.isEmpty ? pushRes.output : pushRes.error)"
                syncIsError = true
            }
        } else {
            isSyncing = false
            syncStatusMessage = "Committed locally (no Git remote configured)."
            syncIsError = false
        }

        refreshGitStatus()
    }

    public func pullRemote() {
        guard !activeWorkspace.directoryPath.isEmpty && activeWorkspace.isGitConfigured else { return }
        isSyncing = true
        syncStatusMessage = "Pulling latest changes from remote..."
        syncIsError = false

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

            syncStatusMessage = "Successfully pulled latest changes!"
            syncIsError = false
        } else {
            syncStatusMessage = "Pull error: \(pullRes.error.isEmpty ? pullRes.output : pullRes.error)"
            syncIsError = true
        }

        refreshGitStatus()
    }

    public func openDirectoryInFinder() {
        let url = URL(fileURLWithPath: activeWorkspace.directoryPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
