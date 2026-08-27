//
//  PreferencesView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct PreferencesView: View {
    @ObservedObject public var prefVM = PreferencesViewModel.shared

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
                    Toggle("Disable Cookies handling", isOn: $prefVM.disableCookies)
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
        }
        .frame(width: 480, height: 320)
    }
}
