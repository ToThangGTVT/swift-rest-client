//
//  AuthEditorView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct AuthEditorView: View {
    @Binding public var auth: Authentication

    public init(auth: Binding<Authentication>) {
        self._auth = auth
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $auth.type) {
                ForEach(AuthType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

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
                            .frame(width: 90, alignment: .trailing)
                        TextField("Username", text: $auth.username)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Password:")
                            .frame(width: 90, alignment: .trailing)
                        SecureField("Password", text: $auth.password)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Spacer().frame(width: 90)
                        Toggle("Send Authorization header preemptively", isOn: $auth.isPreemptive)
                            .toggleStyle(.checkbox)
                    }
                }
                .frame(maxWidth: 450)
                .padding(.top, 4)

            case .bearer:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bearer Token:")
                            .frame(width: 90, alignment: .trailing)
                        TextField("JWT or API Access Token", text: $auth.token)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: 450)
                .padding(.top, 4)

            case .digest:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Username:")
                            .frame(width: 90, alignment: .trailing)
                        TextField("Username", text: $auth.username)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Password:")
                            .frame(width: 90, alignment: .trailing)
                        SecureField("Password", text: $auth.password)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: 450)
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding()
    }
}
