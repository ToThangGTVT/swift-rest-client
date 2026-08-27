//
//  WorkspaceSwitcherHeaderView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct WorkspaceSwitcherHeaderView: View {
    @ObservedObject public var wsManagerVM = WorkspaceManagerViewModel.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            // Workspace Dropdown Menu
            Menu {
                Section("Workspaces") {
                    ForEach(wsManagerVM.workspaces) { ws in
                        Button(action: { wsManagerVM.switchWorkspace(to: ws) }) {
                            HStack {
                                Text(ws.name)
                                if ws.id == wsManagerVM.activeWorkspace.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                Button("Manage Workspaces...") {
                    wsManagerVM.showingWorkspaceManagerSheet = true
                }

                Button("Clone Git Repository...") {
                    wsManagerVM.showingCloneWorkspaceSheet = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 11))

                    Text(wsManagerVM.activeWorkspace.name)
                        .font(.system(size: 12.5, weight: .bold))
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .menuStyle(.borderlessButton)

            Spacer()

            // Git Branch & Status Badge
            if wsManagerVM.gitStatus.isGitRepo {
                HStack(spacing: 4) {
                    Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Text(wsManagerVM.gitStatus.currentBranch)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Status Indicator
                    if wsManagerVM.gitStatus.hasUncommittedChanges {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .help("Uncommitted changes in workspace")
                    } else if wsManagerVM.gitStatus.unpushedCommitCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .help("\(wsManagerVM.gitStatus.unpushedCommitCount) unpushed commits")
                    } else {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .help("Git workspace is clean and up to date")
                    }

                    // Quick Sync Button
                    Button(action: {
                        wsManagerVM.commitAndPush(message: "Sync from CocoaRestClient")
                    }) {
                        if wsManagerVM.isSyncing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Sync & Push Workspace to Git")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            } else {
                Button(action: {
                    wsManagerVM.showingWorkspaceManagerSheet = true
                }) {
                    Label("Link Git", systemImage: "link")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
