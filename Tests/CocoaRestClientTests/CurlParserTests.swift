//
//  CurlParserTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class CurlParserTests: XCTestCase {
    func testSimpleGetCurl() throws {
        let curl = "curl https://httpbin.org/get"
        let req = try CurlParser.parse(curl)
        
        XCTAssertEqual(req.url, "https://httpbin.org/get")
        XCTAssertEqual(req.method, .get)
    }

    func testPostJsonWithHeadersAndAuth() throws {
        let curl = """
        curl -X POST 'https://api.example.com/items' \\
          -H 'Content-Type: application/json' \\
          -H 'Authorization: Bearer secret-token-xyz' \\
          -d '{"name":"Widget","price":9.99}'
        """
        let req = try CurlParser.parse(curl)
        
        XCTAssertEqual(req.url, "https://api.example.com/items")
        XCTAssertEqual(req.method, .post)
        XCTAssertEqual(req.bodyType, .raw)
        XCTAssertEqual(req.rawBody, "{\"name\":\"Widget\",\"price\":9.99}")
        XCTAssertEqual(req.auth.type, .bearer)
        XCTAssertEqual(req.auth.token, "secret-token-xyz")
    }

    func testBasicAuthCurl() throws {
        let curl = "curl -u admin:secret123 https://api.test/admin"
        let req = try CurlParser.parse(curl)
        
        XCTAssertEqual(req.auth.type, .basic)
        XCTAssertEqual(req.auth.username, "admin")
        XCTAssertEqual(req.auth.password, "secret123")
    }

    func testGraphQLDetectionInCurl() throws {
        let curl = """
        curl -X POST https://api.spacex.land/graphql \\
          -H "Content-Type: application/json" \\
          -d '{"query":"query { launches { mission_name } }","variables":{"limit":10}}'
        """
        let req = try CurlParser.parse(curl)
        
        XCTAssertEqual(req.bodyType, .graphql)
        XCTAssertEqual(req.graphqlQuery, "query { launches { mission_name } }")
        XCTAssertTrue(req.graphqlVariables.contains("\"limit\""))
    }
}
