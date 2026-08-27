//
//  CocoaRestClientApp.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

@main
struct CocoaRestClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 880, minHeight: 620)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1080, height: 720)
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

                Divider()

                Button("Import from cURL...") {
                    NotificationCenter.default.post(name: .importCurlNotification, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
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

                Button("Generate Code Snippets...") {
                    NotificationCenter.default.post(name: .codeGeneratorNotification, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

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

                Divider()

                Button("Manage Environments...") {
                    NotificationCenter.default.post(name: .environmentManagerNotification, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
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
    static let importCurlNotification = Notification.Name("CRC.importCurl")
    static let codeGeneratorNotification = Notification.Name("CRC.codeGenerator")
    static let environmentManagerNotification = Notification.Name("CRC.environmentManager")
}
