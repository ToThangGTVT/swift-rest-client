//
//  EnvironmentStore.swift
//  CocoaRestClientCore
//

import Foundation

public final class EnvironmentStore: @unchecked Sendable {
    public static let shared = EnvironmentStore()

    private let fileManager = FileManager.default
    private let lock = NSLock()

    private var environmentsFileUrl: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CocoaRestClient", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("CocoaRestClient.environments.json")
    }

    public init() {}

    public func loadEnvironments() -> [EnvironmentProfile] {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: environmentsFileUrl.path),
              let data = try? Data(contentsOf: environmentsFileUrl) else {
            return defaultEnvironments()
        }

        let decoder = JSONDecoder()
        if let profiles = try? decoder.decode([EnvironmentProfile].self, from: data), !profiles.isEmpty {
            return profiles
        }

        return defaultEnvironments()
    }

    public func saveEnvironments(_ profiles: [EnvironmentProfile]) {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: environmentsFileUrl, options: .atomic)
        }
    }

    private func defaultEnvironments() -> [EnvironmentProfile] {
        return [
            EnvironmentProfile(
                name: "Development",
                variables: [
                    KeyValuePair(key: "baseUrl", value: "https://httpbin.org", isEnabled: true),
                    KeyValuePair(key: "apiKey", value: "dev-key-12345", isEnabled: true)
                ]
            ),
            EnvironmentProfile(
                name: "Production",
                variables: [
                    KeyValuePair(key: "baseUrl", value: "https://api.example.com", isEnabled: true),
                    KeyValuePair(key: "apiKey", value: "prod-secret-9999", isEnabled: true)
                ]
            )
        ]
    }
}
