//
//  ResponseFormatterTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class ResponseFormatterTests: XCTestCase {
    func testJsonPrettyPrinting() {
        let compactJson = "{\"name\":\"CocoaRestClient\",\"version\":2,\"active\":true}".data(using: .utf8)!
        let formatted = ResponseFormatter.format(data: compactJson, contentType: "application/json; charset=utf-8")
        XCTAssertTrue(formatted.contains("\n"))
        XCTAssertTrue(formatted.contains("\"name\" : \"CocoaRestClient\"") || formatted.contains("\"name\": \"CocoaRestClient\""))
    }

    func testXmlPrettyPrinting() {
        let rawXml = "<root><item id=\"1\"><title>Swift REST</title></item></root>".data(using: .utf8)!
        let formatted = ResponseFormatter.format(data: rawXml, contentType: "application/xml")
        XCTAssertTrue(formatted.contains("\n"))
        XCTAssertTrue(formatted.contains("<title>Swift REST</title>"))
    }

    func testPlainTextFallback() {
        let plain = "Hello, world!".data(using: .utf8)!
        let formatted = ResponseFormatter.format(data: plain, contentType: "text/plain")
        XCTAssertEqual(formatted, "Hello, world!")
    }
}
