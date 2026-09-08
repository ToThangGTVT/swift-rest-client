//
//  GitCredentialStore.swift
//  CocoaRestClientCore
//

import Foundation
import Security

/// Username plus secret used to authenticate against an HTTPS remote.
/// For GitHub/GitLab/Bitbucket the secret is a personal access token.
public struct GitCredentials: Sendable, Equatable {
    public let username: String
    public let secret: String

    public init(username: String, secret: String) {
        self.username = username
        self.secret = secret
    }

    public var isEmpty: Bool {
        username.isEmpty && secret.isEmpty
    }
}

/// Keychain-backed storage for Git remote credentials.
///
/// The sandboxed app has its own keychain partition, so nothing here is shared
/// with `git-credential-osxkeychain` — credentials the user entered in the
/// terminal are not visible to us and vice versa.
public enum GitCredentialStore {
    private static let service = "com.utc.rest.client.git"

    /// Credentials are keyed by host rather than by full URL, so the same token
    /// serves every repository on e.g. github.com.
    public static func account(forRemoteUrl url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let host = URL(string: trimmed)?.host, !host.isEmpty {
            return host.lowercased()
        }
        // scp-style remote: git@github.com:owner/repo.git
        if let atIndex = trimmed.firstIndex(of: "@") {
            let afterAt = trimmed[trimmed.index(after: atIndex)...]
            if let colonIndex = afterAt.firstIndex(of: ":") {
                return String(afterAt[..<colonIndex]).lowercased()
            }
        }
        return nil
    }

    public static func load(forRemoteUrl url: String) -> GitCredentials? {
        guard let account = account(forRemoteUrl: url) else { return nil }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        // A URL embedding its own user (https://me@host/…) still resolves to the
        // host entry; the username is whatever was stored alongside the secret.
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let result = item as? [String: Any],
              let data = result[kSecValueData as String] as? Data,
              let secret = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        let username = result[kSecAttrLabel as String] as? String ?? ""
        return GitCredentials(username: username, secret: secret)
    }

    @discardableResult
    public static func save(_ credentials: GitCredentials, forRemoteUrl url: String) -> Bool {
        guard let account = account(forRemoteUrl: url) else { return false }
        guard let secretData = credentials.secret.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: secretData,
            // The keychain item is keyed by host, so the username rides along as
            // the label rather than as part of the key.
            kSecAttrLabel as String: credentials.username
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = query
        addQuery.merge(attributes) { current, _ in current }
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    public static func delete(forRemoteUrl url: String) -> Bool {
        guard let account = account(forRemoteUrl: url) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    public static func hasCredentials(forRemoteUrl url: String) -> Bool {
        guard let credentials = load(forRemoteUrl: url) else { return false }
        return !credentials.secret.isEmpty
    }
}
