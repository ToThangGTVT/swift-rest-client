//
//  CocoaRestClientApp.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

@main
struct CocoaRestClientApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 850, minHeight: 600)
        }
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .createNewTabNotification, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeCurrentTabNotification, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command])

                Divider()

                Button("Save Request") {
                    NotificationCenter.default.post(name: .saveRequestNotification, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Quick Open...") {
                    NotificationCenter.default.post(name: .quickOpenNotification, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Request") {
                Button("Send Request") {
                    NotificationCenter.default.post(name: .sendRequestNotification, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Reload Request") {
                    NotificationCenter.default.post(name: .reloadRequestNotification, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("Copy as cURL Command") {
                    NotificationCenter.default.post(name: .copyCurlNotification, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Format JSON Body") {
                    NotificationCenter.default.post(name: .formatBodyNotification, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandMenu("Tools") {
                Button("Compare Two Responses...") {
                    NotificationCenter.default.post(name: .diffResponsesNotification, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
        }

        Settings {
            PreferencesView()
        }
    }
}

public extension Notification.Name {
    static let createNewTabNotification = Notification.Name("CRC.createNewTab")
    static let closeCurrentTabNotification = Notification.Name("CRC.closeCurrentTab")
    static let saveRequestNotification = Notification.Name("CRC.saveRequest")
    static let quickOpenNotification = Notification.Name("CRC.quickOpen")
    static let sendRequestNotification = Notification.Name("CRC.sendRequest")
    static let reloadRequestNotification = Notification.Name("CRC.reloadRequest")
    static let copyCurlNotification = Notification.Name("CRC.copyCurl")
    static let formatBodyNotification = Notification.Name("CRC.formatBody")
    static let diffResponsesNotification = Notification.Name("CRC.diffResponses")
}
