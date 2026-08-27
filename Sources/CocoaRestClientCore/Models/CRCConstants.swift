//
//  CRCConstants.swift
//  CocoaRestClientCore
//

import Foundation

public enum CRCConstants {
    public static let applicationName = "CocoaRestClient"
    public static let dataFileName = "CocoaRestClient.savedRequests.json"
    public static let legacyDataFileName = "CocoaRestClient.savedRequests"
    public static let backupDataFile138 = "CocoaRestClient.savedRequests.backup-1.3.8"
    
    // UserDefaults Keys
    public static let followRedirects = "followRedirects"
    public static let applyHttpMethodOnRedirect = "applyHttpMethodOnRedirect"
    public static let syntaxHighlight = "UIMenuSyntaxHighlight"
    public static let rawRequestBody = "UIRawRequestBody"
    public static let responseTimeout = "responseTimeout"
    public static let savedDrawerSize = "savedDrawerSize"
    public static let theme = "theme"
    public static let darkTheme = "darkTheme"
    public static let defaultFontSize: CGFloat = 12.0
    public static let showLineNumbers = "showLineNumbers"
    public static let disableAnimations = "UIDisableAnimations"
    public static let disableCookies = "disableCookies"
    public static let fileRequestBody = "UIFileRequestBody"
    public static let allowSelfSignedCerts = "allowSelfSignedCerts"
    public static let savedRequestsViewWidth = "savedRequestsViewWidth"
    public static let defaultContentType = "defaultContentType"
    public static let defaultTimeoutSeconds = 30
    
    public static let defaultMethods = [
        "GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH", "COPY", "SEARCH"
    ]
}
