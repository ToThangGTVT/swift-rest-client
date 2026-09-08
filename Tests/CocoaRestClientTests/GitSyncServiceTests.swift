//
//  GitSyncServiceTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class GitSyncServiceTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("GitSyncServiceTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testGitInitializationAndStatus() {
        let initialStatus = GitSyncService.getStatus(inDirectory: tempDir.path)
        XCTAssertFalse(initialStatus.isGitRepo)

        let initRes = GitSyncService.initRepository(inDirectory: tempDir.path, defaultBranch: "main")
        XCTAssertTrue(initRes.isSuccess)

        let statusAfterInit = GitSyncService.getStatus(inDirectory: tempDir.path)
        XCTAssertTrue(statusAfterInit.isGitRepo)
        XCTAssertFalse(statusAfterInit.hasUncommittedChanges)

        // Create a file to test uncommitted changes
        let testFile = tempDir.appendingPathComponent("test.json")
        try? "{}".write(to: testFile, atomically: true, encoding: .utf8)

        let statusWithChanges = GitSyncService.getStatus(inDirectory: tempDir.path)
        XCTAssertTrue(statusWithChanges.hasUncommittedChanges)

        // Commit changes
        let commitRes = GitSyncService.commitAll(
            message: "Initial commit",
            inDirectory: tempDir.path,
            authorName: "Test User",
            authorEmail: "test@example.com"
        )
        XCTAssertTrue(commitRes.isSuccess)

        let statusAfterCommit = GitSyncService.getStatus(inDirectory: tempDir.path)
        XCTAssertFalse(statusAfterCommit.hasUncommittedChanges)
    }

    // MARK: - Ahead / behind reporting

    /// A clone whose remote has moved on has to report itself as behind, because
    /// that is the state in which a push gets rejected as non-fast-forward.
    func testStatusReportsCommitsBehindRemote() throws {
        let remote = try makeBareRemote()
        let local = try clone(remote, as: "local")

        XCTAssertEqual(GitSyncService.getStatus(inDirectory: local.path).behindCommitCount, 0)

        try pushFromAnotherClone(of: remote, writing: "{}", to: "theirs.json")
        XCTAssertTrue(GitSyncService.fetch(inDirectory: local.path).isSuccess)

        let status = GitSyncService.getStatus(inDirectory: local.path)
        XCTAssertEqual(status.behindCommitCount, 1)
        XCTAssertEqual(status.unpushedCommitCount, 0)
    }

    // MARK: - Diverged push

    /// The libgit2 rejection message is opaque, so a diverged push has to come
    /// back naming the fix and leave the branch reporting how far behind it is.
    func testDivergedPushFailsWithGetLatestGuidance() throws {
        let (_, local) = try makeDivergedPair(file: "collections.json")

        let pushRes = GitSyncService.push(inDirectory: local.path)
        XCTAssertFalse(pushRes.isSuccess)
        XCTAssertTrue(pushRes.error.contains("Get Latest"), pushRes.error)

        // The failed push fetches, so the panel can now show the real numbers.
        let status = GitSyncService.getStatus(inDirectory: local.path)
        XCTAssertEqual(status.behindCommitCount, 1)
        XCTAssertEqual(status.unpushedCommitCount, 1)
    }

    /// The second wording libgit2 uses: once the remote commit has been fetched
    /// it exists locally, so the rejection comes back as "non-fastforwardable"
    /// instead. Both have to map to the same guidance.
    func testDivergedPushAfterFetchAlsoReportsGuidance() throws {
        let (_, local) = try makeDivergedPair(file: "collections.json")
        XCTAssertTrue(GitSyncService.fetch(inDirectory: local.path).isSuccess)

        let pushRes = GitSyncService.push(inDirectory: local.path)
        XCTAssertFalse(pushRes.isSuccess)
        XCTAssertTrue(pushRes.error.contains("Get Latest"), pushRes.error)
        XCTAssertFalse(pushRes.error.contains("fastforwardable"), pushRes.error)
    }

    // MARK: - Conflicts

    /// A conflicted pull reports that nothing changed locally, so it has to
    /// actually leave the workspace alone: `git_merge` writes conflict markers
    /// into the tracked files, and JSON carrying those is unreadable to the app.
    func testConflictedPullLeavesWorkspaceUntouched() throws {
        let (_, local) = try makeDivergedPair(file: "collections.json")

        let pullRes = GitSyncService.pull(inDirectory: local.path, authorName: "T", authorEmail: "t@e.com")
        XCTAssertFalse(pullRes.isSuccess)

        let content = try String(contentsOf: local.appendingPathComponent("collections.json"), encoding: .utf8)
        XCTAssertFalse(content.contains("<<<<<<<"), "conflict markers were left in the workspace")
        XCTAssertEqual(content, mine)

        // No half-merge left behind either: the index and tree match HEAD again.
        XCTAssertFalse(GitSyncService.getStatus(inDirectory: local.path).hasUncommittedChanges)
    }

    /// The conflict has to reach the caller as data, not just prose, or the UI
    /// cannot offer a choice of sides.
    func testConflictedPullReportsPathsForTheUI() throws {
        let (_, local) = try makeDivergedPair(file: "collections.json")

        let pullRes = GitSyncService.pull(inDirectory: local.path, authorName: "T", authorEmail: "t@e.com")
        XCTAssertFalse(pullRes.isSuccess)
        XCTAssertEqual(pullRes.conflictingPaths, ["collections.json"])
    }

    func testResolvingConflictKeepingLocalMergesAndAllowsPush() throws {
        let (_, local) = try makeDivergedPair(file: "collections.json")

        let mergeRes = GitSyncService.pull(
            inDirectory: local.path, authorName: "T", authorEmail: "t@e.com", favoring: .local
        )
        XCTAssertTrue(mergeRes.isSuccess, mergeRes.error)

        let content = try String(contentsOf: local.appendingPathComponent("collections.json"), encoding: .utf8)
        XCTAssertEqual(content, mine)

        // A merge commit descends from the remote tip, so the push is accepted
        // without a force and the divergence is over.
        let pushRes = GitSyncService.push(inDirectory: local.path)
        XCTAssertTrue(pushRes.isSuccess, pushRes.error)

        let status = GitSyncService.getStatus(inDirectory: local.path)
        XCTAssertEqual(status.behindCommitCount, 0)
        XCTAssertEqual(status.unpushedCommitCount, 0)
    }

    func testResolvingConflictKeepingRemoteTakesTheirContent() throws {
        let (_, local) = try makeDivergedPair(file: "collections.json")

        let mergeRes = GitSyncService.pull(
            inDirectory: local.path, authorName: "T", authorEmail: "t@e.com", favoring: .remote
        )
        XCTAssertTrue(mergeRes.isSuccess, mergeRes.error)

        let content = try String(contentsOf: local.appendingPathComponent("collections.json"), encoding: .utf8)
        XCTAssertEqual(content, theirs)
        XCTAssertTrue(GitSyncService.push(inDirectory: local.path).isSuccess)
    }

    /// Files only one side touched still merge normally when a favour is set —
    /// picking a side must not throw the other side's other work away.
    func testResolvingConflictKeepsNonConflictingRemoteFiles() throws {
        let (remote, local) = try makeDivergedPair(file: "collections.json")
        try pushFromAnotherClone(of: remote, writing: "{\"env\":1}", to: "environments.json")

        let mergeRes = GitSyncService.pull(
            inDirectory: local.path, authorName: "T", authorEmail: "t@e.com", favoring: .local
        )
        XCTAssertTrue(mergeRes.isSuccess, mergeRes.error)

        let untouched = try String(contentsOf: local.appendingPathComponent("environments.json"), encoding: .utf8)
        XCTAssertEqual(untouched, "{\"env\":1}")
    }

    // MARK: - Helpers

    private let mine = "{\"side\":\"mine\"}"
    private let theirs = "{\"side\":\"theirs\"}"

    /// A stand-in for the server. libgit2's local transport refuses to push into
    /// a repository that has a working tree, so the seed repo's `.git` is copied
    /// out and flipped to bare.
    private func makeBareRemote() throws -> URL {
        let seed = tempDir.appendingPathComponent("seed")
        try FileManager.default.createDirectory(at: seed, withIntermediateDirectories: true)
        XCTAssertTrue(GitSyncService.initRepository(inDirectory: seed.path, defaultBranch: "main").isSuccess)
        try writeAndCommit("{}", as: "seed.json", in: seed, message: "Initial commit")

        let bare = tempDir.appendingPathComponent("remote.git")
        try FileManager.default.copyItem(at: seed.appendingPathComponent(".git"), to: bare)

        let configURL = bare.appendingPathComponent("config")
        let config = try String(contentsOf: configURL, encoding: .utf8)
            .replacingOccurrences(of: "bare = false", with: "bare = true")
        try config.write(to: configURL, atomically: true, encoding: .utf8)
        return bare
    }

    private func clone(_ remote: URL, as name: String) throws -> URL {
        let destination = tempDir.appendingPathComponent(name)
        let res = GitSyncService.clone(repoUrl: remote.path, destination: destination.path)
        XCTAssertTrue(res.isSuccess, res.error)
        return destination
    }

    /// Stands in for the other machine that pushed before this workspace did.
    @discardableResult
    private func pushFromAnotherClone(
        of remote: URL,
        writing contents: String,
        to file: String
    ) throws -> URL {
        let other = try clone(remote, as: "other_\(UUID().uuidString.prefix(8))")
        try writeAndCommit(contents, as: file, in: other, message: "Change from elsewhere")
        let pushRes = GitSyncService.push(inDirectory: other.path)
        XCTAssertTrue(pushRes.isSuccess, pushRes.error)
        return other
    }

    /// A clone and its remote that both rewrote `file`, i.e. the state a pull
    /// reports as conflicted.
    private func makeDivergedPair(file: String) throws -> (remote: URL, local: URL) {
        let remote = try makeBareRemote()
        // Cloned before the other side pushes, so this branch misses that commit.
        let local = try clone(remote, as: "local")
        try pushFromAnotherClone(of: remote, writing: theirs, to: file)
        try writeAndCommit(mine, as: file, in: local, message: "Local change")
        return (remote, local)
    }

    private func writeAndCommit(_ contents: String, as name: String, in dir: URL, message: String) throws {
        try contents.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        let res = GitSyncService.commitAll(
            message: message,
            inDirectory: dir.path,
            authorName: "Test User",
            authorEmail: "test@example.com"
        )
        XCTAssertTrue(res.isSuccess, res.error)
    }
}
