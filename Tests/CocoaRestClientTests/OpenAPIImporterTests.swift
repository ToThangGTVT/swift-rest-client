//
//  OpenAPIImporterTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class OpenAPIImporterTests: XCTestCase {
    func testImportOpenAPI30Specification() throws {
        let openApiJson = """
        {
          "openapi": "3.0.0",
          "info": {
            "title": "Pet Store API",
            "version": "1.0.0"
          },
          "servers": [
            { "url": "https://petstore.swagger.io/v2" }
          ],
          "paths": {
            "/pets": {
              "get": {
                "summary": "List all pets",
                "tags": ["Pets"],
                "parameters": [
                  { "name": "limit", "in": "query", "required": true, "example": "20" }
                ]
              },
              "post": {
                "summary": "Create a pet",
                "tags": ["Pets"],
                "requestBody": {
                  "content": {
                    "application/json": {
                      "example": { "name": "Doggo", "type": "Dog" }
                    }
                  }
                }
              }
            },
            "/ping": {
              "get": {
                "summary": "Health check",
                "operationId": "healthCheck"
              }
            }
          }
        }
        """

        let data = openApiJson.data(using: .utf8)!
        let folder = try OpenAPIImporter.importSpecification(from: data)

        XCTAssertEqual(folder.name, "Pet Store API")
        XCTAssertGreaterThanOrEqual(folder.items.count, 2)

        // Find tagged folder "Pets"
        let petsFolderItem = folder.items.first { $0.name == "Pets" }
        XCTAssertNotNil(petsFolderItem)

        if case .folder(let petsFolder) = petsFolderItem {
            XCTAssertEqual(petsFolder.items.count, 2)

            let getPet = petsFolder.items.first(where: { $0.requestValue?.method == .get })?.requestValue
            XCTAssertNotNil(getPet)
            XCTAssertEqual(getPet?.url, "https://petstore.swagger.io/v2/pets")
            XCTAssertEqual(getPet?.urlParams.count, 1)
            XCTAssertEqual(getPet?.urlParams[0].key, "limit")

            let postPet = petsFolder.items.first(where: { $0.requestValue?.method == .post })?.requestValue
            XCTAssertNotNil(postPet)
            XCTAssertTrue(postPet?.rawBody.contains("Doggo") == true)
        }
    }
}
