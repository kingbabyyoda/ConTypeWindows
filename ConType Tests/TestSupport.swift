import Foundation
@testable import ConType

@MainActor
enum TestSupport {
    static func withTemporarySettingsURL<T>(
        operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConTypeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let settingsURL = directory.appendingPathComponent("settings.json")
        let previousURL = AppSettings.settingsURLOverride
        AppSettings.settingsURLOverride = settingsURL
        
        defer {
            AppSettings.settingsURLOverride = previousURL
            try? FileManager.default.removeItem(at: directory)
        }
        
        return try await operation()
    }
    
    static func withPermissionProviders<T>(
        isAuthorized: @escaping @MainActor () -> Bool,
        requestAuthorization: @escaping @MainActor () -> Bool,
        operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        let previousIsAuthorized = InputMonitoringPermission.isAuthorizedProvider
        let previousRequestAuthorization = InputMonitoringPermission.requestAuthorizationProvider
        
        InputMonitoringPermission.isAuthorizedProvider = isAuthorized
        InputMonitoringPermission.requestAuthorizationProvider = requestAuthorization
        
        defer {
            InputMonitoringPermission.isAuthorizedProvider = previousIsAuthorized
            InputMonitoringPermission.requestAuthorizationProvider = previousRequestAuthorization
        }
        
        return try await operation()
    }
    
    static func drainMainQueue() async {
        await Task.yield()
        await Task.yield()
    }
}
