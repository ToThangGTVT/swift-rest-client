//
//  CodeGeneratorTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class CodeGeneratorTests: XCTestCase {
    func testCodeGenerationSwift() {
        let req = RestRequest(
            name: "Test",
            url: "https://httpbin.org/post",
            method: .post,
            headers: [KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true)],
            bodyType: .raw,
            rawBody: "{\"test\":true}"
        )
        let swiftCode = CodeGenerator.generate(language: .swift, request: req)
        XCTAssertTrue(swiftCode.contains("URLSession.shared.data"))
        XCTAssertTrue(swiftCode.contains("request.httpMethod = \"POST\""))
        XCTAssertTrue(swiftCode.contains("https://httpbin.org/post"))
    }

    func testCodeGenerationPython() {
        let req = RestRequest(
            name: "Test",
            url: "https://httpbin.org/get",
            method: .get
        )
        let pyCode = CodeGenerator.generate(language: .python, request: req)
        XCTAssertTrue(pyCode.contains("import requests"))
        XCTAssertTrue(pyCode.contains("requests.get"))
    }

    func testCodeGenerationJavaScript() {
        let req = RestRequest(
            name: "Test",
            url: "https://httpbin.org/delete",
            method: .delete
        )
        let jsCode = CodeGenerator.generate(language: .javascript, request: req)
        XCTAssertTrue(jsCode.contains("fetch("))
        XCTAssertTrue(jsCode.contains("method: \"DELETE\""))
    }

    func testCodeGenerationGo() {
        let req = RestRequest(
            name: "Test",
            url: "https://httpbin.org/put",
            method: .put
        )
        let goCode = CodeGenerator.generate(language: .go, request: req)
        XCTAssertTrue(goCode.contains("http.NewRequest(\"PUT\""))
        XCTAssertTrue(goCode.contains("http.DefaultClient.Do(req)"))
    }
}
