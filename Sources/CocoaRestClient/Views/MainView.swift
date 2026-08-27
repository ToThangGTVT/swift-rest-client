//
//  MainView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct MainView: View {
    @StateObject public var workspaceVM = WorkspaceViewModel()
    @StateObject public var savedVM = SavedRequestsViewModel()
    @ObservedObject public var prefVM = PreferencesViewModel.shared
    @ObservedObject public var envVM = EnvironmentViewModel.shared

    @State private var showingCookieManager: Bool = false
    @State private var showingRealtimeConsole: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SavedRequestsSidebarView(
                savedVM: savedVM,
                currentRequest: workspaceVM.selectedTab?.request ?? RestRequest(),
                onSelectRequest: { req in
                    workspaceVM.openSavedRequest(req)
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
            .frame(minWidth: 200)
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
                        },
                        onOpenCodeGenerator: {
                            workspaceVM.showingCodeGenerator = true
                        }
                    )
                } else {
                    VStack {
                        Text("No tab selected")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 620)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $workspaceVM.showingFastSearch) {
            FastSearchSheetView(savedVM: savedVM) { selectedReq in
                workspaceVM.openSavedRequest(selectedReq)
            }
        }
        .sheet(isPresented: $workspaceVM.showingDiffView) {
            DiffSheetView(workspaceVM: workspaceVM)
        }
        .sheet(isPresented: $workspaceVM.showingCurlImport) {
            CurlImportSheetView { importedReq in
                workspaceVM.createNewTab(with: importedReq)
            }
        }
        .sheet(isPresented: $workspaceVM.showingCodeGenerator) {
            if let tab = workspaceVM.selectedTab {
                CodeGeneratorSheetView(request: tab.request)
            }
        }
        .sheet(isPresented: $envVM.showingEnvironmentSheet) {
            EnvironmentManagerSheetView(envVM: envVM)
        }
        .sheet(isPresented: $savedVM.showingExportImportSheet) {
            ExportImportSheetView(savedVM: savedVM)
        }
        .sheet(isPresented: $savedVM.showingSaveSheet) {
            if let tab = workspaceVM.selectedTab {
                SaveRequestSheetView(savedVM: savedVM, requestToSave: tab.request)
            }
        }
        .sheet(isPresented: $showingCookieManager) {
            CookieManagerSheetView()
        }
        .sheet(isPresented: $showingRealtimeConsole) {
            VStack(spacing: 0) {
                HStack {
                    Text("Real-time WebSocket & SSE Testing Console")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showingRealtimeConsole = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(14)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                WebSocketClientView()
            }
            .frame(minWidth: 800, minHeight: 520)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Environment Selector
                Menu {
                    ForEach(envVM.environments) { env in
                        Button(action: { envVM.selectedEnvironmentId = env.id }) {
                            HStack {
                                Text(env.name)
                                if env.id == envVM.selectedEnvironmentId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Manage Environments...") {
                        envVM.showingEnvironmentSheet = true
                    }
                } label: {
                    Label(envVM.activeEnvironment?.name ?? "No Environment", systemImage: "globe")
                        .font(.caption)
                }
                .help("Select Active Environment")

                // Realtime WebSocket & SSE Console
                Button(action: { showingRealtimeConsole = true }) {
                    Label("Real-time (WS/SSE)", systemImage: "antenna.radiowaves.left.and.right")
                }
                .help("Open Real-time WebSocket & SSE Console")

                // Cookies Manager
                Button(action: { showingCookieManager = true }) {
                    Label("Cookies", systemImage: "circle.hexagongrid")
                }
                .help("Manage Stored Cookies (Cookie Jar)")

                // Import cURL
                Button(action: { workspaceVM.showingCurlImport = true }) {
                    Label("Import cURL", systemImage: "square.and.arrow.down")
                }
                .help("Import from cURL Command (Cmd+Shift+I)")

                // Code Snippets
                Button(action: { workspaceVM.showingCodeGenerator = true }) {
                    Label("Code Snippets", systemImage: "curlybraces")
                }
                .help("Generate Code Snippets (Cmd+Shift+G)")

                // Quick Open
                Button(action: { workspaceVM.showingFastSearch = true }) {
                    Label("Quick Open", systemImage: "magnifyingglass")
                }
                .help("Quick Open Saved Request (Cmd+O)")

                // Diff Responses
                Button(action: { workspaceVM.showingDiffView = true }) {
                    Label("Diff Responses", systemImage: "square.split.2x1")
                }
                .help("Compare Two Responses (Cmd+D)")

                // New Tab
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
        .onReceive(NotificationCenter.default.publisher(for: .importCurlNotification)) { _ in
            workspaceVM.showingCurlImport = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .codeGeneratorNotification)) { _ in
            workspaceVM.showingCodeGenerator = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .environmentManagerNotification)) { _ in
            envVM.showingEnvironmentSheet = true
        }
    }
}

public struct RequestDetailView: View {
    @ObservedObject public var tabVM: RequestTabViewModel
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

    private func tabTitle(for tab: RequestEditorTab) -> String {
        switch tab {
        case .params:
            let count = tabVM.request.urlParams.count
            return count > 0 ? "Params (\(count))" : "Params"
        case .headers:
            let count = tabVM.request.headers.count
            return count > 0 ? "Headers (\(count))" : "Headers"
        case .tests:
            let count = tabVM.request.assertions.count
            return count > 0 ? "Tests (\(count))" : "Tests"
        default:
            return tab.rawValue
        }
    }

    public var body: some View {
        VSplitView {
            // Top Pane: Request Editor
            VStack(spacing: 0) {
                RequestHeaderBar(
                    tabVM: tabVM,
                    onSave: onSave,
                    onOpenCodeGenerator: onOpenCodeGenerator
                )

                // Request Tabs Segmented Control
                HStack {
                    Picker("", selection: $tabVM.selectedRequestTab) {
                        ForEach(RequestEditorTab.allCases) { tab in
                            Text(tabTitle(for: tab)).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 440)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()

                // Request Tab Editor Content
                switch tabVM.selectedRequestTab {
                case .body:
                    RequestBodyEditorView(tabVM: tabVM)
                case .params:
                    ParamsTableView(request: $tabVM.request)
                        .padding(.horizontal, 10)
                case .headers:
                    HeadersTableView(headers: $tabVM.request.headers)
                        .padding(.horizontal, 10)
                case .auth:
                    AuthEditorView(auth: $tabVM.request.auth)
                case .tests:
                    TestsEditorView(
                        assertions: $tabVM.request.assertions,
                        extractionRules: $tabVM.request.extractionRules
                    )
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
                        WorkspaceTabItemView(
                            tab: tab,
                            isSelected: workspaceVM.selectedTabId == tab.id,
                            onSelect: { workspaceVM.selectedTabId = tab.id },
                            onClose: { workspaceVM.closeTab(withId: tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Spacer()

            Button(action: { workspaceVM.createNewTab() }) {
                Image(systemName: "plus")
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("New Tab (Cmd+T)")
            .padding(.trailing, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct WorkspaceTabItemView: View {
    @ObservedObject var tab: RequestTabViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.request.method.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(methodColor(tab.request.method))

            Text(tab.tabTitle)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .secondary)

            if isHovered || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color(NSColor.windowBackgroundColor) : Color.clear)
        .cornerRadius(6)
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
