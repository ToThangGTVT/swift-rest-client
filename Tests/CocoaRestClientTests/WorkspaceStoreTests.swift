//
//  WorkspaceStoreTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class WorkspaceStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("WorkspaceStoreTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testWorkspaceModelCreationAndPersistence() {
        let store = WorkspaceStore()
        let ws = WorkspaceModel(
            name: "Test Workspace",
            description: "Test description",
            directoryPath: tempDir.path,
            gitRemoteUrl: "https://github.com/org/repo.git",
            gitBranch: "develop"
        )

        store.saveWorkspaceManifest(ws)

        let manifestFile = tempDir.appendingPathComponent("workspace.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestFile.path))

        let data = try? Data(contentsOf: manifestFile)
        XCTAssertNotNil(data)

        let decoded = try? JSONDecoder().decode(WorkspaceModel.self, from: data!)
        XCTAssertEqual(decoded?.name, "Test Workspace")
        XCTAssertEqual(decoded?.gitBranch, "develop")
    }

    func testCollectionsAndEnvironmentsPersistenceInWorkspace() {
        let store = WorkspaceStore()
        let ws = WorkspaceModel(
            name: "Alpha Workspace",
            directoryPath: tempDir.path
        )

        var folder = RequestFolder(name: "My API Collection")
        let req = RestRequest(name: "Ping Request", url: "https://api.example.com/ping", method: .get)
        folder.append(.request(req))

        store.saveCollections(folder, for: ws)

        let loadedFolder = store.loadCollections(for: ws)
        XCTAssertEqual(loadedFolder.name, "My API Collection")
        XCTAssertEqual(loadedFolder.items.count, 1)

        let envs = [
            EnvironmentProfile(name: "Staging", variables: [
                KeyValuePair(key: "API_HOST", value: "https://staging.example.com", isEnabled: true)
            ])
        ]
        store.saveEnvironments(envs, for: ws)

        let loadedEnvs = store.loadEnvironments(for: ws)
        XCTAssertEqual(loadedEnvs.count, 1)
        XCTAssertEqual(loadedEnvs.first?.name, "Staging")
        XCTAssertEqual(loadedEnvs.first?.variables.first?.value, "https://staging.example.com")
    }
}
