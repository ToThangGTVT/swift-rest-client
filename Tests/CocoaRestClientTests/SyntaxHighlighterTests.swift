//
//  SyntaxHighlighterTests.swift
//  CocoaRestClientTests
//

import XCTest
#if canImport(AppKit)
import AppKit
@testable import CocoaRestClientCore

final class SyntaxHighlighterTests: XCTestCase {
    func testJsonHighlightingAttributes() {
        let json = """
        {
          "name": "CocoaRestClient",
          "count": 42,
          "active": true
        }
        """
        
        let attrString = SyntaxHighlighter.highlight(text: json, fontSize: 13.0)
        XCTAssertEqual(attrString.string, json)
        XCTAssertGreaterThan(attrString.length, 0)
        
        // Find "name" range
        let nsString = json as NSString
        let nameKeyRange = nsString.range(of: "\"name\"")
        let nameColor = attrString.attribute(.foregroundColor, at: nameKeyRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(nameColor)
        
        // Find "CocoaRestClient" range
        let nameValRange = nsString.range(of: "\"CocoaRestClient\"")
        let valColor = attrString.attribute(.foregroundColor, at: nameValRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(valColor)
        XCTAssertNotEqual(nameColor, valColor) // Keys and values should have different colors
        
        // Find "42" range
        let numRange = nsString.range(of: "42")
        let numColor = attrString.attribute(.foregroundColor, at: numRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(numColor)
        
        // Find "true" range
        let boolRange = nsString.range(of: "true")
        let boolColor = attrString.attribute(.foregroundColor, at: boolRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(boolColor)
    }
}
#endif
