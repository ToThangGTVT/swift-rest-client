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
            // SwiftUI runs onAppear inside the update that inserted this view, and
            // `request` is a @Published on the tab view model that the header bar,
            // the response viewer and the tab bar all observe -- writing it here is
            // "Publishing changes from within view updates". parseUrlParameters() is
            // a no-op once the table agrees with the URL, so this settles in one pass.
            DispatchQueue.main.async {
                request.parseUrlParameters()
            }
        }
    }
}
