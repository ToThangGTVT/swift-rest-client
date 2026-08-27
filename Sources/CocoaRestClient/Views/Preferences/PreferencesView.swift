//
//  PreferencesView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct PreferencesView: View {
    @ObservedObject public var prefVM = PreferencesViewModel.shared

    @State private var clientCertPath: String = ""
    @State private var clientCertPassword: String = ""

    public init() {}

    public var body: some View {
        TabView {
            // General Tab
            Form {
                Section("Network & Connection") {
                    HStack {
                        Text("Response Timeout:")
                        TextField("", value: $prefVM.timeoutSeconds, formatter: NumberFormatter())
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("seconds")
                            .foregroundColor(.secondary)
                    }

                    Toggle("Follow HTTP Redirects", isOn: $prefVM.followRedirects)
                    Toggle("Apply original HTTP Method on Redirect (POST/PUT instead of GET)", isOn: $prefVM.applyHttpMethodOnRedirect)
                    Toggle("Allow Self-Signed & Untrusted SSL Certificates", isOn: $prefVM.allowSelfSignedCerts)
                    Toggle("Disable Automatic Cookie Jar handling", isOn: $prefVM.disableCookies)
                }

                Section("Defaults") {
                    Picker("Default Content-Type:", selection: $prefVM.defaultContentType) {
                        Text("application/json").tag("application/json")
                        Text("application/x-www-form-urlencoded").tag("application/x-www-form-urlencoded")
                        Text("application/xml").tag("application/xml")
                        Text("text/plain").tag("text/plain")
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            // Editor Tab
            Form {
                Section("Editor & Display") {
                    Toggle("Enable Syntax Highlighting", isOn: $prefVM.syntaxHighlight)
                    Toggle("Show Line Numbers", isOn: $prefVM.showLineNumbers)
                }
            }
            .padding(20)
            .tabItem {
                Label("Editor", systemImage: "character.cursor.ibeam")
            }

            // Certificates (mTLS) Tab
            Form {
                Section("Client SSL / TLS Certificates (mTLS)") {
                    Text("Provide a PKCS#12 (.p12 / .pfx) client certificate for mutual TLS authentication.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("Certificate File (.p12 / .pfx)", text: $clientCertPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                clientCertPath = url.path
                            }
                        }
                    }

                    SecureField("Certificate Password (if protected)", text: $clientCertPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(20)
            .tabItem {
                Label("Certificates", systemImage: "lock.shield")
            }
        }
        .frame(width: 520, height: 340)
    }
}
