//
//  SavedRequestsSidebarView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public enum SidebarTab: String, CaseIterable, Identifiable {
    case saved = "Saved"
    case history = "History"

    public var id: String { rawValue }
}

public struct SavedRequestsSidebarView: View {
    @ObservedObject public var savedVM: SavedRequestsViewModel
    public var onSelectRequest: (RestRequest) -> Void
    public var currentRequest: RestRequest

    @State private var selectedSidebarTab: SidebarTab = .saved
    @State private var showingNewFolderAlert: Bool = false
    @State private var newFolderName: String = "New Folder"
    @State private var targetFolderIdForNewFolder: UUID? = nil

    public init(
        savedVM: SavedRequestsViewModel,
        currentRequest: RestRequest,
        onSelectRequest: @escaping (RestRequest) -> Void
    ) {
        self.savedVM = savedVM
        self.currentRequest = currentRequest
        self.onSelectRequest = onSelectRequest
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Mode Switcher (Saved vs History)
            Picker("", selection: $selectedSidebarTab) {
                ForEach(SidebarTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if selectedSidebarTab == .history {
                HistorySidebarView(onSelectHistoryItem: onSelectRequest)
            } else {
                savedRequestsContent
            }
        }
        .frame(minWidth: 200)
        .alert("Create New Folder", isPresented: $showingNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                savedVM.createFolder(name: newFolderName, intoFolderId: targetFolderIdForNewFolder)
                newFolderName = "New Folder"
            }
            Button("Cancel", role: .cancel) {
                newFolderName = "New Folder"
            }
        }
    }

    @ViewBuilder
    private var savedRequestsContent: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Search saved requests...", text: $savedVM.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.caption)

                if !savedVM.searchQuery.isEmpty {
                    Button(action: { savedVM.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(8)

            Divider()

            // Tree List
            if !savedVM.searchQuery.isEmpty {
                // Flat filtered list
                List(savedVM.filteredRequests, id: \.request.id) { item in
                    Button(action: { onSelectRequest(item.request) }) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.request.method.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(methodColor(item.request.method).opacity(0.2))
                                    .foregroundColor(methodColor(item.request.method))
                                    .cornerRadius(3)

                                Text(item.request.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            Text(item.path)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            } else {
                // Hierarchical list
                List {
                    ForEach(savedVM.rootFolder.items) { item in
                        RequestTreeItemView(
                            item: item,
                            savedVM: savedVM,
                            currentRequest: currentRequest,
                            onSelectRequest: onSelectRequest,
                            onNewFolderIn: { folderId in
                                targetFolderIdForNewFolder = folderId
                                showingNewFolderAlert = true
                            }
                        )
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Bottom Actions Bar
            HStack {
                Button(action: {
                    targetFolderIdForNewFolder = nil
                    showingNewFolderAlert = true
                }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()

                Button(action: { savedVM.showingExportImportSheet = true }) {
                    Label("Import/Export", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .green
        case .post: return .blue
        case .put: return .orange
        case .delete: return .red
        default: return .gray
        }
    }
}

private struct RequestTreeItemView: View {
    let item: RequestTreeItem
    @ObservedObject var savedVM: SavedRequestsViewModel
    let currentRequest: RestRequest
    let onSelectRequest: (RestRequest) -> Void
    let onNewFolderIn: (UUID) -> Void

    var body: some View {
        switch item {
        case .folder(let folder):
            RequestTreeFolderView(
                folder: folder,
                savedVM: savedVM,
                currentRequest: currentRequest,
                onSelectRequest: onSelectRequest,
                onNewFolderIn: onNewFolderIn
            )

        case .request(let req):
            Button(action: { onSelectRequest(req) }) {
                HStack(spacing: 6) {
                    Text(req.method.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(methodColor(req.method).opacity(0.18))
                        .foregroundColor(methodColor(req.method))
                        .cornerRadius(3)

                    Text(req.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Open Request") {
                    onSelectRequest(req)
                }
                Button("Overwrite with Current") {
                    savedVM.overwriteRequest(withId: req.id, with: currentRequest)
                }
                Button("Duplicate") {
                    savedVM.addRequest(req.duplicate(withName: "\(req.name) (Copy)"))
                }
                Divider()
                Button("Delete", role: .destructive) {
                    savedVM.deleteItem(withId: req.id)
                }
            }
        }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .green
        case .post: return .blue
        case .put: return .orange
        case .delete: return .red
        default: return .gray
        }
    }
}

private struct RequestTreeFolderView: View {
    let folder: RequestFolder
    @ObservedObject var savedVM: SavedRequestsViewModel
    let currentRequest: RestRequest
    let onSelectRequest: (RestRequest) -> Void
    let onNewFolderIn: (UUID) -> Void

    @State private var isExpanded: Bool

    init(
        folder: RequestFolder,
        savedVM: SavedRequestsViewModel,
        currentRequest: RestRequest,
        onSelectRequest: @escaping (RestRequest) -> Void,
        onNewFolderIn: @escaping (UUID) -> Void
    ) {
        self.folder = folder
        self.savedVM = savedVM
        self.currentRequest = currentRequest
        self.onSelectRequest = onSelectRequest
        self.onNewFolderIn = onNewFolderIn
        self._isExpanded = State(initialValue: folder.isExpanded)
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                ForEach(folder.items) { subItem in
                    RequestTreeItemView(
                        item: subItem,
                        savedVM: savedVM,
                        currentRequest: currentRequest,
                        onSelectRequest: onSelectRequest,
                        onNewFolderIn: onNewFolderIn
                    )
                }
            },
            label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.accentColor)
                    Text(folder.name)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(folder.totalRequestCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Add Request Here") {
                        savedVM.addRequest(currentRequest, intoFolderId: folder.id)
                    }
                    Button("New Subfolder") {
                        onNewFolderIn(folder.id)
                    }
                    Divider()
                    Button("Delete Folder", role: .destructive) {
                        savedVM.deleteItem(withId: folder.id)
                    }
                }
            }
        )
        .onChange(of: isExpanded) { newValue in
            savedVM.setFolderExpanded(id: folder.id, isExpanded: newValue)
        }
    }
}
