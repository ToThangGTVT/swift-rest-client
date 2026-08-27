//
//  CookieJarStore.swift
//  CocoaRestClientCore
//

import Foundation

public final class CookieJarStore: @unchecked Sendable {
    public static let shared = CookieJarStore()
    private let lock = NSLock()
    private var cookies: [CookieItem] = []
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("CocoaRestClient", isDirectory: true)
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.fileURL = appDir.appendingPathComponent("cookies.json")
        }
        loadCookies()
    }

    public func getAllCookies() -> [CookieItem] {
        lock.lock()
        defer { lock.unlock() }
        return cookies
    }

    public func setCookie(_ cookie: CookieItem) {
        lock.lock()
        defer { lock.unlock() }
        if let idx = cookies.firstIndex(where: { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }) {
            cookies[idx] = cookie
        } else {
            cookies.append(cookie)
        }
        saveCookies()
    }

    public func removeCookie(withId id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        cookies.removeAll { $0.id == id }
        saveCookies()
    }

    public func removeCookies(forDomain domain: String) {
        lock.lock()
        defer { lock.unlock() }
        cookies.removeAll { $0.domain == domain || $0.domain.hasSuffix(domain) }
        saveCookies()
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cookies.removeAll()
        saveCookies()
    }

    public func cookies(for url: URL) -> [CookieItem] {
        lock.lock()
        defer { lock.unlock() }
        guard let host = url.host?.lowercased() else { return [] }
        let path = url.path.isEmpty ? "/" : url.path
        let isHttps = url.scheme?.lowercased() == "https"

        return cookies.filter { cookie in
            if cookie.isExpired { return false }
            if cookie.isSecure && !isHttps { return false }

            let cookieDomain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let matchesDomain = host == cookieDomain || host.hasSuffix("." + cookieDomain)
            guard matchesDomain else { return false }

            let matchesPath = path.hasPrefix(cookie.path)
            return matchesPath
        }
    }

    public func cookieHeaderValue(for url: URL) -> String? {
        let matching = cookies(for: url)
        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    public func storeCookies(from responseHeaders: [String: String], for url: URL) {
        guard let host = url.host?.lowercased() else { return }
        for (key, value) in responseHeaders {
            if key.caseInsensitiveCompare("Set-Cookie") == .orderedSame {
                parseAndStoreSetCookie(headerValue: value, defaultDomain: host, defaultPath: "/")
            }
        }
    }

    public func parseAndStoreSetCookie(headerValue: String, defaultDomain: String, defaultPath: String = "/") {
        let parts = headerValue.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstPart = parts.first, let equalsIdx = firstPart.firstIndex(of: "=") else { return }

        let name = String(firstPart[..<equalsIdx]).trimmingCharacters(in: .whitespaces)
        let value = String(firstPart[firstPart.index(after: equalsIdx)...]).trimmingCharacters(in: .whitespaces)

        var domain = defaultDomain
        var path = defaultPath
        var isSecure = false
        var isHttpOnly = false
        var expires: Date?

        for part in parts.dropFirst() {
            let lower = part.lowercased()
            if lower.hasPrefix("domain=") {
                let d = String(part.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                if !d.isEmpty { domain = d }
            } else if lower.hasPrefix("path=") {
                let p = String(part.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !p.isEmpty { path = p }
            } else if lower == "secure" {
                isSecure = true
            } else if lower == "httponly" {
                isHttpOnly = true
            } else if lower.hasPrefix("max-age=") {
                if let seconds = Double(part.dropFirst(8)) {
                    expires = Date().addingTimeInterval(seconds)
                }
            }
        }

        let cookie = CookieItem(
            name: name,
            value: value,
            domain: domain,
            path: path,
            expires: expires,
            isSecure: isSecure,
            isHttpOnly: isHttpOnly
        )
        setCookie(cookie)
    }

    private func saveCookies() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(cookies) {
            try? data.write(to: fileURL)
        }
    }

    private func loadCookies() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let loaded = try? decoder.decode([CookieItem].self, from: data) {
            self.cookies = loaded
        }
    }
}
