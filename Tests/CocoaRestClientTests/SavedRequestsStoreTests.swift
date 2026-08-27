//
//  SavedRequestsStoreTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class SavedRequestsStoreTests: XCTestCase {
    func testTreeItemAndFolderOperations() {
        var root = RequestFolder(name: "Root")
        var subFolder = RequestFolder(name: "Sub")
        let req1 = RestRequest(name: "Req 1", url: "https://api.test/1", method: .get)
        let req2 = RestRequest(name: "Req 2", url: "https://api.test/2", method: .post)
        
        subFolder.append(.request(req1))
        root.append(.folder(subFolder))
        root.append(.request(req2))
        
        XCTAssertEqual(root.totalRequestCount, 2)
        
        let all = root.allRequests()
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(where: { $0.request.name == "Req 1" && $0.path == "/Sub/" }))
        XCTAssertTrue(all.contains(where: { $0.request.name == "Req 2" && $0.path == "/" }))
        
        // Remove item
        let removed = root.removeItem(withId: req1.id)
        XCTAssertTrue(removed)
        XCTAssertEqual(root.totalRequestCount, 1)
    }

    func testExportAndImportFolder() throws {
        var folder = RequestFolder(name: "Export Test")
        folder.append(.request(RestRequest(name: "Exported Req", url: "https://example.com", method: .get)))
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("test_export_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileUrl) }
        
        try SavedRequestsStore.shared.exportFolder(folder, to: fileUrl)
        let imported = try SavedRequestsStore.shared.importFolder(from: fileUrl)
        
        XCTAssertEqual(imported.name, "Export Test")
        XCTAssertEqual(imported.totalRequestCount, 1)
        XCTAssertEqual(imported.items.first?.requestValue?.name, "Exported Req")
    }
}
