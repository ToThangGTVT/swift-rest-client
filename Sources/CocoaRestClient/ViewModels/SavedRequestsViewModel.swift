//
//  SavedRequestsViewModel.swift
//  CocoaRestClientApp
//

import Foundation
import SwiftUI
import CocoaRestClientCore
import UniformTypeIdentifiers

public final class SavedRequestsViewModel: ObservableObject {
    @Published public var rootFolder: RequestFolder
    @Published public var searchQuery: String = ""
    @Published public var selectedItemId: UUID?
    @Published public var showingSaveSheet: Bool = false
    @Published public var showingExportImportSheet: Bool = false
    @Published public var saveSheetRequestName: String = ""

    public init() {
        self.rootFolder = SavedRequestsStore.shared.loadRootFolder()
    }

    public func persist() {
        SavedRequestsStore.shared.saveRootFolder(rootFolder)
    }

    public func addRequest(_ request: RestRequest, intoFolderId targetFolderId: UUID? = nil) {
        var copy = request
        if copy.name.isEmpty || copy.name == "New Request" {
            copy.name = URL(string: request.url)?.host ?? "Saved Request"
        }

        if let folderId = targetFolderId {
            insertItem(.request(copy), intoFolderWithId: folderId)
        } else {
            rootFolder.append(.request(copy))
        }
        persist()
    }

    public func createFolder(name: String = "New Folder", intoFolderId targetFolderId: UUID? = nil) {
        let newFolder = RequestFolder(name: name)
        if let folderId = targetFolderId {
            insertItem(.folder(newFolder), intoFolderWithId: folderId)
        } else {
            rootFolder.append(.folder(newFolder))
        }
        persist()
    }

    public func deleteItem(withId id: UUID) {
        if rootFolder.removeItem(withId: id) {
            persist()
        }
    }

    public func overwriteRequest(withId id: UUID, with updatedRequest: RestRequest) {
        if let idx = rootFolder.items.firstIndex(where: { $0.id == id }) {
            var newReq = updatedRequest
            newReq.id = id
            newReq.name = rootFolder.items[idx].name
            rootFolder.items[idx] = .request(newReq)
            persist()
            return
        }
        for i in 0..<rootFolder.items.count {
            if case .folder(var sub) = rootFolder.items[i] {
                if overwriteInFolder(&sub, id: id, updatedRequest: updatedRequest) {
                    rootFolder.items[i] = .folder(sub)
                    persist()
                    return
                }
            }
        }
    }

    private func overwriteInFolder(_ folder: inout RequestFolder, id: UUID, updatedRequest: RestRequest) -> Bool {
        if let idx = folder.items.firstIndex(where: { $0.id == id }) {
            var newReq = updatedRequest
            newReq.id = id
            newReq.name = folder.items[idx].name
            folder.items[idx] = .request(newReq)
            return true
        }
        for i in 0..<folder.items.count {
            if case .folder(var sub) = folder.items[i] {
                if overwriteInFolder(&sub, id: id, updatedRequest: updatedRequest) {
                    folder.items[i] = .folder(sub)
                    return true
                }
            }
        }
        return false
    }

    private func insertItem(_ item: RequestTreeItem, intoFolderWithId folderId: UUID) {
        if rootFolder.id == folderId {
            rootFolder.append(item)
            return
        }
        for i in 0..<rootFolder.items.count {
            if case .folder(var sub) = rootFolder.items[i] {
                if insertIntoFolder(&sub, item: item, targetId: folderId) {
                    rootFolder.items[i] = .folder(sub)
                    return
                }
            }
        }
        // Fallback: append to root
        rootFolder.append(item)
    }

    private func insertIntoFolder(_ folder: inout RequestFolder, item: RequestTreeItem, targetId: UUID) -> Bool {
        if folder.id == targetId {
            folder.append(item)
            return true
        }
        for i in 0..<folder.items.count {
            if case .folder(var sub) = folder.items[i] {
                if insertIntoFolder(&sub, item: item, targetId: targetId) {
                    folder.items[i] = .folder(sub)
                    return true
                }
            }
        }
        return false
    }

    public var filteredRequests: [(path: String, request: RestRequest)] {
        let all = rootFolder.allRequests()
        guard !searchQuery.isEmpty else { return all }
        return all.filter {
            $0.request.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.request.url.localizedCaseInsensitiveContains(searchQuery)
        }
    }
}
