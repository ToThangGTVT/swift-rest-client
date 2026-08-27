//
//  EnvironmentViewModel.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public final class EnvironmentViewModel: ObservableObject {
    public static let shared = EnvironmentViewModel()

    @Published public var environments: [EnvironmentProfile] = []
    @Published public var selectedEnvironmentId: UUID? = nil
    @Published public var showingEnvironmentSheet: Bool = false

    private let store = EnvironmentStore.shared

    public init() {
        self.environments = store.loadEnvironments()
        if let first = environments.first {
            self.selectedEnvironmentId = first.id
        }
    }

    public var activeEnvironment: EnvironmentProfile? {
        environments.first(where: { $0.id == selectedEnvironmentId })
    }

    public var activeVariables: [String: String] {
        var merged = ProcessInfo.processInfo.environment
        if let active = activeEnvironment {
            for (k, v) in active.asDictionary() {
                merged[k] = v
            }
        }
        return merged
    }

    public func addEnvironment(name: String = "New Environment") {
        let env = EnvironmentProfile(name: name, variables: [
            KeyValuePair(key: "baseUrl", value: "https://api.example.com", isEnabled: true)
        ])
        environments.append(env)
        selectedEnvironmentId = env.id
        save()
    }

    public func deleteEnvironment(withId id: UUID) {
        environments.removeAll(where: { $0.id == id })
        if selectedEnvironmentId == id {
            selectedEnvironmentId = environments.first?.id
        }
        save()
    }

    public func setVariable(key: String, value: String) {
        guard let id = selectedEnvironmentId, let idx = environments.firstIndex(where: { $0.id == id }) else { return }
        if let varIdx = environments[idx].variables.firstIndex(where: { $0.key == key }) {
            environments[idx].variables[varIdx].value = value
        } else {
            environments[idx].variables.append(KeyValuePair(key: key, value: value, isEnabled: true))
        }
        save()
    }

    public func save() {
        store.saveEnvironments(environments)
    }
}
