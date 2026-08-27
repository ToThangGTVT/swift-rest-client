//
//  PostmanImporterTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class PostmanImporterTests: XCTestCase {
    func testImportPostmanCollectionV21() throws {
        let postmanJson = """
        {
          "info": {
            "name": "My API Collection",
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
          },
          "item": [
            {
              "name": "Auth Folder",
              "item": [
                {
                  "name": "Login Request",
                  "request": {
                    "method": "POST",
                    "header": [
                      { "key": "Content-Type", "value": "application/json" }
                    ],
                    "body": {
                      "mode": "raw",
                      "raw": "{\\"username\\":\\"admin\\"}"
                    },
                    "url": {
                      "raw": "https://api.example.com/v1/login",
                      "query": [
                        { "key": "redirect", "value": "true" }
                      ]
                    },
                    "auth": {
                      "type": "bearer",
                      "bearer": [
                        { "key": "token", "value": "secret-token-123" }
                      ]
                    }
                  }
                }
              ]
            },
            {
              "name": "Get Users",
              "request": {
                "method": "GET",
                "url": "https://api.example.com/v1/users"
              }
            }
          ]
        }
        """

        let data = postmanJson.data(using: .utf8)!
        let folder = try PostmanImporter.importCollection(from: data)

        XCTAssertEqual(folder.name, "My API Collection")
        XCTAssertEqual(folder.items.count, 2)

        // Check subfolder
        guard case .folder(let subFolder) = folder.items[0] else {
            XCTFail("Expected first item to be a folder")
            return
        }
        XCTAssertEqual(subFolder.name, "Auth Folder")
        XCTAssertEqual(subFolder.items.count, 1)

        // Check login request
        guard case .request(let loginReq) = subFolder.items[0] else {
            XCTFail("Expected first sub-item to be a request")
            return
        }
        XCTAssertEqual(loginReq.name, "Login Request")
        XCTAssertEqual(loginReq.method, .post)
        XCTAssertEqual(loginReq.url, "https://api.example.com/v1/login")
        XCTAssertEqual(loginReq.auth.type, .bearer)
        XCTAssertEqual(loginReq.auth.token, "secret-token-123")
        XCTAssertEqual(loginReq.rawBody, "{\"username\":\"admin\"}")
        XCTAssertEqual(loginReq.urlParams.count, 1)
        XCTAssertEqual(loginReq.urlParams[0].key, "redirect")

        // Check second root item
        guard case .request(let usersReq) = folder.items[1] else {
            XCTFail("Expected second item to be a request")
            return
        }
        XCTAssertEqual(usersReq.name, "Get Users")
        XCTAssertEqual(usersReq.method, .get)
        XCTAssertEqual(usersReq.url, "https://api.example.com/v1/users")
    }
}
