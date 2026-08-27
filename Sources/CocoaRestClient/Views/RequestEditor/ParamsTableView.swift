//
//  ParamsTableView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct ParamsTableView: View {
    @Binding public var request: RestRequest

    public init(request: Binding<RestRequest>) {
        self._request = request
    }

    public var body: some View {
        VStack(spacing: 8) {
            KeyValueEditorTable(
                items: Binding(
                    get: { request.urlParams },
                    set: { newParams in
                        request.urlParams = newParams
                        request.rebuildUrlFromUrlParameters()
                    }
                ),
                keyPlaceholder: "Query Parameter Key",
                valuePlaceholder: "Query Parameter Value"
            )
        }
        .onAppear {
            request.parseUrlParameters()
        }
    }
}
