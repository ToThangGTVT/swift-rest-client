//
//  PreferencesViewModel.swift
//  CocoaRestClientApp
//

import Foundation
import SwiftUI
import CocoaRestClientCore

public final class PreferencesViewModel: ObservableObject {
    public static let shared = PreferencesViewModel()

    @AppStorage(CRCConstants.responseTimeout) public var timeoutSeconds: Int = CRCConstants.defaultTimeoutSeconds
    @AppStorage(CRCConstants.followRedirects) public var followRedirects: Bool = true
    @AppStorage(CRCConstants.applyHttpMethodOnRedirect) public var applyHttpMethodOnRedirect: Bool = false
    @AppStorage(CRCConstants.allowSelfSignedCerts) public var allowSelfSignedCerts: Bool = true
    @AppStorage(CRCConstants.disableCookies) public var disableCookies: Bool = true
    @AppStorage(CRCConstants.defaultContentType) public var defaultContentType: String = "application/json"
    @AppStorage(CRCConstants.showLineNumbers) public var showLineNumbers: Bool = true
    @AppStorage(CRCConstants.syntaxHighlight) public var syntaxHighlight: Bool = true

    public init() {}

    public var networkOptions: NetworkOptions {
        NetworkOptions(
            timeoutSeconds: TimeInterval(timeoutSeconds),
            followRedirects: followRedirects,
            applyHttpMethodOnRedirect: applyHttpMethodOnRedirect,
            allowSelfSignedCerts: allowSelfSignedCerts,
            disableCookies: disableCookies
        )
    }
}
