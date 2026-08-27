//
//  MainView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct MainView: View {
    @StateObject public var workspaceVM = WorkspaceViewModel()
    @StateObject public var savedVM = SavedRequestsViewModel()
    @ObservedObject public var prefVM = PreferencesViewModel.shared

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SavedRequestsSidebarView(
                savedVM: savedVM,
                currentRequest: workspaceVM.selectedTab?.request ?? RestRequest(),
                onSelectRequest: { req in
                    workspaceVM.openSavedRequest(req)
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 380)
        } detail: {
            VStack(spacing: 0) {
                // Tab Bar
                WorkspaceTabBar(workspaceVM: workspaceVM)

                Divider()

                if let currentTab = workspaceVM.selectedTab {
                    RequestDetailView(
                        tabVM: currentTab,
                        onSave: {
                            savedVM.showingSaveSheet = true
                        }
                    )
                } else {
                    VStack {
                        Text("No tab selected")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $workspaceVM.showingFastSearch) {
            FastSearchSheetView(savedVM: savedVM) { selectedReq in
                workspaceVM.openSavedRequest(selectedReq)
            }
        }
        .sheet(isPresented: $workspaceVM.showingDiffView) {
            DiffSheetView(workspaceVM: workspaceVM)
        }
        .sheet(isPresented: $savedVM.showingExportImportSheet) {
            ExportImportSheetView(savedVM: savedVM)
        }
        .sheet(isPresented: $savedVM.showingSaveSheet) {
            if let tab = workspaceVM.selectedTab {
                SaveRequestSheetView(savedVM: savedVM, requestToSave: tab.request)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { workspaceVM.showingFastSearch = true }) {
                    Label("Quick Open", systemImage: "magnifyingglass")
                }
                .help("Quick Open Saved Request (Cmd+O)")

                Button(action: { workspaceVM.showingDiffView = true }) {
                    Label("Diff Responses", systemImage: "square.split.2x1")
                }
                .help("Compare Two Responses (Cmd+D)")

                Button(action: { workspaceVM.createNewTab() }) {
                    Label("New Tab", systemImage: "plus")
                }
                .help("Open New Tab (Cmd+T)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewTabNotification)) { _ in
            workspaceVM.createNewTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeCurrentTabNotification)) { _ in
            if let id = workspaceVM.selectedTabId {
                workspaceVM.closeTab(withId: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveRequestNotification)) { _ in
            savedVM.showingSaveSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickOpenNotification)) { _ in
            workspaceVM.showingFastSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .sendRequestNotification)) { _ in
            workspaceVM.selectedTab?.sendRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadRequestNotification)) { _ in
            workspaceVM.selectedTab?.reloadLastRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyCurlNotification)) { _ in
            workspaceVM.selectedTab?.copyCurlCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .formatBodyNotification)) { _ in
            workspaceVM.selectedTab?.formatRawBody()
        }
        .onReceive(NotificationCenter.default.publisher(for: .diffResponsesNotification)) { _ in
            workspaceVM.showingDiffView = true
        }
    }
}

public struct RequestDetailView: View {
    @ObservedObject public var tabVM: RequestTabViewModel
    public var onSave: () -> Void

    public init(tabVM: RequestTabViewModel, onSave: @escaping () -> Void) {
        self.tabVM = tabVM
        self.onSave = onSave
    }

    private func tabTitle(for tab: RequestEditorTab) -> String {
        switch tab {
        case .params:
            let count = tabVM.request.urlParams.count
            return count > 0 ? "Query Params (\(count))" : "Query Params"
        case .headers:
            let count = tabVM.request.headers.count
            return count > 0 ? "Headers (\(count))" : "Headers"
        default:
            return tab.rawValue
        }
    }

    public var body: some View {
        VSplitView {
            // Top Pane: Request Editor
            VStack(spacing: 0) {
                RequestHeaderBar(tabVM: tabVM, onSave: onSave)

                // Request Tabs Segmented Control
                HStack {
                    Picker("", selection: $tabVM.selectedRequestTab) {
                        ForEach(RequestEditorTab.allCases) { tab in
                            Text(tabTitle(for: tab)).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 480)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Divider()

                // Request Tab Editor Content
                switch tabVM.selectedRequestTab {
                case .body:
                    RequestBodyEditorView(tabVM: tabVM)
                case .params:
                    ParamsTableView(request: $tabVM.request)
                case .headers:
                    HeadersTableView(headers: $tabVM.request.headers)
                case .auth:
                    AuthEditorView(auth: $tabVM.request.auth)
                case .formFields:
                    KeyValueEditorTable(
                        items: $tabVM.request.params,
                        keyPlaceholder: "Field Name",
                        valuePlaceholder: "Field Value"
                    )
                case .files:
                    FilesTableView(files: $tabVM.request.files)
                }
            }
            .frame(minHeight: 220)

            // Bottom Pane: Response Viewer
            ResponseViewerView(tabVM: tabVM)
                .frame(minHeight: 200)
        }
    }
}

private struct WorkspaceTabBar: View {
    @ObservedObject var workspaceVM: WorkspaceViewModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(workspaceVM.tabs) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: workspaceVM.selectedTabId == tab.id,
                            onSelect: {
                                workspaceVM.selectedTabId = tab.id
                            },
                            onClose: {
                                workspaceVM.closeTab(withId: tab.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }

            Button(action: { workspaceVM.createNewTab() }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .padding(5)
            }
            .buttonStyle(.plain)
            .help("New Tab (Cmd+T)")
            .padding(.trailing, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct TabButton: View {
    @ObservedObject var tab: RequestTabViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.request.method.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(methodColor(tab.request.method))

            Text(tab.tabTitle)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 140)

            if isHovering || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 10)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color(NSColor.separatorColor) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
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
