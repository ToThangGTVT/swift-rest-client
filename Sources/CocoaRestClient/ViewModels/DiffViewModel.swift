//
//  DiffViewModel.swift
//  CocoaRestClientApp
//

import Foundation
import SwiftUI
import CocoaRestClientCore

public final class DiffViewModel: ObservableObject {
    @Published public var leftTabId: UUID?
    @Published public var rightTabId: UUID?
    @Published public var diffLines: [DiffLine] = []

    public init() {}

    public func computeDiff(tabs: [RequestTabViewModel]) {
        guard let leftId = leftTabId, let leftTab = tabs.first(where: { $0.id == leftId }),
              let rightId = rightTabId, let rightTab = tabs.first(where: { $0.id == rightId }) else {
            diffLines = []
            return
        }

        let leftText = leftTab.response?.formattedBody ?? ""
        let rightText = rightTab.response?.formattedBody ?? ""
        self.diffLines = DiffEngine.diff(left: leftText, right: rightText)
    }
}
