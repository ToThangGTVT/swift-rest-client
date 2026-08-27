//
//  WorkspaceModel.swift
//  CocoaRestClientCore
//

import Foundation

public struct GitSyncStatus: Codable, Sendable, Equatable {
    public var isGitRepo: Bool
    public var currentBranch: String
    public var hasUncommittedChanges: Bool
    public var unpushedCommitCount: Int
    public var lastSyncDate: Date?
    public var lastCommitMessage: String?
    public var errorMessage: String?

    public init(
        isGitRepo: Bool = false,
        currentBranch: String = "main",
        hasUncommittedChanges: Bool = false,
        unpushedCommitCount: Int = 0,
        lastSyncDate: Date? = nil,
        lastCommitMessage: String? = nil,
        errorMessage: String? = nil
    ) {
        self.isGitRepo = isGitRepo
        self.currentBranch = currentBranch
        self.hasUncommittedChanges = hasUncommittedChanges
        self.unpushedCommitCount = unpushedCommitCount
        self.lastSyncDate = lastSyncDate
        self.lastCommitMessage = lastCommitMessage
        self.errorMessage = errorMessage
    }
}

public struct WorkspaceModel: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var description: String
    public var directoryPath: String
    public var gitRemoteUrl: String
    public var gitBranch: String
    public var gitAuthorName: String
    public var gitAuthorEmail: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "Default Workspace",
        description: String = "",
        directoryPath: String = "",
        gitRemoteUrl: String = "",
        gitBranch: String = "main",
        gitAuthorName: String = "",
        gitAuthorEmail: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.directoryPath = directoryPath
        self.gitRemoteUrl = gitRemoteUrl
        self.gitBranch = gitBranch
        self.gitAuthorName = gitAuthorName
        self.gitAuthorEmail = gitAuthorEmail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var directoryURL: URL {
        URL(fileURLWithPath: directoryPath)
    }

    public var isGitConfigured: Bool {
        !gitRemoteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
