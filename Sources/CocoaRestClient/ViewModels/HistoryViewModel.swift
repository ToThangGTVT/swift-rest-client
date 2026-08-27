//
//  HistoryViewModel.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public final class HistoryViewModel: ObservableObject {
    public static let shared = HistoryViewModel()

    @Published public var historyItems: [HistoryItem] = []
    @Published public var searchText: String = ""

    private let store = HistoryStore.shared

    public init() {
        refresh()
    }

    public func refresh() {
        self.historyItems = store.loadHistory()
    }

    public var filteredItems: [HistoryItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return historyItems
        }
        let query = searchText.lowercased()
        return historyItems.filter { item in
            item.request.name.lowercased().contains(query) ||
            item.request.url.lowercased().contains(query) ||
            item.request.method.rawValue.lowercased().contains(query) ||
            String(item.statusCode).contains(query)
        }
    }

    public func clearAll() {
        store.clearHistory()
        historyItems = []
    }
}
