//
//  DiffEngine.swift
//  CocoaRestClientCore
//

import Foundation

public enum DiffLineType: Sendable {
    case unchanged
    case inserted
    case deleted
}

public struct DiffLine: Identifiable, Sendable {
    public var id: UUID
    public var type: DiffLineType
    public var leftLineNumber: Int?
    public var rightLineNumber: Int?
    public var text: String

    public init(
        id: UUID = UUID(),
        type: DiffLineType,
        leftLineNumber: Int?,
        rightLineNumber: Int?,
        text: String
    ) {
        self.id = id
        self.type = type
        self.leftLineNumber = leftLineNumber
        self.rightLineNumber = rightLineNumber
        self.text = text
    }
}

public struct DiffEngine: Sendable {
    public init() {}

    public static func diff(left: String, right: String) -> [DiffLine] {
        let leftLines = left.components(separatedBy: .newlines)
        let rightLines = right.components(separatedBy: .newlines)
        
        let lcs = longestCommonSubsequence(leftLines, rightLines)
        
        var results: [DiffLine] = []
        var i = 0
        var j = 0
        var leftLineNum = 1
        var rightLineNum = 1

        for match in lcs {
            // Deleted lines from left
            while i < match.0 {
                results.append(DiffLine(
                    type: .deleted,
                    leftLineNumber: leftLineNum,
                    rightLineNumber: nil,
                    text: leftLines[i]
                ))
                i += 1
                leftLineNum += 1
            }
            
            // Inserted lines in right
            while j < match.1 {
                results.append(DiffLine(
                    type: .inserted,
                    leftLineNumber: nil,
                    rightLineNumber: rightLineNum,
                    text: rightLines[j]
                ))
                j += 1
                rightLineNum += 1
            }
            
            // Unchanged line
            results.append(DiffLine(
                type: .unchanged,
                leftLineNumber: leftLineNum,
                rightLineNumber: rightLineNum,
                text: leftLines[i]
            ))
            i += 1
            j += 1
            leftLineNum += 1
            rightLineNum += 1
        }
        
        // Remaining deleted lines
        while i < leftLines.count {
            results.append(DiffLine(
                type: .deleted,
                leftLineNumber: leftLineNum,
                rightLineNumber: nil,
                text: leftLines[i]
            ))
            i += 1
            leftLineNum += 1
        }
        
        // Remaining inserted lines
        while j < rightLines.count {
            results.append(DiffLine(
                type: .inserted,
                leftLineNumber: nil,
                rightLineNumber: rightLineNum,
                text: rightLines[j]
            ))
            j += 1
            rightLineNum += 1
        }
        
        return results
    }

    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        let m = a.count
        let n = b.count
        guard m > 0 && n > 0 else { return [] }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0..<m {
            for j in 0..<n {
                if a[i] == b[j] {
                    dp[i + 1][j + 1] = dp[i][j] + 1
                } else {
                    dp[i + 1][j + 1] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var matches: [(Int, Int)] = []
        var i = m
        var j = n

        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                matches.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return matches.reversed()
    }
}
