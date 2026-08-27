//
//  CookieJarTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class CookieJarTests: XCTestCase {
    func testCookieStorageAndMatching() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_cookies_\(UUID().uuidString).json")
        let store = CookieJarStore(fileURL: tempFile)

        let cookie1 = CookieItem(
            name: "session_id",
            value: "abc123xyz",
            domain: "example.com",
            path: "/"
        )
        let cookie2 = CookieItem(
            name: "auth_token",
            value: "secret",
            domain: "api.example.com",
            path: "/v1"
        )
        store.setCookie(cookie1)
        store.setCookie(cookie2)

        // Matching url for example.com
        let url1 = URL(string: "https://example.com/dashboard")!
        let matching1 = store.cookies(for: url1)
        XCTAssertEqual(matching1.count, 1)
        XCTAssertEqual(matching1[0].name, "session_id")

        // Matching url for api.example.com/v1/users
        let url2 = URL(string: "https://api.example.com/v1/users")!
        let matching2 = store.cookies(for: url2)
        XCTAssertEqual(matching2.count, 2) // Inherits parent domain + subdomain

        let headerVal = store.cookieHeaderValue(for: url2)
        XCTAssertNotNil(headerVal)
        XCTAssertTrue(headerVal?.contains("session_id=abc123xyz") == true)
        XCTAssertTrue(headerVal?.contains("auth_token=secret") == true)

        // Test Set-Cookie parsing
        store.parseAndStoreSetCookie(headerValue: "user_pref=dark_mode; Domain=example.com; Path=/; Secure; HttpOnly", defaultDomain: "example.com")
        let matching3 = store.cookies(for: url1)
        XCTAssertEqual(matching3.count, 2)
        let prefCookie = matching3.first(where: { $0.name == "user_pref" })
        XCTAssertNotNil(prefCookie)
        XCTAssertEqual(prefCookie?.value, "dark_mode")
        XCTAssertTrue(prefCookie?.isSecure == true)
        XCTAssertTrue(prefCookie?.isHttpOnly == true)
    }
}
