//
//  WorkspaceStore.swift
//  CocoaRestClientCore
//

import Foundation

public final class WorkspaceStore: @unchecked Sendable {
    public static let shared = WorkspaceStore()

    private let fileManager = FileManager.default
    private let lock = NSLock()

    private var appSupportDir: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CocoaRestClient", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    private var workspacesConfigFile: URL {
        appSupportDir.appendingPathComponent("workspaces_index.json")
    }

    private var activeWorkspaceFile: URL {
        appSupportDir.appendingPathComponent("active_workspace.txt")
    }

    public var defaultWorkspacesRootDirectory: URL {
        let dir = appSupportDir.appendingPathComponent("Workspaces", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public init() {}

    // MARK: - Workspace Index & Active Workspace

    public func loadWorkspaces() -> [WorkspaceModel] {
        lock.lock()
        defer { lock.unlock() }

        return loadWorkspacesLocked()
    }

    public func saveWorkspaces(_ workspaces: [WorkspaceModel]) {
        lock.lock()
        defer { lock.unlock() }

        saveWorkspacesLocked(workspaces)
    }

    public func getActiveWorkspaceId() -> UUID {
        lock.lock()
        defer { lock.unlock() }

        if let idStr = try? String(contentsOf: activeWorkspaceFile, encoding: .utf8),
           let id = UUID(uuidString: idStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return id
        }
        let list = loadWorkspacesLocked()
        let id = list.first?.id ?? UUID()
        try? id.uuidString.write(to: activeWorkspaceFile, atomically: true, encoding: .utf8)
        return id
    }

    /// Caller must already hold `lock`. NSLock is not reentrant, so the public
    /// entry points funnel through these helpers instead of calling each other.
    private func loadWorkspacesLocked() -> [WorkspaceModel] {
        if fileManager.fileExists(atPath: workspacesConfigFile.path),
           let data = try? Data(contentsOf: workspacesConfigFile) {
            let decoder = JSONDecoder()
            if let workspaces = try? decoder.decode([WorkspaceModel].self, from: data), !workspaces.isEmpty {
                return workspaces
            }
        }

        // Default: Create Default Workspace
        let defaultWorkspace = createDefaultWorkspace()
        saveWorkspacesLocked([defaultWorkspace])
        return [defaultWorkspace]
    }

    /// Caller must already hold `lock`.
    private func saveWorkspacesLocked(_ workspaces: [WorkspaceModel]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(workspaces) {
            try? data.write(to: workspacesConfigFile, options: .atomic)
        }
    }

    public func setActiveWorkspaceId(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        try? id.uuidString.write(to: activeWorkspaceFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Workspace Data Loading / Saving to Directory

    public func loadCollections(for workspace: WorkspaceModel) -> RequestFolder {
        let fileUrl = URL(fileURLWithPath: workspace.directoryPath).appendingPathComponent("collections.json")
        if fileManager.fileExists(atPath: fileUrl.path),
           let data = try? Data(contentsOf: fileUrl),
           let folder = try? JSONDecoder().decode(RequestFolder.self, from: data) {
            return folder
        }
        // Fallback: Default starter collection
        let defaultCollection = RequestFolder(name: "Main Collection")
        saveCollections(defaultCollection, for: workspace)
        return defaultCollection
    }

    public func saveCollections(_ folder: RequestFolder, for workspace: WorkspaceModel) {
        ensureDirectoryExists(workspace.directoryPath)
        let fileUrl = URL(fileURLWithPath: workspace.directoryPath).appendingPathComponent("collections.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(folder) {
            try? data.write(to: fileUrl, options: .atomic)
        }
    }

    public func loadEnvironments(for workspace: WorkspaceModel) -> [EnvironmentProfile] {
        let fileUrl = URL(fileURLWithPath: workspace.directoryPath).appendingPathComponent("environments.json")
        if fileManager.fileExists(atPath: fileUrl.path),
           let data = try? Data(contentsOf: fileUrl),
           let envs = try? JSONDecoder().decode([EnvironmentProfile].self, from: data), !envs.isEmpty {
            return envs
        }
        let defaultEnvs = [
            EnvironmentProfile(name: "Development", variables: [
                KeyValuePair(key: "baseUrl", value: "https://httpbin.org", isEnabled: true)
            ]),
            EnvironmentProfile(name: "Production", variables: [
                KeyValuePair(key: "baseUrl", value: "https://api.example.com", isEnabled: true)
            ])
        ]
        saveEnvironments(defaultEnvs, for: workspace)
        return defaultEnvs
    }

    public func saveEnvironments(_ envs: [EnvironmentProfile], for workspace: WorkspaceModel) {
        ensureDirectoryExists(workspace.directoryPath)
        let fileUrl = URL(fileURLWithPath: workspace.directoryPath).appendingPathComponent("environments.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(envs) {
            try? data.write(to: fileUrl, options: .atomic)
        }
    }

    public func saveWorkspaceManifest(_ workspace: WorkspaceModel) {
        ensureDirectoryExists(workspace.directoryPath)
        let fileUrl = URL(fileURLWithPath: workspace.directoryPath).appendingPathComponent("workspace.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(workspace) {
            try? data.write(to: fileUrl, options: .atomic)
        }
    }

    public func deleteWorkspaceDirectory(_ workspace: WorkspaceModel) {
        try? fileManager.removeItem(atPath: workspace.directoryPath)
    }

    private func ensureDirectoryExists(_ path: String) {
        if !fileManager.fileExists(atPath: path) {
            try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    private func createDefaultWorkspace() -> WorkspaceModel {
        let dir = defaultWorkspacesRootDirectory.appendingPathComponent("Default Workspace", isDirectory: true)
        ensureDirectoryExists(dir.path)

        let workspace = WorkspaceModel(
            name: "Default Workspace",
            description: "Personal API testing and request collections",
            directoryPath: dir.path
        )

        // Migrate existing saved requests and environments if available
        let existingFolder = SavedRequestsStore.shared.loadRootFolder()
        saveCollections(existingFolder, for: workspace)

        let existingEnvs = EnvironmentStore.shared.loadEnvironments()
        saveEnvironments(existingEnvs, for: workspace)

        saveWorkspaceManifest(workspace)

        // Init git repo for default workspace
        _ = GitSyncService.initRepository(inDirectory: dir.path)
        _ = GitSyncService.commitAll(message: "Initial workspace setup", inDirectory: dir.path)

        return workspace
    }
}
