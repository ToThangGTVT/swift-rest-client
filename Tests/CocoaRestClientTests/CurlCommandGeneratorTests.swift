//
//  CurlCommandGeneratorTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class CurlCommandGeneratorTests: XCTestCase {
    func testGetCurlCommand() {
        let req = RestRequest(
            url: "https://api.example.com/data",
            method: .get,
            headers: [
                KeyValuePair(key: "Accept", value: "application/json", isEnabled: true),
                KeyValuePair(key: "X-Custom", value: "value", isEnabled: true)
            ]
        )
        let curl = CurlCommandGenerator.generate(from: req, followRedirects: true, environment: [:])
        XCTAssertTrue(curl.hasPrefix("curl -k -L"))
        XCTAssertTrue(curl.contains("-H 'Accept: application/json'"))
        XCTAssertTrue(curl.contains("-H 'X-Custom: value'"))
        XCTAssertTrue(curl.hasSuffix("'https://api.example.com/data'"))
    }

    func testPostJsonWithBasicAuth() {
        let req = RestRequest(
            url: "https://api.example.com/login",
            method: .post,
            headers: [
                KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true)
            ],
            auth: Authentication(type: .basic, username: "admin", password: "secretPassword", isPreemptive: true),
            bodyType: .raw,
            rawBody: "{\"action\":\"login\"}"
        )
        let curl = CurlCommandGenerator.generate(from: req, followRedirects: false, environment: [:])
        XCTAssertTrue(curl.contains("-X POST"))
        XCTAssertTrue(curl.contains("-u 'admin:secretPassword'"))
        XCTAssertTrue(curl.contains("-d '{\"action\":\"login\"}'"))
    }

    func testFormEncodedCurlCommand() {
        let req = RestRequest(
            url: "https://api.example.com/submit",
            method: .post,
            params: [
                KeyValuePair(key: "user", value: "john doe", isEnabled: true),
                KeyValuePair(key: "tag", value: "swift&cocoa", isEnabled: true)
            ],
            bodyType: .formUrlEncoded
        )
        let curl = CurlCommandGenerator.generate(from: req, followRedirects: true, environment: [:])
        XCTAssertTrue(curl.contains("-d 'user=john%20doe&tag=swift%26cocoa'"))
    }
}
