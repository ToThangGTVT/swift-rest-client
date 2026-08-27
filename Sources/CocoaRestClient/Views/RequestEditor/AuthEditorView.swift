//
//  AuthEditorView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

public struct AuthEditorView: View {
    @Binding public var auth: Authentication

    public init(auth: Binding<Authentication>) {
        self._auth = auth
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Top Bar: Auth Type Segmented Picker
            HStack {
                Picker("", selection: $auth.type) {
                    ForEach(AuthType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            Divider()

            // Form content based on Auth type
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch auth.type {
                    case .none:
                        VStack(spacing: 8) {
                            Image(systemName: "lock.open")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("No authentication will be sent with this request.")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)

                    case .basic:
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Username:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("Username", text: $auth.username)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Password:")
                                    .frame(width: 100, alignment: .trailing)
                                SecureField("Password", text: $auth.password)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Spacer().frame(width: 100)
                                Toggle("Send Authorization header preemptively", isOn: $auth.isPreemptive)
                                    .toggleStyle(.checkbox)
                            }
                        }
                        .frame(maxWidth: 480)
                        .padding(.top, 8)
                        .padding(.horizontal, 12)

                    case .bearer:
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Bearer Token:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("JWT or API Access Token", text: $auth.token)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .frame(maxWidth: 480)
                        .padding(.top, 8)
                        .padding(.horizontal, 12)

                    case .apiKey:
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Key Name:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("e.g. X-API-Key, api_key", text: $auth.apiKeyName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Value:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("API Key Value", text: $auth.apiKeyValue)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Add To:")
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $auth.apiKeyLocation) {
                                    ForEach(APIKeyLocation.allCases, id: \.self) { loc in
                                        Text(loc.rawValue).tag(loc)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 220)
                            }
                        }
                        .frame(maxWidth: 480)
                        .padding(.top, 8)
                        .padding(.horizontal, 12)

                    case .oauth2:
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Grant Type:")
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $auth.oauth2GrantType) {
                                    ForEach(OAuth2GrantType.allCases, id: \.self) { grant in
                                        Text(grant.rawValue).tag(grant)
                                    }
                                }
                                .labelsHidden()
                            }

                            HStack {
                                Text("Access Token:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("Bearer access token", text: $auth.oauth2AccessToken)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Token URL:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("https://auth.example.com/oauth/token", text: $auth.oauth2TokenUrl)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Client ID:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("Client Identifier", text: $auth.oauth2ClientId)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Client Secret:")
                                    .frame(width: 100, alignment: .trailing)
                                SecureField("Client Secret", text: $auth.oauth2ClientSecret)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Scope:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("read write", text: $auth.oauth2Scope)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .frame(maxWidth: 520)
                        .padding(.top, 8)
                        .padding(.horizontal, 12)

                    case .digest:
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Username:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("Username", text: $auth.username)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Password:")
                                    .frame(width: 100, alignment: .trailing)
                                SecureField("Password", text: $auth.password)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .frame(maxWidth: 480)
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
