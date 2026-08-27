//
//  EnvironmentVariableResolverTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class EnvironmentVariableResolverTests: XCTestCase {
    func testSingleSubstitution() {
        let env = ["USER": "alice", "PORT": "8080"]
        let template = "User has ${USER} username"
        let result = EnvironmentVariableResolver.resolve(template, environment: env)
        XCTAssertEqual(result, "User has alice username")
    }

    func testMultipleSubstitutions() {
        let env = ["HOST": "localhost", "PORT": "3000", "PATH": "api/v1"]
        let template = "http://${HOST}:${PORT}/${PATH}/items"
        let result = EnvironmentVariableResolver.resolve(template, environment: env)
        XCTAssertEqual(result, "http://localhost:3000/api/v1/items")
    }

    func testMissingVariableKeepsTemplate() {
        let env = ["KNOWN": "value"]
        let template = "Hello ${UNKNOWN}"
        let result = EnvironmentVariableResolver.resolve(template, environment: env)
        XCTAssertEqual(result, "Hello ${UNKNOWN}")
    }
}
