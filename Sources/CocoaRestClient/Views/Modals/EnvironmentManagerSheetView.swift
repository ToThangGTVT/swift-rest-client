//
//  EnvironmentManagerSheetView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct EnvironmentManagerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var envVM: EnvironmentViewModel

    @State private var selectedProfileId: UUID?
    @State private var newEnvName: String = ""
    @State private var showingAddAlert: Bool = false

    public init(envVM: EnvironmentViewModel = EnvironmentViewModel.shared) {
        self.envVM = envVM
        self._selectedProfileId = State(initialValue: envVM.selectedEnvironmentId ?? envVM.environments.first?.id)
    }

    private var currentProfileIndex: Int? {
        guard let id = selectedProfileId else { return nil }
        return envVM.environments.firstIndex(where: { $0.id == id })
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Manage Environments & Variables")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    envVM.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)

            Divider()

            HSplitView {
                // Left: Environment list
                VStack(spacing: 0) {
                    List(selection: $selectedProfileId) {
                        ForEach(envVM.environments) { env in
                            HStack {
                                Text(env.name)
                                    .fontWeight(env.id == envVM.selectedEnvironmentId ? .bold : .regular)
                                Spacer()
                                if env.id == envVM.selectedEnvironmentId {
                                    Text("Active")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                }
                            }
                            .tag(env.id)
                            .contextMenu {
                                Button("Set as Active") {
                                    envVM.selectedEnvironmentId = env.id
                                }
                                Button("Delete", role: .destructive) {
                                    envVM.deleteEnvironment(withId: env.id)
                                }
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))

                    Divider()

                    HStack {
                        Button(action: { showingAddAlert = true }) {
                            Image(systemName: "plus")
                        }
                        .help("Add Environment")

                        Button(action: {
                            if let id = selectedProfileId {
                                envVM.deleteEnvironment(withId: id)
                            }
                        }) {
                            Image(systemName: "minus")
                        }
                        .disabled(selectedProfileId == nil)
                        .help("Delete Environment")

                        Spacer()

                        Button("Set Active") {
                            if let id = selectedProfileId {
                                envVM.selectedEnvironmentId = id
                            }
                        }
                        .disabled(selectedProfileId == nil)
                    }
                    .padding(8)
                }
                .frame(minWidth: 180, maxWidth: 220)

                // Right: Variables editor
                VStack(alignment: .leading, spacing: 8) {
                    if let idx = currentProfileIndex {
                        HStack {
                            Text("Environment Name:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Name", text: $envVM.environments[idx].name)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)

                        Text("Variables can be referenced as {{variableName}} or ${variableName}")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)

                        Divider()

                        KeyValueEditorTable(
                            items: $envVM.environments[idx].variables,
                            keyPlaceholder: "Variable Name",
                            valuePlaceholder: "Value"
                        )
                    } else {
                        VStack {
                            Text("Select an environment to edit its variables.")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(width: 650, height: 440)
        .alert("New Environment", isPresented: $showingAddAlert) {
            TextField("Environment Name", text: $newEnvName)
            Button("Cancel", role: .cancel) { newEnvName = "" }
            Button("Create") {
                if !newEnvName.isEmpty {
                    envVM.addEnvironment(name: newEnvName)
                    newEnvName = ""
                }
            }
        }
    }
}
