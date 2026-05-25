//
//  OnboardingWindowController.swift
//  ConType
//
//  Created by Ethan John Lagera on 4/14/26.
//

import AppKit
import SwiftUI

/// The controller for the onboarding window
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    var onCompletion: (() -> Void)?
    var openSettings: (() -> Void)?
    var onAccessibilityTrustChanged: ((Bool) -> Void)? {
        didSet {
            viewModel.onAccessibilityTrustChanged = onAccessibilityTrustChanged
        }
    }

    private let settings: AppSettings
    private let viewModel: OnboardingViewModel
    private var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
        self.viewModel = OnboardingViewModel(settings: settings)
        super.init()

        viewModel.onComplete = { [weak self] in
            self?.onCompletion?()
            self?.close()
        }
        
        viewModel.openSettings = { [weak self] in
            self?.onCompletion?()
            self?.openSettings?()
            self?.close()
        }
    }

    var isVisible: Bool {
        window?.isVisible == true
    }
    
    /// Show the onboarding view, prepare the window, initialize with the view model and make it appear front and center.
    /// - Parameter startAtWelcome: Wether to explicitly start the onboarding view at the beginning.
    func show(startAtWelcome: Bool) {
        let window = makeWindowIfNeeded()
        viewModel.prepareForPresentation(startAtWelcome: startAtWelcome)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    /// Calls the window to close.
    func close() {
        window?.performClose(nil)
    }
    
    /// Calls the view model to handle when the overlay shortcut is called.
    func handleShortcutActivation() {
        viewModel.handleShortcutActivation()
    }
    
    /// Handles window closure
    /// - Parameter notification: The `Notification` from the window closure
    func windowWillClose(_ notification: Notification) {
        viewModel.stop()
        onClose?()
    }
    
    /// Returns the window if existing, else it creates a window with specific parameters for the onboarding window
    /// - Returns: An `NSWindow` containing the onboarding view
    private func makeWindowIfNeeded() -> NSWindow {
        if let window {
            return window
        }

        let hostingController = NSHostingController(
            rootView: OnboardingView(settings: settings, viewModel: viewModel)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.title = "Welcome to ConType"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 360, height: 400)
        window.maxSize = NSSize(width: 540, height: 600)

        self.window = window
        return window
    }
}
