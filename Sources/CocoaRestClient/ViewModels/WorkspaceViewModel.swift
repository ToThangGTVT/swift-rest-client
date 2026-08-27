//
//  WorkspaceViewModel.swift
//  CocoaRestClientApp
//

import Foundation
import SwiftUI
import CocoaRestClientCore

public final class WorkspaceViewModel: ObservableObject {
    @Published public var tabs: [RequestTabViewModel] = []
    @Published public var selectedTabId: UUID?
    @Published public var showingFastSearch: Bool = false
    @Published public var showingDiffView: Bool = false
    @Published public var showingTimeoutSettings: Bool = false
    @Published public var isSidebarVisible: Bool = true

    public init() {
        let initialTab = RequestTabViewModel()
        self.tabs = [initialTab]
        self.selectedTabId = initialTab.id
    }

    public var selectedTab: RequestTabViewModel? {
        tabs.first(where: { $0.id == selectedTabId }) ?? tabs.first
    }

    public func createNewTab(with request: RestRequest = RestRequest()) {
        let newTab = RequestTabViewModel(request: request)
        tabs.append(newTab)
        selectedTabId = newTab.id
    }

    public func duplicateCurrentTab() {
        guard let current = selectedTab else { return }
        let clonedRequest = current.request.duplicate(withName: "\(current.request.name) (Copy)")
        createNewTab(with: clonedRequest)
    }

    public func closeTab(withId id: UUID) {
        guard tabs.count > 1 else {
            // Keep at least one tab open
            tabs = [RequestTabViewModel()]
            selectedTabId = tabs[0].id
            return
        }
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: idx)
            if selectedTabId == id {
                let nextIndex = min(idx, tabs.count - 1)
                selectedTabId = tabs[nextIndex].id
            }
        }
    }

    public func openSavedRequest(_ request: RestRequest) {
        if let current = selectedTab, current.request.url == "https://httpbin.org/get" && current.response == nil && current.request.name == "New Request" {
            current.request = request
        } else {
            createNewTab(with: request)
        }
    }
}
