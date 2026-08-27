//
//  TestAssertion.swift
//  CocoaRestClientCore
//

import Foundation

public enum TestAssertionType: String, Codable, CaseIterable, Sendable {
    case statusCodeEquals = "Status Code Equals"
    case is2xxSuccess = "Status is 2xx Success"
    case responseTimeLessThan = "Response Time Less Than (ms)"
    case bodyContains = "Body Contains String"
    case headerExists = "Header Exists"
    case headerEquals = "Header Value Equals"
    case jsonKeyExists = "JSON Key / Path Exists"
    case jsonKeyEquals = "JSON Key / Path Equals"
}

public struct TestAssertion: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var isEnabled: Bool
    public var type: TestAssertionType
    public var targetKey: String
    public var expectedValue: String

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        type: TestAssertionType = .statusCodeEquals,
        targetKey: String = "",
        expectedValue: String = ""
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.type = type
        self.targetKey = targetKey
        self.expectedValue = expectedValue
    }
}

public struct TestResult: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var assertion: TestAssertion
    public var passed: Bool
    public var message: String

    public init(id: UUID = UUID(), assertion: TestAssertion, passed: Bool, message: String) {
        self.id = id
        self.assertion = assertion
        self.passed = passed
        self.message = message
    }
}

public struct VariableExtractionRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var isEnabled: Bool
    public var source: ExtractionSource
    public var sourceKey: String
    public var targetEnvironmentVariable: String

    public enum ExtractionSource: String, Codable, CaseIterable, Sendable {
        case jsonBody = "JSON Body Key / Path"
        case responseHeader = "Response Header"
        case regexBody = "Regex on Body"
    }

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        source: ExtractionSource = .jsonBody,
        sourceKey: String = "",
        targetEnvironmentVariable: String = ""
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.source = source
        self.sourceKey = sourceKey
        self.targetEnvironmentVariable = targetEnvironmentVariable
    }
}
