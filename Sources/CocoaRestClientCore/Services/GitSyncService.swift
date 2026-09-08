//
//  GitSyncService.swift
//  CocoaRestClientCore
//

import Foundation

/// Outcome of a Git operation, shaped for direct display in the sync banner.
public struct GitOperationResult: Sendable {
    public let isSuccess: Bool
    public let output: String
    public let error: String
    /// Files both sides changed, when that is why the operation stopped. The
    /// caller can offer to keep one side instead of parsing `error` for paths.
    public let conflictingPaths: [String]

    public init(
        isSuccess: Bool,
        output: String = "",
        error: String = "",
        conflictingPaths: [String] = []
    ) {
        self.isSuccess = isSuccess
        self.output = output
        self.error = error
        self.conflictingPaths = conflictingPaths
    }

    static func success(_ output: String = "") -> GitOperationResult {
        GitOperationResult(isSuccess: true, output: output)
    }

    static func failure(_ error: Error) -> GitOperationResult {
        GitOperationResult(isSuccess: false, error: String(describing: error))
    }

    static func failure(message: String, conflictingPaths: [String] = []) -> GitOperationResult {
        GitOperationResult(isSuccess: false, error: message, conflictingPaths: conflictingPaths)
    }
}

/// Git operations for workspace synchronisation, implemented on libgit2.
///
/// The app runs in the App Sandbox: it cannot spawn `/usr/bin/git`, and it has
/// no access to the user's `~/.gitconfig` or to `git-credential-osxkeychain`.
/// Everything the library needs — the author identity and the HTTPS credentials
/// — therefore comes from the workspace settings and this app's own keychain.
public struct GitSyncService: Sendable {
    public static let defaultRemoteName = "origin"

    public init() {}

    // MARK: - Inspection

    public static func isRepository(atDirectory dirPath: String) -> Bool {
        GitRepository.exists(at: dirPath)
    }

    public static func getStatus(inDirectory dirPath: String) -> GitSyncStatus {
        guard isRepository(atDirectory: dirPath) else {
            return GitSyncStatus(isGitRepo: false)
        }

        do {
            let repo = try GitRepository.open(at: dirPath)
            let branch = repo.currentBranchName() ?? "main"
            // No fetch here: this runs synchronously from the UI on every
            // workspace refresh, so it reports what the last fetch recorded.
            let (ahead, behind) = repo.aheadBehind()

            return GitSyncStatus(
                isGitRepo: true,
                currentBranch: branch.isEmpty ? "main" : branch,
                hasUncommittedChanges: try repo.hasUncommittedChanges(),
                unpushedCommitCount: ahead,
                behindCommitCount: behind,
                lastSyncDate: Date(),
                lastCommitMessage: repo.headCommitMessage(),
                errorMessage: nil
            )
        } catch {
            return GitSyncStatus(isGitRepo: true, errorMessage: String(describing: error))
        }
    }

    // MARK: - Repository setup

    public static func initRepository(
        inDirectory dirPath: String,
        defaultBranch: String = "main"
    ) -> GitOperationResult {
        do {
            _ = try GitRepository.create(at: dirPath, initialBranch: defaultBranch)
            return .success("Initialised empty Git repository in \(dirPath)")
        } catch {
            return .failure(error)
        }
    }

    public static func setRemote(
        url: String,
        inDirectory dirPath: String,
        remoteName: String = defaultRemoteName
    ) -> GitOperationResult {
        do {
            let repo = try GitRepository.open(at: dirPath)
            try repo.setRemote(named: remoteName, url: url)
            return .success("Remote \(remoteName) set to \(url)")
        } catch {
            return .failure(error)
        }
    }

    /// Removing a remote that was never added is not an error worth surfacing,
    /// so the result is only useful for diagnostics.
    @discardableResult
    public static func removeRemote(
        inDirectory dirPath: String,
        remoteName: String = defaultRemoteName
    ) -> GitOperationResult {
        do {
            let repo = try GitRepository.open(at: dirPath)
            return repo.removeRemote(named: remoteName)
                ? .success("Removed remote \(remoteName)")
                : .failure(message: "No remote named \(remoteName)")
        } catch {
            return .failure(error)
        }
    }

    public static func remoteUrl(
        inDirectory dirPath: String,
        remoteName: String = defaultRemoteName
    ) -> String? {
        guard let repo = try? GitRepository.open(at: dirPath) else { return nil }
        return repo.remoteUrl(named: remoteName)
    }

    // MARK: - Committing

    public static func commitAll(
        message: String,
        inDirectory dirPath: String,
        authorName: String = "",
        authorEmail: String = ""
    ) -> GitOperationResult {
        do {
            let repo = try GitRepository.open(at: dirPath)
            try repo.stageAll()

            let commitMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Update API Workspace"
                : message

            guard let commitId = try repo.commitStagedChanges(
                message: commitMessage,
                authorName: authorName,
                authorEmail: authorEmail
            ) else {
                return .success("nothing to commit, working tree clean")
            }
            return .success("Committed \(String(commitId.prefix(7))): \(commitMessage)")
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Network operations

    public static func push(
        inDirectory dirPath: String,
        remoteName: String = defaultRemoteName,
        branch: String = "main",
        credentials: GitCredentials? = nil
    ) -> GitOperationResult {
        let repo: GitRepository
        do {
            repo = try GitRepository.open(at: dirPath)
        } catch {
            return .failure(error)
        }

        let resolved = credentials ?? storedCredentials(for: repo, remoteName: remoteName)
        do {
            try repo.push(remoteName: remoteName, branch: branch, credentials: resolved)
            return .success("Pushed \(branch) to \(remoteName)")
        } catch let error as GitError where error.isNonFastForward {
            // The remote moved on. Fetching updates the remote-tracking ref, so
            // the status panel can show how far behind the branch is instead of
            // still claiming it is only ahead.
            try? repo.fetch(remoteName: remoteName, branch: branch, credentials: resolved)
            let behind = repo.aheadBehind().behind
            let amount = behind > 0
                ? "\(behind) commit\(behind == 1 ? "" : "s")"
                : "commits"
            return .failure(
                message: "\(remoteName)/\(branch) has \(amount) that you do not have yet. "
                    + "Press \"Get Latest\" to bring them in, then push again."
            )
        } catch {
            return .failure(error)
        }
    }

    public static func fetch(
        inDirectory dirPath: String,
        remoteName: String = defaultRemoteName,
        branch: String = "main",
        credentials: GitCredentials? = nil
    ) -> GitOperationResult {
        do {
            let repo = try GitRepository.open(at: dirPath)
            let resolved = credentials ?? storedCredentials(for: repo, remoteName: remoteName)
            try repo.fetch(remoteName: remoteName, branch: branch, credentials: resolved)
            return .success("Fetched \(remoteName)/\(branch)")
        } catch {
            return .failure(error)
        }
    }

    /// Fetches and integrates the remote branch. Conflicts are reported rather
    /// than left in the working tree — the merge is rolled back first.
    public static func pull(
        inDirectory dirPath: String,
        remoteName: String = defaultRemoteName,
        branch: String = "main",
        authorName: String = "",
        authorEmail: String = "",
        credentials: GitCredentials? = nil,
        favoring favor: GitMergeFavor = .reportConflict
    ) -> GitOperationResult {
        do {
            let repo = try GitRepository.open(at: dirPath)
            let resolved = credentials ?? storedCredentials(for: repo, remoteName: remoteName)
            let outcome = try repo.pull(
                remoteName: remoteName,
                branch: branch,
                credentials: resolved,
                authorName: authorName,
                authorEmail: authorEmail,
                favoring: favor
            )

            switch outcome {
            case .upToDate:
                return .success("Already up to date")
            case .fastForwarded:
                return .success("Fast-forwarded \(branch) to \(remoteName)/\(branch)")
            case .merged:
                switch favor {
                case .reportConflict:
                    return .success("Merged \(remoteName)/\(branch) into \(branch)")
                case .local:
                    return .success("Kept your version and merged \(remoteName)/\(branch)")
                case .remote:
                    return .success("Took the \(remoteName)/\(branch) version")
                }
            case .conflicted(let paths):
                let list = paths.isEmpty ? "" : ": \(paths.joined(separator: ", "))"
                // Pushing is not one of the options here: the branch has
                // diverged, so the push would be rejected as non-fast-forward.
                // One side has to be given up, and neither the merge nor that
                // choice is something this app can do yet.
                return .failure(
                    message: "The remote changed the same files you did\(list). "
                        + "Your workspace was left untouched — keep your version or take the "
                        + "repository's to continue.",
                    conflictingPaths: paths
                )
            }
        } catch {
            return .failure(error)
        }
    }

    public static func clone(
        repoUrl: String,
        destination: String,
        branch: String? = nil,
        credentials: GitCredentials? = nil
    ) -> GitOperationResult {
        do {
            let resolved = credentials ?? GitCredentialStore.load(forRemoteUrl: repoUrl)
            _ = try GitRepository.clone(
                url: repoUrl,
                into: destination,
                branch: branch,
                credentials: resolved
            )
            return .success("Cloned \(repoUrl) into \(destination)")
        } catch {
            return .failure(error)
        }
    }

    private static func storedCredentials(
        for repo: GitRepository,
        remoteName: String
    ) -> GitCredentials? {
        guard let url = repo.remoteUrl(named: remoteName) else { return nil }
        return GitCredentialStore.load(forRemoteUrl: url)
    }
}
