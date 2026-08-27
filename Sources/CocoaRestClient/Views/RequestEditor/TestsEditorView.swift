//
//  TestsEditorView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct TestsEditorView: View {
    @Binding public var assertions: [TestAssertion]
    @Binding public var extractionRules: [VariableExtractionRule]

    @State private var selectedSection: Int = 0

    public init(
        assertions: Binding<[TestAssertion]>,
        extractionRules: Binding<[VariableExtractionRule]>
    ) {
        self._assertions = assertions
        self._extractionRules = extractionRules
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Header Bar
            HStack {
                Picker("", selection: $selectedSection) {
                    Text("Test Assertions (\(assertions.count))").tag(0)
                    Text("Variable Extraction (\(extractionRules.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 340)

                Spacer()

                if selectedSection == 0 {
                    Button(action: {
                        assertions.append(TestAssertion(type: .statusCodeEquals, expectedValue: "200"))
                    }) {
                        Label("Add Assertion", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button(action: {
                        extractionRules.append(VariableExtractionRule(source: .jsonBody, sourceKey: "token", targetEnvironmentVariable: "AUTH_TOKEN"))
                    }) {
                        Label("Add Extraction Rule", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            Divider()

            // Content
            if selectedSection == 0 {
                assertionsList
            } else {
                extractionsList
            }
        }
    }

    private var assertionsList: some View {
        Group {
            if assertions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No automated test assertions configured")
                        .foregroundColor(.secondary)
                    Button("Add Status 200 Assertion") {
                        assertions.append(TestAssertion(type: .statusCodeEquals, expectedValue: "200"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($assertions) { $assertion in
                        HStack(spacing: 8) {
                            Toggle("", isOn: $assertion.isEnabled)
                                .labelsHidden()

                            Picker("", selection: $assertion.type) {
                                ForEach(TestAssertionType.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 200)

                            if assertion.type == .headerExists || assertion.type == .headerEquals || assertion.type == .jsonKeyExists || assertion.type == .jsonKeyEquals {
                                TextField("Key / Path (e.g. data.id)", text: $assertion.targetKey)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 180)
                            }

                            if assertion.type != .is2xxSuccess && assertion.type != .headerExists && assertion.type != .jsonKeyExists {
                                TextField("Expected Value", text: $assertion.expectedValue)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Spacer()

                            Button(action: {
                                assertions.removeAll { $0.id == assertion.id }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private var extractionsList: some View {
        Group {
            if extractionRules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No variable extraction rules configured")
                        .foregroundColor(.secondary)
                    Text("Automatically extract tokens or IDs from response into active environment variables")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Add Token Extractor") {
                        extractionRules.append(VariableExtractionRule(source: .jsonBody, sourceKey: "token", targetEnvironmentVariable: "AUTH_TOKEN"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($extractionRules) { $rule in
                        HStack(spacing: 8) {
                            Toggle("", isOn: $rule.isEnabled)
                                .labelsHidden()

                            Picker("", selection: $rule.source) {
                                ForEach(VariableExtractionRule.ExtractionSource.allCases, id: \.self) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)

                            TextField("Source Path / Header / Regex", text: $rule.sourceKey)
                                .textFieldStyle(.roundedBorder)

                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)

                            TextField("Target Env Variable (e.g. TOKEN)", text: $rule.targetEnvironmentVariable)
                                .textFieldStyle(.roundedBorder)

                            Spacer()

                            Button(action: {
                                extractionRules.removeAll { $0.id == rule.id }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}
