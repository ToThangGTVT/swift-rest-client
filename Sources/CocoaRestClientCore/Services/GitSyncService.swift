//
//  GitSyncService.swift
//  CocoaRestClientCore
//

import Foundation

public struct GitCommandResult: Sendable {
    public let exitCode: Int32
    public let output: String
    public let error: String

    public var isSuccess: Bool {
        exitCode == 0
    }
}

public struct GitSyncService: Sendable {
    public init() {}

    public static func runGit(args: [String], inDirectory dirPath: String) -> GitCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: dirPath)

        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_AUTHOR_NAME"] = "CocoaRestClient"
        env["GIT_AUTHOR_EMAIL"] = "restclient@local"
        env["GIT_COMMITTER_NAME"] = "CocoaRestClient"
        env["GIT_COMMITTER_EMAIL"] = "restclient@local"
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let outStr = String(data: outData, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""

            return GitCommandResult(exitCode: process.terminationStatus, output: outStr, error: errStr)
        } catch {
            return GitCommandResult(exitCode: -1, output: "", error: error.localizedDescription)
        }
    }

    public static func getStatus(inDirectory dirPath: String) -> GitSyncStatus {
        let gitDir = URL(fileURLWithPath: dirPath).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            return GitSyncStatus(isGitRepo: false)
        }

        // 1. Current Branch
        let branchRes = runGit(args: ["branch", "--show-current"], inDirectory: dirPath)
        let branch = branchRes.isSuccess ? branchRes.output.trimmingCharacters(in: .whitespacesAndNewlines) : "main"

        // 2. Uncommitted changes (porcelain)
        let statusRes = runGit(args: ["status", "--porcelain"], inDirectory: dirPath)
        let hasChanges = statusRes.isSuccess && !statusRes.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // 3. Last commit message
        let logRes = runGit(args: ["log", "-1", "--pretty=%B"], inDirectory: dirPath)
        let lastMsg = logRes.isSuccess ? logRes.output.trimmingCharacters(in: .whitespacesAndNewlines) : nil

        // 4. Unpushed commits count
        let unpushedRes = runGit(args: ["rev-list", "@{u}..HEAD", "--count"], inDirectory: dirPath)
        let unpushedCount = unpushedRes.isSuccess ? (Int(unpushedRes.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) : 0

        return GitSyncStatus(
            isGitRepo: true,
            currentBranch: branch.isEmpty ? "main" : branch,
            hasUncommittedChanges: hasChanges,
            unpushedCommitCount: unpushedCount,
            lastSyncDate: Date(),
            lastCommitMessage: lastMsg,
            errorMessage: nil
        )
    }

    public static func initRepository(inDirectory dirPath: String, defaultBranch: String = "main") -> GitCommandResult {
        let res = runGit(args: ["init", "-b", defaultBranch], inDirectory: dirPath)
        if !res.isSuccess {
            // Fallback for older git versions without -b flag
            _ = runGit(args: ["init"], inDirectory: dirPath)
            return runGit(args: ["checkout", "-b", defaultBranch], inDirectory: dirPath)
        }
        return res
    }

    public static func setRemote(url: String, inDirectory dirPath: String, remoteName: String = "origin") -> GitCommandResult {
        _ = runGit(args: ["remote", "remove", remoteName], inDirectory: dirPath)
        return runGit(args: ["remote", "add", remoteName, url], inDirectory: dirPath)
    }

    public static func commitAll(
        message: String,
        inDirectory dirPath: String,
        authorName: String = "",
        authorEmail: String = ""
    ) -> GitCommandResult {
        // Set local author if provided
        if !authorName.isEmpty {
            _ = runGit(args: ["config", "user.name", authorName], inDirectory: dirPath)
        }
        if !authorEmail.isEmpty {
            _ = runGit(args: ["config", "user.email", authorEmail], inDirectory: dirPath)
        }

        // Add all files
        let addRes = runGit(args: ["add", "-A"], inDirectory: dirPath)
        guard addRes.isSuccess else { return addRes }

        let commitMsg = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Update API Workspace" : message
        return runGit(args: ["commit", "-m", commitMsg], inDirectory: dirPath)
    }

    public static func push(
        inDirectory dirPath: String,
        remoteName: String = "origin",
        branch: String = "main"
    ) -> GitCommandResult {
        runGit(args: ["push", "-u", remoteName, branch], inDirectory: dirPath)
    }

    public static func pull(
        inDirectory dirPath: String,
        remoteName: String = "origin",
        branch: String = "main"
    ) -> GitCommandResult {
        runGit(args: ["pull", "--rebase", remoteName, branch], inDirectory: dirPath)
    }

    public static func clone(
        repoUrl: String,
        destination: String,
        branch: String? = nil
    ) -> GitCommandResult {
        var args = ["clone"]
        if let b = branch, !b.isEmpty {
            args.append(contentsOf: ["-b", b])
        }
        args.append(contentsOf: [repoUrl, destination])
        return runGit(args: args, inDirectory: FileManager.default.temporaryDirectory.path)
    }
}
