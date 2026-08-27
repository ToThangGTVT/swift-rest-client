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
}
