//
//  KeyboardHotkeyManager.swift
//  ConType
//
//  Created by Ethan John Lagera on 4/14/26.
//

import AppKit
import ApplicationServices

/// A struct that represents a keyboard shortcut consisting of a key and its associated modifier flags.
struct Shortcut: Equatable {
    let key: String
    let modifiers: NSEvent.ModifierFlags
    
    var displayText: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.command) { parts.append("Command") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        
        switch key {
        case " ": parts.append("Space")
        case "\r": parts.append("Return")
        default: parts.append(key.uppercased())
        }
        return parts.joined(separator: " + ")
    }
}

/// `KeyboardHotkeyManager` is responsible for monitoring global keyboard events to trigger a specified action.
/// - Note: To function correctly, the host application must have the necessary Accessibility permissions
///   granted by the system.
final class KeyboardHotkeyManager {
    /// Closure that gets called when the configured shortcut is activated.
    var onToggle: (() -> Void)?
    var shortcut: Shortcut?

    /// Internal state for managing the event tap and run loop source.
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    deinit {
        stop()
    }
    
    /// Starts monitoring for the configured shortcut.
    /// This method sets up a `CGEventTap` and registers it with the current `CFRunLoop`.
    /// If the event tap fails to create (e.g., due to missing permissions), it will log a warning and stop.
    func start() {
        stop()

        if installEventTap() {
            return
        }
        
        debugPrint("[KeyboardHotkeyManager] Failed to create event tap for keyboard hotkey. Stopping hotkey monitoring.")
        stop()
    }

    /// Stops monitoring for the shortcut and releases system resources.
    /// This removes the event tap from the `CFRunLoop` and disables it.
    func stop() {

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }
    
    /// Checks if a given `NSEvent` matches the configured shortcut for toggling.
    /// - Parameter event: The keyboard event to check against the configured shortcut.
    /// - Returns: A boolean indicating whether the event matches the shortcut.
    private func matchesToggleShortcut(_ event: NSEvent) -> Bool {
        guard let shortcut else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == shortcut.modifiers else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == shortcut.key
    }

    /// Parses an `NSEvent` to construct a `Shortcut` instance if possible.
    /// - Parameter event: The `NSEvent` to extract shortcut information from.
    /// - Returns: A `Shortcut` object if the event contains valid key and modifier information, otherwise `nil`.
    static func shortcut(from event: NSEvent) -> Shortcut? {
        guard let rawKey = event.charactersIgnoringModifiers?.lowercased(), !rawKey.isEmpty else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let mappedKey: String

        switch event.keyCode {
        case 49:
            mappedKey = " "
        case 36, 76:
            mappedKey = "\r"
        default:
            mappedKey = String(rawKey.prefix(1))
        }

        return Shortcut(key: mappedKey, modifiers: flags)
    }
    
    /// Installs a global event tap to monitor for keyboard events.
    /// - Returns: A boolean indicating whether the event tap was successfully created and installed.
    private func installEventTap() -> Bool {
        // Requires Accessibility to modify/swallow events; otherwise tap creation fails.
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: KeyboardHotkeyManager.eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }
    
    /// The callback function for the event tap, which processes incoming keyboard events.
    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, cgEvent, refcon in
        // Pass through non-key events
        guard type == .keyDown else {
            return Unmanaged.passUnretained(cgEvent)
        }

        guard let refcon = refcon else {
            return Unmanaged.passUnretained(cgEvent)
        }

        let manager = Unmanaged<KeyboardHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

        /// Convert to NSEvent to reuse existing shortcut matching logic
        guard let nsEvent = NSEvent(cgEvent: cgEvent) else {
            return Unmanaged.passUnretained(cgEvent)
        }

        if manager.matchesToggleShortcut(nsEvent) {
            /// Toggle on the main thread and swallow the event so the front app doesn't also handle it
            DispatchQueue.main.async {
                manager.onToggle?()
            }
            return nil
        }

        return Unmanaged.passUnretained(cgEvent)
    }
}
