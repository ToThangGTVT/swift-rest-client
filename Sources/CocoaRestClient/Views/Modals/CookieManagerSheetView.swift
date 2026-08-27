//
//  CookieManagerSheetView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct CookieManagerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cookies: [CookieItem] = []
    @State private var searchQuery: String = ""
    @State private var showingAddCookie: Bool = false
    
    @State private var newName: String = ""
    @State private var newValue: String = ""
    @State private var newDomain: String = "localhost"
    @State private var newPath: String = "/"
    @State private var newIsSecure: Bool = false
    @State private var newIsHttpOnly: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cookie Jar Manager")
                        .font(.headline)
                    Text("Manage session and persistent cookies stored by domain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button(action: { showingAddCookie = true }) {
                    Label("Add Cookie", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button("Clear All", role: .destructive) {
                    CookieJarStore.shared.clearAll()
                    loadCookies()
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter cookies by domain or name...", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Table of Cookies
            if filteredCookies.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(searchQuery.isEmpty ? "No cookies stored in Cookie Jar" : "No cookies matching \"\(searchQuery)\"")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredCookies) { cookie in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(cookie.name)
                                        .fontWeight(.semibold)
                                        .font(.system(size: 13, design: .monospaced))
                                    Text("=\(cookie.value)")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 13, design: .monospaced))
                                        .lineLimit(1)
                                }
                                HStack(spacing: 12) {
                                    Label(cookie.domain, systemImage: "globe")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                    Label(cookie.path, systemImage: "folder")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if cookie.isSecure {
                                        Text("Secure")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundColor(.green)
                                            .cornerRadius(3)
                                    }
                                    if cookie.isHttpOnly {
                                        Text("HttpOnly")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.purple.opacity(0.2))
                                            .foregroundColor(.purple)
                                            .cornerRadius(3)
                                    }
                                }
                            }

                            Spacer()

                            Button(action: {
                                CookieJarStore.shared.removeCookie(withId: cookie.id)
                                loadCookies()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(minWidth: 650, minHeight: 450)
        .onAppear {
            loadCookies()
        }
        .sheet(isPresented: $showingAddCookie) {
            VStack(spacing: 16) {
                Text("Add New Cookie")
                    .font(.headline)

                Form {
                    TextField("Name:", text: $newName)
                    TextField("Value:", text: $newValue)
                    TextField("Domain:", text: $newDomain)
                    TextField("Path:", text: $newPath)
                    Toggle("Secure (HTTPS only)", isOn: $newIsSecure)
                    Toggle("HttpOnly", isOn: $newIsHttpOnly)
                }
                .frame(width: 320)

                HStack {
                    Button("Cancel") {
                        showingAddCookie = false
                    }
                    Spacer()
                    Button("Save") {
                        if !newName.isEmpty {
                            let cookie = CookieItem(
                                name: newName,
                                value: newValue,
                                domain: newDomain,
                                path: newPath,
                                isSecure: newIsSecure,
                                isHttpOnly: newIsHttpOnly
                            )
                            CookieJarStore.shared.setCookie(cookie)
                            loadCookies()
                            newName = ""
                            newValue = ""
                            showingAddCookie = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 380)
        }
    }

    private var filteredCookies: [CookieItem] {
        guard !searchQuery.isEmpty else { return cookies }
        return cookies.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.domain.localizedCaseInsensitiveContains(searchQuery) ||
            $0.value.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private func loadCookies() {
        self.cookies = CookieJarStore.shared.getAllCookies()
    }
}
