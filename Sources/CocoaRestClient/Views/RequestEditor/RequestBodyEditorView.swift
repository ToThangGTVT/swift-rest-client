//
//  RequestBodyEditorView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore
import UniformTypeIdentifiers

public struct RequestBodyEditorView: View {
    @ObservedObject public var tabVM: RequestTabViewModel

    public init(tabVM: RequestTabViewModel) {
        self.tabVM = tabVM
    }

    private let commonContentTypes = [
        "application/json",
        "application/xml",
        "text/plain",
        "text/html",
        "application/javascript",
        "application/x-www-form-urlencoded",
        "multipart/form-data"
    ]

    public var body: some View {
        VStack(spacing: 6) {
            // Body type picker & Actions bar
            HStack(spacing: 12) {
                Picker("", selection: $tabVM.request.bodyType) {
                    ForEach(RequestBodyType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()

                if tabVM.request.bodyType == .raw {
                    HStack(spacing: 6) {
                        Text("Content-Type:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $tabVM.request.rawBodyContentType) {
                            ForEach(commonContentTypes, id: \.self) { ct in
                                Text(ct).tag(ct)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }

                    if tabVM.request.rawBodyContentType.contains("json") {
                        Button(action: { tabVM.formatRawBody() }) {
                            Label("Beautify", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Pretty Print JSON Body (Cmd+Shift+F)")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            Divider()

            // Body Content based on selected type
            switch tabVM.request.bodyType {
            case .raw:
                SyntaxTextEditorView(
                    text: $tabVM.request.rawBody,
                    isEditable: true,
                    fontSize: tabVM.fontSize
                )
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            case .formUrlEncoded:
                KeyValueEditorTable(
                    items: $tabVM.request.params,
                    keyPlaceholder: "Parameter Key",
                    valuePlaceholder: "Parameter Value"
                )
                .padding(.horizontal, 10)

            case .multipart:
                VStack(spacing: 8) {
                    Text("Form Fields")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)

                    KeyValueEditorTable(
                        items: $tabVM.request.params,
                        keyPlaceholder: "Field Name",
                        valuePlaceholder: "Field Value"
                    )
                    .frame(maxHeight: 180)
                    .padding(.horizontal, 10)

                    Divider()

                    Text("Attached Files")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)

                    FilesTableView(files: $tabVM.request.files)
                        .padding(.horizontal, 10)
                }

            case .binaryFile:
                VStack(spacing: 12) {
                    if !tabVM.request.binaryFilePath.isEmpty {
                        HStack {
                            Image(systemName: "doc.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text(URL(fileURLWithPath: tabVM.request.binaryFilePath).lastPathComponent)
                                    .fontWeight(.medium)
                                Text(tabVM.request.binaryFilePath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                tabVM.request.binaryFilePath = ""
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No binary file selected")
                                .foregroundColor(.secondary)
                            Button("Choose File...") {
                                chooseBinaryFile()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    }
                }
                .padding()

            case .graphql:
                GraphQLBodyEditorView(
                    query: $tabVM.request.graphqlQuery,
                    variables: $tabVM.request.graphqlVariables,
                    fontSize: tabVM.fontSize
                )
                .padding(.horizontal, 10)
            }
        }
    }

    private func chooseBinaryFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            tabVM.request.binaryFilePath = url.path
        }
    }
}
