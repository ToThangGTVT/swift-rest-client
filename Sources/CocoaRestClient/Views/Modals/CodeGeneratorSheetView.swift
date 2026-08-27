//
//  CodeGeneratorSheetView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct CodeGeneratorSheetView: View {
    @Environment(\.dismiss) private var dismiss
    public let request: RestRequest

    @State private var selectedLanguage: CodeLanguage = .swift
    @State private var copied: Bool = false

    public init(request: RestRequest) {
        self.request = request
    }

    private var generatedCode: String {
        let env = EnvironmentViewModel.shared.activeVariables
        return CodeGenerator.generate(language: selectedLanguage, request: request, environment: env)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "curlybraces")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Generate Code Snippet")
                    .font(.headline)

                Spacer()

                Picker("Language", selection: $selectedLanguage) {
                    ForEach(CodeLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }

            Divider()

            ScrollView {
                Text(generatedCode)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))

            HStack {
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(generatedCode, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    Label(copied ? "Copied!" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 600, height: 440)
    }
}
