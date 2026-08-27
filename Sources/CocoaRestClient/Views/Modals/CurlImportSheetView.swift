//
//  CurlImportSheetView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct CurlImportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var curlText: String = ""
    @State private var errorMessage: String? = nil

    public var onImport: (RestRequest) -> Void

    public init(onImport: @escaping (RestRequest) -> Void) {
        self.onImport = onImport
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "terminal")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Import from cURL")
                    .font(.headline)
                Spacer()
            }

            Text("Paste a cURL command below to automatically populate the request details.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $curlText)
                .font(.system(size: 12, design: .monospaced))
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                .frame(minHeight: 180)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Paste from Clipboard") {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        curlText = str
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Import") {
                    do {
                        let parsedReq = try CurlParser.parse(curlText)
                        onImport(parsedReq)
                        dismiss()
                    } catch {
                        errorMessage = "Invalid cURL command: \(error.localizedDescription)"
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(curlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 520, height: 340)
    }
}
