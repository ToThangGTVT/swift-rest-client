//
//  GraphQLBodyEditorView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct GraphQLBodyEditorView: View {
    @Binding public var query: String
    @Binding public var variables: String
    public var fontSize: CGFloat

    public init(query: Binding<String>, variables: Binding<String>, fontSize: CGFloat = 13.0) {
        self._query = query
        self._variables = variables
        self.fontSize = fontSize
    }

    public var body: some View {
        HSplitView {
            // Left: Query Editor
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Query / Mutation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                SyntaxTextEditorView(text: $query, fontSize: fontSize)
            }
            .frame(minWidth: 200)

            // Right: Variables JSON Editor
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Variables (JSON)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                SyntaxTextEditorView(text: $variables, fontSize: fontSize)
            }
            .frame(minWidth: 160)
        }
    }
}
