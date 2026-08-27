//
//  HistoryStoreTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class HistoryStoreTests: XCTestCase {
    func testHistoryItemFormatting() {
        let item = HistoryItem(
            statusCode: 200,
            latencyMs: 125.4,
            responseSize: 2048,
            request: RestRequest(name: "History Req", url: "https://api.test/data")
        )
        
        XCTAssertEqual(item.statusCode, 200)
        XCTAssertEqual(item.formattedSize, "2.0 KB")
        XCTAssertFalse(item.formattedTime.isEmpty)
    }

    func testHistoryStoreAddAndLoad() {
        let store = HistoryStore.shared
        store.clearHistory()
        
        XCTAssertEqual(store.loadHistory().count, 0)
        
        store.addEntry(
            request: RestRequest(name: "Req 1", url: "https://api.test/1"),
            statusCode: 200,
            latencyMs: 50.0,
            responseSize: 500
        )
        
        let loaded = store.loadHistory()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.request.name, "Req 1")
        XCTAssertEqual(loaded.first?.statusCode, 200)
    }
}
