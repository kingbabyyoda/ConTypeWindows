//
//  AccessibilityPermission.swift
//  ConType
//
//  Created by Ethan John Lagera on 4/8/26.
//
//  Code referenced from Hold To Talk
//  https://github.com/jxucoder/hold-to-talk/tree/main

import CoreGraphics
import Foundation

/// Enum for managing Input Monitoring (TCC) permissions on macOS.
/// Uses CoreGraphics APIs to check and request permission.
public enum InputMonitoringPermission {
    /// Test seam that can replace the real authorization check when needed.
    public static var isAuthorizedProvider: @MainActor () -> Bool = {
        return CGPreflightPostEventAccess() || CGPreflightListenEventAccess()
    }
    
    /// Test seam that can replace the real authorization request when needed.
    public static var requestAuthorizationProvider: @MainActor () -> Bool = {
        return CGRequestPostEventAccess()
    }
    
    /// Checks if the app is authorized for Input Monitoring.
    /// - Returns: true if authorized, false otherwise.
    @MainActor
    public static func isAuthorized() -> Bool {
        isAuthorizedProvider()
    }
    
    /// Requests Input Monitoring permission from the user.
    /// Doesn't guarantee to return true immediately after permission is granted. May require app restart.
    /// - Returns: `true` if access is granted, `false` otherwise.
    @MainActor
    public static func requestAuthorization() -> Bool {
        requestAuthorizationProvider()
    }
}
