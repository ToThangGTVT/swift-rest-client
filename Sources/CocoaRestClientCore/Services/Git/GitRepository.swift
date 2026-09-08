//
//  GitRepository.swift
//  CocoaRestClientCore
//

import Foundation
import Clibgit2

/// What a pull actually did, so the caller can phrase a useful message.
public enum GitPullOutcome: Sendable, Equatable {
    case upToDate
    case fastForwarded
    case merged
    case conflicted(paths: [String])
}

/// Which side wins when a pull finds both sides changed the same file.
public enum GitMergeFavor: Sendable, Equatable {
    /// Stop and report the conflicting paths, changing nothing.
    case reportConflict
    /// Keep the version in this workspace.
    case local
    /// Take the version from the remote.
    case remote
}

/// Authentication state for a single network operation.
///
/// libgit2 asks for credentials through a C callback, which cannot capture
/// context, so the instance is handed over as the callback's payload.
final class GitAuthSession {
    let credentials: GitCredentials?
    var attempts: Int = 0

    init(credentials: GitCredentials?) {
        self.credentials = credentials
    }

    func makeCallbacks() -> git_remote_callbacks {
        var callbacks = git_remote_callbacks()
        git_remote_init_callbacks(&callbacks, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
        callbacks.credentials = gitCredentialsCallback
        callbacks.payload = Unmanaged.passUnretained(self).toOpaque()
        return callbacks
    }
}

private let gitCredentialsCallback: git_credential_acquire_cb = { out, _, usernameFromUrl, allowedTypes, payload in
    guard let out, let payload else { return -1 }
    let session = Unmanaged<GitAuthSession>.fromOpaque(payload).takeUnretainedValue()

    // libgit2 calls back again after the server rejects an attempt. Failing on
    // the second pass turns an endless retry loop into a clear error.
    session.attempts += 1
    guard session.attempts <= 1 else {
        git_error_set_str(Int32(GIT_ERROR_NET.rawValue),
                          "The Git server rejected these credentials.")
        return -1
    }

    if allowedTypes & GIT_CREDENTIAL_USERPASS_PLAINTEXT.rawValue != 0 {
        guard let credentials = session.credentials, !credentials.secret.isEmpty else {
            git_error_set_str(Int32(GIT_ERROR_NET.rawValue),
                              "This repository needs credentials. Add a username and personal access token in the workspace's repository settings.")
            return -1
        }
        // Hosts that authenticate by token accept any non-empty username, so an
        // unset one falls back to whatever the URL carried.
        var username = credentials.username
        if username.isEmpty, let fromUrl = usernameFromUrl {
            username = String(cString: fromUrl)
        }
        if username.isEmpty { username = "git" }

        return username.withCString { user in
            credentials.secret.withCString { secret in
                git_credential_userpass_plaintext_new(out, user, secret)
            }
        }
    }

    if allowedTypes & GIT_CREDENTIAL_DEFAULT.rawValue != 0 {
        return git_credential_default_new(out)
    }

    git_error_set_str(Int32(GIT_ERROR_NET.rawValue),
                      "This remote requires SSH authentication, which the sandboxed app cannot use. Switch the remote to an HTTPS URL.")
    return -1
}

func gitOidString(_ oid: git_oid) -> String {
    var value = oid
    var buffer = [CChar](repeating: 0, count: Int(GIT_OID_MAX_HEXSIZE) + 1)
    git_oid_tostr(&buffer, buffer.count, &value)
    return String(cString: buffer)
}

/// Owns a `git_repository *` for its lifetime.
final class GitRepository {
    let pointer: OpaquePointer

    private init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        git_repository_free(pointer)
    }

    // MARK: - Opening & creating

    /// True when `path` is itself a repository. Parent directories are not
    /// searched, so a workspace inside an unrelated repo is not mistaken for one.
    static func exists(at path: String) -> Bool {
        guard !path.isEmpty else { return false }
        LibGit2.activate()
        return git_repository_open_ext(nil, path, GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, nil) == 0
    }

    static func open(at path: String) throws -> GitRepository {
        LibGit2.activate()
        var repo: OpaquePointer?
        try gitTry("Open repository") {
            git_repository_open_ext(&repo, path, GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, nil)
        }
        guard let repo else {
            throw GitError(code: -1, message: "Open repository: no repository at \(path)")
        }
        return GitRepository(pointer: repo)
    }

    static func create(at path: String, initialBranch: String) throws -> GitRepository {
        LibGit2.activate()
        var options = git_repository_init_options()
        try gitTry("Initialise repository") {
            git_repository_init_options_init(&options, UInt32(GIT_REPOSITORY_INIT_OPTIONS_VERSION))
        }
        options.flags = GIT_REPOSITORY_INIT_MKPATH.rawValue

        let branch = initialBranch.isEmpty ? "main" : initialBranch
        var repo: OpaquePointer?
        try branch.withCString { head in
            options.initial_head = head
            try gitTry("Initialise repository") {
                git_repository_init_ext(&repo, path, &options)
            }
        }
        guard let repo else {
            throw GitError(code: -1, message: "Initialise repository: could not create \(path)")
        }
        return GitRepository(pointer: repo)
    }

    static func clone(
        url: String,
        into path: String,
        branch: String?,
        credentials: GitCredentials?
    ) throws -> GitRepository {
        LibGit2.activate()
        let session = GitAuthSession(credentials: credentials)

        var options = git_clone_options()
        try gitTry("Clone") { git_clone_options_init(&options, UInt32(GIT_CLONE_OPTIONS_VERSION)) }
        options.fetch_opts.callbacks = session.makeCallbacks()

        var repo: OpaquePointer?
        _ = try withExtendedLifetime(session) {
            if let branch, !branch.isEmpty {
                try branch.withCString { name in
                    options.checkout_branch = name
                    try gitTry("Clone \(url)") { git_clone(&repo, url, path, &options) }
                }
            } else {
                try gitTry("Clone \(url)") { git_clone(&repo, url, path, &options) }
            }
        }
        guard let repo else {
            throw GitError(code: -1, message: "Clone \(url): no repository was created")
        }
        return GitRepository(pointer: repo)
    }

    // MARK: - Inspection

    /// The checked-out branch, including the not-yet-created branch of a repo
    /// that has no commits.
    func currentBranchName() -> String? {
        var head: OpaquePointer?
        if git_repository_head(&head, pointer) == 0 {
            defer { git_reference_free(head) }
            guard let name = git_reference_shorthand(head) else { return nil }
            return String(cString: name)
        }

        var ref: OpaquePointer?
        guard git_reference_lookup(&ref, pointer, "HEAD") == 0 else { return nil }
        defer { git_reference_free(ref) }
        guard let target = git_reference_symbolic_target(ref) else { return nil }

        let fullName = String(cString: target)
        let prefix = "refs/heads/"
        return fullName.hasPrefix(prefix) ? String(fullName.dropFirst(prefix.count)) : fullName
    }

    func hasUncommittedChanges() throws -> Bool {
        var options = git_status_options()
        try gitTry("Read status") { git_status_options_init(&options, UInt32(GIT_STATUS_OPTIONS_VERSION)) }
        options.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR
        options.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
            | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue

        var list: OpaquePointer?
        try gitTry("Read status") { git_status_list_new(&list, pointer, &options) }
        defer { git_status_list_free(list) }

        return git_status_list_entrycount(list) > 0
    }

    /// Caller takes ownership and must `git_commit_free` the result.
    private func lookupHeadCommit() -> OpaquePointer? {
        var commit: OpaquePointer?
        guard git_revparse_single(&commit, pointer, "HEAD") == 0 else { return nil }
        return commit
    }

    func headCommitMessage() -> String? {
        guard let commit = lookupHeadCommit() else { return nil }
        defer { git_commit_free(commit) }
        guard let message = git_commit_message(commit) else { return nil }
        return String(cString: message).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Commits on the local branch that its upstream does not have, and vice
    /// versa. Both are zero when no upstream is configured yet.
    func aheadBehind() -> (ahead: Int, behind: Int) {
        var head: OpaquePointer?
        guard git_repository_head(&head, pointer) == 0 else { return (0, 0) }
        defer { git_reference_free(head) }

        var upstream: OpaquePointer?
        guard git_branch_upstream(&upstream, head) == 0 else { return (0, 0) }
        defer { git_reference_free(upstream) }

        guard let localOid = git_reference_target(head),
              let upstreamOid = git_reference_target(upstream)
        else { return (0, 0) }

        var ahead = 0
        var behind = 0
        guard git_graph_ahead_behind(&ahead, &behind, pointer, localOid, upstreamOid) == 0 else {
            return (0, 0)
        }
        return (ahead, behind)
    }

    // MARK: - Staging & committing

    /// Equivalent of `git add -A`: `add_all` records new and modified files,
    /// `update_all` records the ones that disappeared from the working tree.
    func stageAll() throws {
        var index: OpaquePointer?
        try gitTry("Open index") { git_repository_index(&index, pointer) }
        defer { git_index_free(index) }

        try gitTry("Stage changes") {
            git_index_add_all(index, nil, GIT_INDEX_ADD_DEFAULT.rawValue, nil, nil)
        }
        try gitTry("Stage deletions") { git_index_update_all(index, nil, nil, nil) }
        try gitTry("Write index") { git_index_write(index) }
    }

    /// Writes the staged tree as a commit. Returns `nil` when the tree matches
    /// HEAD — the libgit2 equivalent of "nothing to commit".
    func commitStagedChanges(message: String, authorName: String, authorEmail: String) throws -> String? {
        var index: OpaquePointer?
        try gitTry("Open index") { git_repository_index(&index, pointer) }
        defer { git_index_free(index) }

        var treeOid = git_oid()
        try gitTry("Write tree") { git_index_write_tree(&treeOid, index) }

        let parent = lookupHeadCommit()
        defer { if let parent { git_commit_free(parent) } }

        if let parent, let parentTreeOid = git_commit_tree_id(parent),
           git_oid_equal(&treeOid, parentTreeOid) != 0 {
            return nil
        }

        var tree: OpaquePointer?
        try gitTry("Look up tree") { git_tree_lookup(&tree, pointer, &treeOid) }
        defer { git_tree_free(tree) }

        let signature = try makeSignature(name: authorName, email: authorEmail)
        defer { git_signature_free(signature) }

        var commitOid = git_oid()
        if let parent {
            var parents: [OpaquePointer?] = [parent]
            try gitTry("Create commit") {
                git_commit_create(&commitOid, pointer, "HEAD", signature, signature,
                                  nil, message, tree, 1, &parents)
            }
        } else {
            try gitTry("Create commit") {
                git_commit_create(&commitOid, pointer, "HEAD", signature, signature,
                                  nil, message, tree, 0, nil)
            }
        }
        return gitOidString(commitOid)
    }

    private func makeSignature(name: String, email: String) throws -> UnsafeMutablePointer<git_signature>? {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        var signature: UnsafeMutablePointer<git_signature>?
        // A repo-local identity is not guaranteed to exist inside the sandbox,
        // so the workspace's own author details are the primary source.
        if !resolvedName.isEmpty || !resolvedEmail.isEmpty {
            try gitTry("Build commit signature") {
                git_signature_now(&signature,
                                  resolvedName.isEmpty ? "CocoaRestClient" : resolvedName,
                                  resolvedEmail.isEmpty ? "restclient@local" : resolvedEmail)
            }
            return signature
        }

        if git_signature_default(&signature, pointer) == 0 {
            return signature
        }
        try gitTry("Build commit signature") {
            git_signature_now(&signature, "CocoaRestClient", "restclient@local")
        }
        return signature
    }

    // MARK: - Remotes

    func remoteUrl(named name: String) -> String? {
        var remote: OpaquePointer?
        guard git_remote_lookup(&remote, pointer, name) == 0 else { return nil }
        defer { git_remote_free(remote) }
        guard let url = git_remote_url(remote) else { return nil }
        return String(cString: url)
    }

    func setRemote(named name: String, url: String) throws {
        // Replacing outright keeps a stale URL from lingering under the same name.
        git_remote_delete(pointer, name)
        var remote: OpaquePointer?
        try gitTry("Set remote \(name)") { git_remote_create(&remote, pointer, name, url) }
        git_remote_free(remote)
    }

    @discardableResult
    func removeRemote(named name: String) -> Bool {
        git_remote_delete(pointer, name) == 0
    }

    // MARK: - Network operations

    func push(remoteName: String, branch: String, credentials: GitCredentials?) throws {
        var remote: OpaquePointer?
        try gitTry("Look up remote \(remoteName)") { git_remote_lookup(&remote, pointer, remoteName) }
        defer { git_remote_free(remote) }

        let session = GitAuthSession(credentials: credentials)
        var options = git_push_options()
        try gitTry("Push") { git_push_options_init(&options, UInt32(GIT_PUSH_OPTIONS_VERSION)) }
        options.callbacks = session.makeCallbacks()

        _ = try withExtendedLifetime(session) {
            try withGitStrArray(["refs/heads/\(branch):refs/heads/\(branch)"]) { refspecs in
                try gitTry("Push to \(remoteName)/\(branch)") {
                    git_remote_push(remote, &refspecs, &options)
                }
            }
        }

        // The remote-tracking ref only appears after a fetch, and the ahead/behind
        // counter in the UI needs it, so the branch is wired to its upstream here.
        try? fetch(remoteName: remoteName, branch: branch, credentials: credentials)
        setUpstreamIfPossible(remoteName: remoteName, branch: branch)
    }

    func fetch(remoteName: String, branch: String, credentials: GitCredentials?) throws {
        var remote: OpaquePointer?
        try gitTry("Look up remote \(remoteName)") { git_remote_lookup(&remote, pointer, remoteName) }
        defer { git_remote_free(remote) }

        let session = GitAuthSession(credentials: credentials)
        var options = git_fetch_options()
        try gitTry("Fetch") { git_fetch_options_init(&options, UInt32(GIT_FETCH_OPTIONS_VERSION)) }
        options.callbacks = session.makeCallbacks()

        let refspec = "+refs/heads/\(branch):refs/remotes/\(remoteName)/\(branch)"
        _ = try withExtendedLifetime(session) {
            try withGitStrArray([refspec]) { refspecs in
                try gitTry("Fetch from \(remoteName)") {
                    git_remote_fetch(remote, &refspecs, &options, nil)
                }
            }
        }
    }

    private func setUpstreamIfPossible(remoteName: String, branch: String) {
        var head: OpaquePointer?
        guard git_repository_head(&head, pointer) == 0 else { return }
        defer { git_reference_free(head) }
        git_branch_set_upstream(head, "\(remoteName)/\(branch)")
    }

    /// Fetches and integrates the remote branch: fast-forward when possible,
    /// a real merge commit otherwise, and a clean bail-out on conflicts.
    func pull(
        remoteName: String,
        branch: String,
        credentials: GitCredentials?,
        authorName: String,
        authorEmail: String,
        favoring favor: GitMergeFavor = .reportConflict
    ) throws -> GitPullOutcome {
        try fetch(remoteName: remoteName, branch: branch, credentials: credentials)

        var remoteRef: OpaquePointer?
        try gitTry("Find \(remoteName)/\(branch)") {
            git_reference_lookup(&remoteRef, pointer, "refs/remotes/\(remoteName)/\(branch)")
        }
        defer { git_reference_free(remoteRef) }

        guard let remoteOidPointer = git_reference_target(remoteRef) else {
            throw GitError(code: -1, message: "Pull: \(remoteName)/\(branch) has no commits")
        }
        let remoteOid = remoteOidPointer.pointee

        var theirHead: OpaquePointer?
        var oid = remoteOid
        try gitTry("Prepare merge") { git_annotated_commit_lookup(&theirHead, pointer, &oid) }
        defer { git_annotated_commit_free(theirHead) }

        var heads: [OpaquePointer?] = [theirHead]
        var analysis = git_merge_analysis_t(0)
        var preference = git_merge_preference_t(0)
        try gitTry("Analyse merge") {
            git_merge_analysis(&analysis, &preference, pointer, &heads, 1)
        }

        if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
            return .upToDate
        }

        if analysis.rawValue & GIT_MERGE_ANALYSIS_UNBORN.rawValue != 0
            || analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0 {
            try fastForward(to: remoteOid, branch: branch)
            return .fastForwarded
        }

        return try performMerge(heads: &heads, authorName: authorName, authorEmail: authorEmail,
                                remoteName: remoteName, branch: branch, favoring: favor)
    }

    /// Throws away a half-applied merge: the index conflicts and the conflict
    /// markers `git_merge` wrote into the tracked files both go away.
    private func discardMergeInProgress() throws {
        guard let head = lookupHeadCommit() else { return }
        defer { git_commit_free(head) }

        var checkoutOptions = git_checkout_options()
        try gitTry("Discard merge") {
            git_checkout_options_init(&checkoutOptions, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        }
        try gitTry("Discard merge") {
            git_reset(pointer, head, GIT_RESET_HARD, &checkoutOptions)
        }
    }

    private func fastForward(to oid: git_oid, branch: String) throws {
        var target = oid
        var commit: OpaquePointer?
        try gitTry("Look up commit") { git_commit_lookup(&commit, pointer, &target) }
        defer { git_commit_free(commit) }

        var checkoutOptions = git_checkout_options()
        try gitTry("Checkout") {
            git_checkout_options_init(&checkoutOptions, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        }
        checkoutOptions.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue
        try gitTry("Update working tree") {
            git_checkout_tree(pointer, commit, &checkoutOptions)
        }

        var head: OpaquePointer?
        if git_repository_head(&head, pointer) == 0 {
            defer { git_reference_free(head) }
            var moved: OpaquePointer?
            try gitTry("Move branch") {
                git_reference_set_target(&moved, head, &target, "pull: fast-forward")
            }
            git_reference_free(moved)
            return
        }

        // Unborn HEAD: the branch itself does not exist yet.
        var created: OpaquePointer?
        try gitTry("Create branch \(branch)") {
            git_reference_create(&created, pointer, "refs/heads/\(branch)", &target, 0, "pull: create branch")
        }
        git_reference_free(created)
        try gitTry("Point HEAD at \(branch)") {
            git_repository_set_head(pointer, "refs/heads/\(branch)")
        }
    }

    private func performMerge(
        heads: inout [OpaquePointer?],
        authorName: String,
        authorEmail: String,
        remoteName: String,
        branch: String,
        favoring favor: GitMergeFavor
    ) throws -> GitPullOutcome {
        var mergeOptions = git_merge_options()
        try gitTry("Merge") { git_merge_options_init(&mergeOptions, UInt32(GIT_MERGE_OPTIONS_VERSION)) }

        // Letting libgit2 pick the winning side per file resolves the conflict
        // inside the merge itself, so the result is an ordinary merge commit
        // that the remote accepts as a fast-forward. Force-pushing, the other
        // way out of a divergence, would drop the other side's commits.
        switch favor {
        case .reportConflict: break
        case .local: mergeOptions.file_favor = GIT_MERGE_FILE_FAVOR_OURS
        case .remote: mergeOptions.file_favor = GIT_MERGE_FILE_FAVOR_THEIRS
        }

        var checkoutOptions = git_checkout_options()
        try gitTry("Merge") {
            git_checkout_options_init(&checkoutOptions, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        }
        checkoutOptions.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue
            | GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue

        try gitTry("Merge \(remoteName)/\(branch)") {
            git_merge(pointer, &heads, heads.count, &mergeOptions, &checkoutOptions)
        }

        var index: OpaquePointer?
        try gitTry("Open index") { git_repository_index(&index, pointer) }
        defer { git_index_free(index) }

        if git_index_has_conflicts(index) != 0 {
            let paths = conflictPaths(in: index)
            // `git_merge` ran with GIT_CHECKOUT_ALLOW_CONFLICTS, so by now it has
            // written conflict markers into the working tree and conflict entries
            // into the index. State cleanup alone only drops MERGE_HEAD and would
            // leave those behind — for this app that means handing the UI JSON
            // files it can no longer parse. Reset to HEAD so the workspace really
            // is untouched, which is what the caller reports.
            try discardMergeInProgress()
            git_repository_state_cleanup(pointer)
            return .conflicted(paths: paths)
        }

        var treeOid = git_oid()
        try gitTry("Write merged tree") { git_index_write_tree(&treeOid, index) }

        var tree: OpaquePointer?
        try gitTry("Look up merged tree") { git_tree_lookup(&tree, pointer, &treeOid) }
        defer { git_tree_free(tree) }

        guard let localParent = lookupHeadCommit() else {
            throw GitError(code: -1, message: "Merge: local branch has no commits")
        }
        defer { git_commit_free(localParent) }

        var remoteOid = git_annotated_commit_id(heads[0]).pointee
        var remoteParent: OpaquePointer?
        try gitTry("Look up remote commit") { git_commit_lookup(&remoteParent, pointer, &remoteOid) }
        defer { git_commit_free(remoteParent) }

        let signature = try makeSignature(name: authorName, email: authorEmail)
        defer { git_signature_free(signature) }

        var parents: [OpaquePointer?] = [localParent, remoteParent]
        var commitOid = git_oid()
        let subject: String
        switch favor {
        case .reportConflict: subject = "Merge \(remoteName)/\(branch)"
        case .local: subject = "Merge \(remoteName)/\(branch), keeping the local version"
        case .remote: subject = "Merge \(remoteName)/\(branch), taking the remote version"
        }
        try gitTry("Create merge commit") {
            git_commit_create(&commitOid, pointer, "HEAD", signature, signature, nil,
                              subject, tree, parents.count, &parents)
        }

        git_repository_state_cleanup(pointer)
        return .merged
    }

    private func conflictPaths(in index: OpaquePointer?) -> [String] {
        var iterator: OpaquePointer?
        guard git_index_conflict_iterator_new(&iterator, index) == 0 else { return [] }
        defer { git_index_conflict_iterator_free(iterator) }

        var paths: [String] = []
        while true {
            var ancestor: UnsafePointer<git_index_entry>?
            var ours: UnsafePointer<git_index_entry>?
            var theirs: UnsafePointer<git_index_entry>?
            guard git_index_conflict_next(&ancestor, &ours, &theirs, iterator) == 0 else { break }

            if let path = ours?.pointee.path ?? theirs?.pointee.path ?? ancestor?.pointee.path {
                paths.append(String(cString: path))
            }
        }
        return paths
    }
}
