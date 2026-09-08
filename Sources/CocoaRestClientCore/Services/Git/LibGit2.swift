//
//  LibGit2.swift
//  CocoaRestClientCore
//

import Foundation
import Clibgit2

/// Process-wide libgit2 bootstrap and error plumbing.
///
/// The app runs inside the App Sandbox, where spawning `/usr/bin/git` is not an
/// option, so every Git operation goes through the statically linked libgit2.
public enum LibGit2 {
    /// libgit2 keeps global state (allocators, TLS stack, thread locals) that has
    /// to be set up once before any other call. A `static let` gives us exactly
    /// one initialisation, lazily and thread-safely.
    private static let bootstrap: Int32 = git_libgit2_init()

    public static func activate() {
        _ = bootstrap
    }

    /// The message libgit2 recorded for the most recent failure *on this thread*.
    /// Only meaningful immediately after a call returned a negative code.
    public static func lastErrorMessage() -> String {
        guard let err = git_error_last(), let message = err.pointee.message else {
            return "Unknown Git error"
        }
        return String(cString: message)
    }

    public static var version: String {
        var major: Int32 = 0
        var minor: Int32 = 0
        var patch: Int32 = 0
        git_libgit2_version(&major, &minor, &patch)
        return "\(major).\(minor).\(patch)"
    }
}

/// A libgit2 call that failed, carrying the library's own diagnostic.
public struct GitError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }

    public var description: String { message }

    public var isNotFound: Bool { code == GIT_ENOTFOUND.rawValue }
    public var isAuthenticationFailure: Bool {
        code == GIT_EAUTH.rawValue || code == GIT_ECERTIFICATE.rawValue
    }

    /// A push the remote rejected because its branch has commits HEAD lacks.
    ///
    /// libgit2 words this two ways — one for when the remote commit is missing
    /// from the local object database, one for when it is present but is not an
    /// ancestor — and flags both with `GIT_ENONFASTFORWARD`, so the code is what
    /// gets checked. The strings only serve as a fallback for the case where a
    /// wrapping layer keeps the message but loses the code.
    public var isNonFastForward: Bool {
        if code == GIT_ENONFASTFORWARD.rawValue { return true }
        let normalized = message.lowercased().replacingOccurrences(of: "-", with: "")
        return normalized.contains("nonfastforward") || normalized.contains("not present locally")
    }
}

/// Turns a libgit2 return code into a Swift error, capturing the message while
/// it is still the last one recorded on this thread.
@discardableResult
func gitTry(_ operation: String, _ body: () -> Int32) throws -> Int32 {
    let code = body()
    guard code < 0 else { return code }
    throw GitError(code: code, message: "\(operation): \(LibGit2.lastErrorMessage())")
}

/// Bridges `[String]` to the `git_strarray` libgit2 expects for refspec lists.
func withGitStrArray<T>(_ values: [String], _ body: (inout git_strarray) throws -> T) rethrows -> T {
    var cStrings: [UnsafeMutablePointer<CChar>?] = values.map { strdup($0) }
    defer { cStrings.forEach { free($0) } }
    return try cStrings.withUnsafeMutableBufferPointer { buffer in
        var array = git_strarray(strings: buffer.baseAddress, count: values.count)
        return try body(&array)
    }
}
