//
//  RequestHeaderBar.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct RequestHeaderBar: View {
    @ObservedObject public var tabVM: RequestTabViewModel
    @ObservedObject private var envVM = EnvironmentViewModel.shared
    public var onSave: () -> Void
    public var onOpenCodeGenerator: () -> Void

    public init(
        tabVM: RequestTabViewModel,
        onSave: @escaping () -> Void,
        onOpenCodeGenerator: @escaping () -> Void = {}
    ) {
        self.tabVM = tabVM
        self.onSave = onSave
        self.onOpenCodeGenerator = onOpenCodeGenerator
    }

    private var methodColor: Color {
        switch tabVM.request.method {
        case .get: return .green
        case .post: return .blue
        case .put: return .orange
        case .delete: return .red
        case .patch: return .purple
        case .head: return .teal
        default: return .gray
        }
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Method Picker
            Picker("", selection: $tabVM.request.method) {
                ForEach(HTTPMethod.allPredefined, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .frame(width: 105)
            .labelsHidden()
            .accentColor(methodColor)

            // URL Box
            HStack {
                ZStack(alignment: .leading) {
                    if tabVM.request.url.isEmpty {
                        Text("https://api.example.com/resource")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(NSColor.placeholderTextColor))
                            .allowsHitTesting(false)
                    }

                    VariableChipTextField(
                        text: $tabVM.request.url,
                        environment: envVM.activeVariables,
                        onSubmit: { tabVM.sendRequest() }
                    )
                    .frame(height: 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: tabVM.request.url) { newUrl in
                    // Auto-detect pasted cURL command in URL bar
                    let trimmed = newUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.lowercased().hasPrefix("curl "),
                          let parsed = try? CurlParser.parse(trimmed) else { return }
                    // onChange runs inside the update that observed the edit, so
                    // replacing the whole request here would publish mid-update.
                    DispatchQueue.main.async {
                        tabVM.request = parsed
                    }
                }

                if !tabVM.request.url.isEmpty {
                    Button(action: { tabVM.request.url = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )

            // Send / Cancel Button
            Button(action: { tabVM.sendRequest() }) {
                HStack(spacing: 6) {
                    if tabVM.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(tabVM.isLoading ? "Sending..." : "Send")
                        .fontWeight(.semibold)
                }
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(tabVM.isLoading || tabVM.request.url.isEmpty)

            // Code Snippets Button
            Button(action: onOpenCodeGenerator) {
                Image(systemName: "curlybraces")
            }
            .buttonStyle(.bordered)
            .help("Generate Code Snippets (Cmd+Shift+G)")

            // Copy cURL Button
            Button(action: { tabVM.copyCurlCommand() }) {
                Image(systemName: "terminal")
            }
            .buttonStyle(.bordered)
            .help("Copy as cURL command (Cmd+Shift+C)")

            // Save Request Button
            Button(action: onSave) {
                Image(systemName: "bookmark")
            }
            .buttonStyle(.bordered)
            .help("Save Request to Sidebar (Cmd+S)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
