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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

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
                    .font(.system(size: 11))

                if !savedVM.searchQuery.isEmpty {
                    Button(action: { savedVM.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // Tree List in tight ScrollView
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if !savedVM.searchQuery.isEmpty {
                        // Flat filtered list
                        if savedVM.filteredRequests.isEmpty {
                            Text("No matching requests")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                        } else {
                            ForEach(savedVM.filteredRequests, id: \.request.id) { item in
                                CompactFilteredRequestRow(
                                    item: item,
                                    isSelected: currentRequest.id == item.request.id,
                                    onSelect: { onSelectRequest(item.request) }
                                )
                            }
                        }
                    } else {
                        // Hierarchical tree
                        if savedVM.rootFolder.items.isEmpty {
                            VStack(spacing: 6) {
                                Text("No saved requests")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Create Folder") {
                                    targetFolderIdForNewFolder = nil
                                    showingNewFolderAlert = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                        } else {
                            ForEach(savedVM.rootFolder.items) { item in
                                CompactTreeItemView(
                                    item: item,
                                    level: 0,
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
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

private struct CompactTreeItemView: View {
    let item: RequestTreeItem
    let level: Int
    @ObservedObject var savedVM: SavedRequestsViewModel
    let currentRequest: RestRequest
    let onSelectRequest: (RestRequest) -> Void
    let onNewFolderIn: (UUID) -> Void

    var body: some View {
        switch item {
        case .folder(let folder):
            CompactFolderView(
                folder: folder,
                level: level,
                savedVM: savedVM,
                currentRequest: currentRequest,
                onSelectRequest: onSelectRequest,
                onNewFolderIn: onNewFolderIn
            )

        case .request(let req):
            CompactRequestRow(
                req: req,
                level: level,
                isSelected: currentRequest.id == req.id,
                onSelect: { onSelectRequest(req) },
                onOverwrite: { savedVM.overwriteRequest(withId: req.id, with: currentRequest) },
                onDuplicate: { savedVM.addRequest(req.duplicate(withName: "\(req.name) (Copy)")) },
                onDelete: { savedVM.deleteItem(withId: req.id) }
            )
        }
    }
}

private struct CompactFolderView: View {
    let folder: RequestFolder
    let level: Int
    @ObservedObject var savedVM: SavedRequestsViewModel
    let currentRequest: RestRequest
    let onSelectRequest: (RestRequest) -> Void
    let onNewFolderIn: (UUID) -> Void

    @State private var isExpanded: Bool
    @State private var isHovered: Bool = false

    init(
        folder: RequestFolder,
        level: Int,
        savedVM: SavedRequestsViewModel,
        currentRequest: RestRequest,
        onSelectRequest: @escaping (RestRequest) -> Void,
        onNewFolderIn: @escaping (UUID) -> Void
    ) {
        self.folder = folder
        self.level = level
        self.savedVM = savedVM
        self.currentRequest = currentRequest
        self.onSelectRequest = onSelectRequest
        self.onNewFolderIn = onNewFolderIn
        self._isExpanded = State(initialValue: folder.isExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Folder Header Row
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isExpanded)
                    .frame(width: 12)

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 11))

                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text("\(folder.totalRequestCount)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(3)
            }
            .padding(.leading, CGFloat(level) * 12.0)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            .cornerRadius(4)
            .onHover { isHovered = $0 }
            .onTapGesture {
                isExpanded.toggle()
                savedVM.setFolderExpanded(id: folder.id, isExpanded: isExpanded)
            }
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

            // Children rows when expanded
            if isExpanded {
                ForEach(folder.items) { subItem in
                    CompactTreeItemView(
                        item: subItem,
                        level: level + 1,
                        savedVM: savedVM,
                        currentRequest: currentRequest,
                        onSelectRequest: onSelectRequest,
                        onNewFolderIn: onNewFolderIn
                    )
                }
            }
        }
    }
}

private struct CompactRequestRow: View {
    let req: RestRequest
    let level: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onOverwrite: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Text(req.method.rawValue)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(methodColor(req.method).opacity(0.18))
                .foregroundColor(methodColor(req.method))
                .cornerRadius(3)

            Text(req.name)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))

            Spacer()
        }
        .padding(.leading, CGFloat(level) * 12.0 + 16.0)
        .padding(.horizontal, 4)
        .padding(.vertical, 2.5)
        .contentShape(Rectangle())
        .background(
            isSelected
                ? Color.accentColor.opacity(0.15)
                : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .cornerRadius(4)
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Open Request") { onSelect() }
            Button("Overwrite with Current") { onOverwrite() }
            Button("Duplicate") { onDuplicate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
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

private struct CompactFilteredRequestRow: View {
    let item: (path: String, request: RestRequest)
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(item.request.method.rawValue)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(methodColor(item.request.method).opacity(0.18))
                    .foregroundColor(methodColor(item.request.method))
                    .cornerRadius(3)

                Text(item.request.name)
                    .font(.system(size: 11.5))
                    .lineLimit(1)

                Spacer()
            }

            Text(item.path)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .background(
            isSelected
                ? Color.accentColor.opacity(0.15)
                : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .cornerRadius(4)
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
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
