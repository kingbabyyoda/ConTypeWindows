//
//  AppDelegate.swift
//  ConType
//
//  Created by GitHub Copilot on 5/25/26.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkForDuplicateInstanceIfNeeded()
    }
    
    private func checkForDuplicateInstanceIfNeeded() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != NSRunningApplication.current.processIdentifier }
        
        guard !otherInstances.isEmpty else { return }
        
        NSApp.activate(ignoringOtherApps: true)
        let shouldCloseOtherInstance = presentDuplicateInstanceAlert()
        guard shouldCloseOtherInstance else {
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return
        }
        
        otherInstances.forEach { _ = $0.terminate() }
    }
    
    private func presentDuplicateInstanceAlert() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Another instance of ConType is already running."
        alert.informativeText = "Would you like to close the old instance and continue, or cancel this launch?"
        alert.addButton(withTitle: "Close Other Instance")
        alert.addButton(withTitle: "Cancel")
        
        return alert.runModal() == .alertFirstButtonReturn
    }
}
