//
//  RestRequestTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class RestRequestTests: XCTestCase {
    func testRequestInitializationAndDuplication() {
        let request = RestRequest(
            name: "Test Request",
            url: "https://api.example.com/users",
            method: .get
        )
        
        XCTAssertEqual(request.name, "Test Request")
        XCTAssertEqual(request.url, "https://api.example.com/users")
        XCTAssertEqual(request.method, .get)
        
        let duplicate = request.duplicate(withName: "Cloned Request")
        XCTAssertNotEqual(request.id, duplicate.id)
        XCTAssertEqual(duplicate.name, "Cloned Request")
        XCTAssertEqual(duplicate.url, request.url)
    }

    func testUrlParametersParsingAndRebuilding() {
        var request = RestRequest(url: "https://api.example.com/search?q=swift&page=2&limit=50")
        request.parseUrlParameters()
        
        XCTAssertEqual(request.urlParams.count, 3)
        XCTAssertEqual(request.urlParams[0].key, "q")
        XCTAssertEqual(request.urlParams[0].value, "swift")
        XCTAssertEqual(request.urlParams[1].key, "page")
        XCTAssertEqual(request.urlParams[1].value, "2")
        
        // Modify param in table and rebuild URL
        request.urlParams[1].value = "3"
        request.urlParams.append(KeyValuePair(key: "sort", value: "desc", isEnabled: true))
        request.rebuildUrlFromUrlParameters()
        
        XCTAssertTrue(request.url.contains("page=3"))
        XCTAssertTrue(request.url.contains("sort=desc"))
    }
}
