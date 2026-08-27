//
//  DiffEngineTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class DiffEngineTests: XCTestCase {
    func testIdenticalTexts() {
        let text = "Line 1\nLine 2\nLine 3"
        let diff = DiffEngine.diff(left: text, right: text)
        XCTAssertEqual(diff.count, 3)
        XCTAssertTrue(diff.allSatisfy { $0.type == .unchanged })
    }

    func testInsertedAndDeletedLines() {
        let left = "Alpha\nBeta\nGamma"
        let right = "Alpha\nBeta Modified\nGamma\nDelta"
        let diff = DiffEngine.diff(left: left, right: right)
        
        XCTAssertTrue(diff.contains(where: { $0.type == .deleted && $0.text == "Beta" }))
        XCTAssertTrue(diff.contains(where: { $0.type == .inserted && $0.text == "Beta Modified" }))
        XCTAssertTrue(diff.contains(where: { $0.type == .inserted && $0.text == "Delta" }))
    }
}
