//
//  WindowSnappingManager.swift
//  ConType
//
//  Created by Ethan John Lagera on 5/22/26.
//

import AppKit
import Combine
import SwiftUI

/// An enum representing the current snapping state of the keyboard window, which can affect how the snapping logic applies during drags and releases.
/// - `none`- No active snap, the window is free to move without any special snapping behavior.
/// - `absoluteCenter` - The window is snapped to the absolute center of the screen.
/// - `verticalTrack` - The window is snapped along a vertical track centered on the screen.
private enum KeyboardSnapState {
    case none
    case absoluteCenter
    case verticalTrack
}

/// The manager responsible for handling the snapping behavior of the keyboard and mouse overlay windows, including the logic for determining when to snap, reveal guides, and release snaps based on user interactions.
@MainActor
final class OverlaySnappingManager: ObservableObject {
    var keyboardSnapDistance: CGFloat = 72
    var mouseSnapDistance: CGFloat = 44
    
    private let settings: AppSettings
    weak var keyboardWindow: NSWindow?
    weak var mouseWindow: NSWindow?
    
    private let positionGuideModel = OverlayPositionGuideModel()
    private var positionGuideWindow: NSWindow?
    private var guideHideWorkItem: DispatchWorkItem?
    private var currentKeyboardSnapState: KeyboardSnapState = .none
    private var isMouseTrackingActive = false
    
    @Published var keyboardSnapLockOrigin: NSPoint?
    @Published var mouseSnapLockOrigin: NSPoint?
    @Published var keyboardSnapSuppressionOrigin: NSPoint?
    @Published var mouseSnapSuppressionOrigin: NSPoint?
    @Published var isApplyingProgrammaticSnap = false
    @Published var keyboardSessionHasSnap = false
    @Published var mouseSessionHasSnap = false
    @Published var dragStartMouseLocation: NSPoint = .zero
    @Published var dragStartWindowOrigin: NSPoint = .zero
    @Published var virtualWindowOrigin: NSPoint = .zero
    
    init(settings: AppSettings, keyboardWindow: NSWindow? = nil, mouseWindow: NSWindow? = nil) {
        self.settings = settings
        self.keyboardWindow = keyboardWindow
        self.mouseWindow = mouseWindow
    }
    
    /// Creates and configures the position guide window if it doesn't exist, or updates its frame if it does. This window is used to display visual guides for snapping targets when the user is dragging an overlay window.
    /// - Parameter screenFrame: The `NSRect` frame of the screen (or visible area) that the guide window should cover, used for coordinate conversion and guide rendering.
    /// - Returns: The `NSWindow` instance of the position guide window, ready to be displayed or updated.
    func makePositionGuideWindowIfNeeded(for screenFrame: NSRect) -> NSWindow {
        if let positionGuideWindow {
            if positionGuideWindow.frame != screenFrame {
                positionGuideWindow.setFrame(screenFrame, display: false)
            }
            return positionGuideWindow
        }
        
        let hostingController = NSHostingController(
            rootView: OverlayPositionGuideView(model: positionGuideModel)
        )
        let baseMask: NSWindow.StyleMask = [
            .borderless, .fullSizeContentView,
        ]
        let window = NonActivatingOverlayPanel(
            contentRect: screenFrame,
            styleMask: baseMask.union(.nonactivatingPanel),
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        
        self.positionGuideWindow = window
        return window
    }
    
    /// Refreshes the position guide based on the current position of the given window. This method calculates the appropriate snapping targets and distances, determines whether to show the guide, and handles snap locking and suppression logic for both keyboard and mouse windows.
    /// - Parameter window: The `NSWindow` that is being dragged and for which the position guide should be refreshed.
    func refreshPositionGuide(for window: NSWindow) {
        guard let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame else {
            clearPositionGuide()
            return
        }
        
        let screenRect = NSRect(origin: screenFrame.origin, size: screenFrame.size)
        positionGuideModel.screenFrame = screenRect
        
        if window == keyboardWindow {
            let windowSize = settings.keyboardWindowSize.windowDimensions()
            let targetMidX = screenRect.midX - (windowSize.width / 2)
            let targetMidY = screenRect.midY - (windowSize.height / 2)
            
            let absoluteCenterTarget = NSRect(
                x: targetMidX,
                y: targetMidY,
                width: window.frame.width,
                height: window.frame.height
            )
            
            let centerDistance = centerDistance(between: window.frame, and: absoluteCenterTarget)
            let horizontalDistance = abs(window.frame.origin.x - targetMidX)
            
            let revealDistance: CGFloat = 88
            let snapDistance: CGFloat = 24
            let releaseDistance: CGFloat = keyboardSessionHasSnap ? 156 : 96
            let suppressionDistance: CGFloat = keyboardSessionHasSnap ? 100 : 68
            
            if let snapOrigin = keyboardSnapLockOrigin {
                let movedAwayDistance = (currentKeyboardSnapState == .verticalTrack)
                ? abs(window.frame.origin.x - snapOrigin.x)
                : originDistance(between: window.frame.origin, and: snapOrigin)
                
                if movedAwayDistance < releaseDistance {
                    if currentKeyboardSnapState == .verticalTrack {
                        let distanceToAbsoluteCenter = centerDistance
                        
                        if distanceToAbsoluteCenter <= snapDistance {
                            keyboardSnapLockOrigin = nil
                        } else {
                            keyboardSnapLockOrigin = window.frame.origin
                            
                            // Keep the guide track targets active
                            let dynamicTargetFrame = NSRect(
                                x: targetMidX,
                                y: targetMidY,
                                width: window.frame.width,
                                height: window.frame.height
                            )
                            positionGuideModel.targets = [OverlayPositionGuideTarget(kind: .keyboard, frame: dynamicTargetFrame)]
                            makePositionGuideWindowIfNeeded(for: screenRect).orderFrontRegardless()
                            return
                        }
                    } else {
                        clearPositionGuide()
                        return
                    }
                } else {
                    keyboardSnapSuppressionOrigin = snapOrigin
                    keyboardSnapLockOrigin = nil
                    currentKeyboardSnapState = .none
                }
            }
            
            if let suppressionOrigin = keyboardSnapSuppressionOrigin {
                let suppressionOffset = originDistance(between: window.frame.origin, and: suppressionOrigin)
                if suppressionOffset < suppressionDistance {
                    clearPositionGuide()
                    return
                }
                keyboardSnapSuppressionOrigin = nil
            }
            
            if centerDistance <= snapDistance {
                currentKeyboardSnapState = .absoluteCenter
                snapKeyboardWindow(to: absoluteCenterTarget.origin)
                clearPositionGuide()
                return
            }
            
            if horizontalDistance <= snapDistance {
                currentKeyboardSnapState = .verticalTrack
                let snappedOrigin = NSPoint(x: targetMidX, y: window.frame.origin.y)
                snapKeyboardWindow(to: snappedOrigin)
                clearPositionGuide()
                return
            }
            
            // Guide Display Manager
            if horizontalDistance <= revealDistance && horizontalDistance > 1 {
                let guideY = targetMidY
                
                let dynamicTargetFrame = NSRect(
                    x: targetMidX,
                    y: guideY,
                    width: window.frame.width,
                    height: window.frame.height
                )
                
                positionGuideModel.targets = [OverlayPositionGuideTarget(kind: .keyboard, frame: dynamicTargetFrame)]
                makePositionGuideWindowIfNeeded(for: screenRect).orderFrontRegardless()
            } else {
                clearPositionGuide()
            }
        } else if window == mouseWindow {
            let targets = mouseGuideTargets(for: window.frame.size, screenFrame: screenRect)
            guard let nearestTarget = targets.min(by: {
                originDistance(between: window.frame.origin, and: $0.frame.origin) < originDistance(between: window.frame.origin, and: $1.frame.origin)
            }) else {
                clearPositionGuide()
                return
            }
            
            let distance = originDistance(between: window.frame.origin, and: nearestTarget.frame.origin)
            let revealDistance: CGFloat = 52
            let snapDistance: CGFloat = 18
            let releaseDistance: CGFloat = mouseSessionHasSnap ? 108 : 64
            let suppressionDistance: CGFloat = mouseSessionHasSnap ? 72 : 44
            
            if let snapOrigin = mouseSnapLockOrigin {
                let movedAwayDistance = originDistance(between: window.frame.origin, and: snapOrigin)
                if movedAwayDistance < releaseDistance {
                    clearPositionGuide()
                    return
                }
                mouseSnapSuppressionOrigin = snapOrigin
                mouseSnapLockOrigin = nil
            }
            
            if let suppressionOrigin = mouseSnapSuppressionOrigin {
                let suppressionOffset = originDistance(between: window.frame.origin, and: suppressionOrigin)
                if suppressionOffset < suppressionDistance {
                    clearPositionGuide()
                    return
                }
                mouseSnapSuppressionOrigin = nil
            }
            
            if distance <= snapDistance {
                snapMouseWindow(to: nearestTarget.frame.origin)
                clearPositionGuide()
                return
            }
            
            if distance <= revealDistance && distance > 1 {
                positionGuideModel.targets = [nearestTarget]
                makePositionGuideWindowIfNeeded(for: screenRect).orderFrontRegardless()
            } else {
                clearPositionGuide()
            }
        } else {
            clearPositionGuide()
        }
    }
    
    /// Hides the position guide window and clears any active snapping targets or suppression states.
    func clearPositionGuide() {
        guard !isMouseTrackingActive else { return }
        
        guideHideWorkItem?.cancel()
        guideHideWorkItem = nil
        positionGuideWindow?.orderOut(nil)
        positionGuideModel.clear()
    }
    
    /// Programmatically snaps the keyboard window to the specified origin point, updating the relevant state properties to reflect the new snap lock and suppression conditions.
    /// - Parameter origin: The `NSPoint` to which the keyboard window should be snapped.
    func snapKeyboardWindow(to origin: NSPoint) {
        guard let keyboardWindow, keyboardWindow.frame.origin != origin else { return }
        isApplyingProgrammaticSnap = true
        keyboardWindow.setFrameOrigin(origin)
        isApplyingProgrammaticSnap = false
        keyboardSnapLockOrigin = origin
        keyboardSnapSuppressionOrigin = nil
        keyboardSessionHasSnap = true
        settings.keyboardWindowPosition = origin
    }
    
    /// Programmatically snaps the mouse window to the specified origin point, updating the relevant state properties to reflect the new snap lock and suppression conditions.
    /// - Parameter origin: The `NSPoint` to which the mouse window should be snapped.
    func snapMouseWindow(to origin: NSPoint) {
        guard let mouseWindow, mouseWindow.frame.origin != origin else { return }
        isApplyingProgrammaticSnap = true
        mouseWindow.setFrameOrigin(origin)
        isApplyingProgrammaticSnap = false
        mouseSnapLockOrigin = origin
        mouseSnapSuppressionOrigin = nil
        mouseSessionHasSnap = true
        settings.mouseWindowPosition = origin
    }
    
    /// Calculates the target frame for the keyboard window guide based on the current frame of the window and the screen frame.
    /// - Parameters:
    ///   - currentFrame: The current `NSRect` frame of the keyboard window, used to determine the size of the guide and its relation to the snap targets.
    ///   - screenFrame: The `NSRect` frame of the screen (or visible area) that the guide should consider for positioning, used to calculate the center point for the guide.
    /// - Returns: An `NSRect` representing the target frame for the keyboard guide, centered on the screen with the same size as the current window frame.
    func keyboardGuideTargetFrame(for currentFrame: NSRect, screenFrame: NSRect) -> NSRect {
        NSRect(
            x: screenFrame.midX - (currentFrame.width / 2),
            y: screenFrame.midY - (currentFrame.height / 2),
            width: currentFrame.width,
            height: currentFrame.height
        )
    }
    
    /// Calculates potential guide targets for the mouse window based on the given window size and screen frame. The method generates target frames for snapping to the four corners of the screen, applying an inset to avoid edge collisions, and returns them as an array of `OverlayPositionGuideTarget` instances.
    /// - Parameters:
    ///   - windowSize: The `NSSize` of the mouse window, used to determine the size of the guide targets and ensure they match the window dimensions for accurate snapping feedback.
    ///   - screenFrame: The `NSRect` frame of the screen (or visible area) that the guide should consider for positioning, used to calculate the positions of the corner targets while applying an inset to keep them within visible bounds.
    /// - Returns: An array of `OverlayPositionGuideTarget` representing the potential snap targets for the mouse window at the corners of the screen, each with a frame sized to match the window size and positioned with an inset from the edges.
    func mouseGuideTargets(for windowSize: NSSize, screenFrame: NSRect) -> [OverlayPositionGuideTarget] {
        let inset: CGFloat = 16
        let width = windowSize.width
        let height = windowSize.height
        
        let bottomLeft = NSRect(
            x: screenFrame.minX + inset,
            y: screenFrame.minY + inset,
            width: width,
            height: height
        )
        let bottomRight = NSRect(
            x: max(screenFrame.minX + inset, screenFrame.maxX - inset - width),
            y: screenFrame.minY + inset,
            width: width,
            height: height
        )
        let topLeft = NSRect(
            x: screenFrame.minX + inset,
            y: max(screenFrame.minY + inset, screenFrame.maxY - inset - height),
            width: width,
            height: height
        )
        let topRight = NSRect(
            x: max(screenFrame.minX + inset, screenFrame.maxX - inset - width),
            y: max(screenFrame.minY + inset, screenFrame.maxY - inset - height),
            width: width,
            height: height
        )
        
        return [
            OverlayPositionGuideTarget(kind: .mouse, frame: bottomLeft),
            OverlayPositionGuideTarget(kind: .mouse, frame: bottomRight),
            OverlayPositionGuideTarget(kind: .mouse, frame: topLeft),
            OverlayPositionGuideTarget(kind: .mouse, frame: topRight)
        ]
    }
    
    /// Calculates the distance between the centers of two rectangles.
    /// - Parameters:
    ///   - first: The first `NSRect` whose center will be used for distance calculation.
    ///   - second: The second `NSRect` whose center will be used for distance calculation.
    /// - Returns: A `CGFloat` representing the distance between the centers of the two rectangles.
    func centerDistance(between first: NSRect, and second: NSRect) -> CGFloat {
        hypot(first.midX - second.midX, first.midY - second.midY)
    }
    
    /// Calculates the distance between two points.
    /// - Parameters:
    ///   - first: The first `NSPoint` used for distance calculation.
    ///   - second: The second `NSPoint` used for distance calculation.
    /// - Returns: A `CGFloat` representing the distance between the two points.
    func originDistance(between first: NSPoint, and second: NSPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
    
    /// Handles the dragging of a window by updating the virtual window origin based on the current mouse location and applying snapping logic according to the defined thresholds and states. This method manages the entire lifecycle of a drag operation, including starting the drag, updating the window position during the drag, and finalizing the position when the drag ends, while also refreshing the position guide as needed.
    /// - Parameters:
    ///   - phase: The `DragPhase` indicating the current phase of the drag operation (began, changed, ended)
    ///   - window: The `NSWindow` that is being dragged
    func handleWindowDrag(phase: DragPhase, window: NSWindow) {
        let currentGlobalMouse = NSEvent.mouseLocation
        
        switch phase {
        case .began:
            isMouseTrackingActive = true
            dragStartMouseLocation = currentGlobalMouse
            dragStartWindowOrigin = window.frame.origin
            virtualWindowOrigin = window.frame.origin
            
            guideHideWorkItem?.cancel()
            guideHideWorkItem = nil
            
        case .changed:
            isMouseTrackingActive = true
            guideHideWorkItem?.cancel()
            guideHideWorkItem = nil
            
            let deltaX = currentGlobalMouse.x - dragStartMouseLocation.x
            let deltaY = currentGlobalMouse.y - dragStartMouseLocation.y
            virtualWindowOrigin = NSPoint(
                x: dragStartWindowOrigin.x + deltaX,
                y: dragStartWindowOrigin.y + deltaY
            )
            
            let isKeyboard = (window === keyboardWindow)
            let isSnapped = isKeyboard ? keyboardSessionHasSnap : mouseSessionHasSnap
            let snapOrigin = isKeyboard ? keyboardSnapLockOrigin : mouseSnapLockOrigin
            
            if isSnapped, let snapPoint = snapOrigin {
                if isKeyboard {
                    switch currentKeyboardSnapState {
                    case .absoluteCenter:
                        // Rule 1: Default position - uniform breakout difficulty across both axes
                        let pullDistance = originDistance(between: virtualWindowOrigin, and: snapPoint)
                        if pullDistance > keyboardSnapDistance {
                            keyboardSessionHasSnap = false
                            keyboardSnapLockOrigin = nil
                            currentKeyboardSnapState = .none
                            window.setFrameOrigin(virtualWindowOrigin)
                            refreshPositionGuide(for: window)
                        } else {
                            // Lock rigidly in place while within threshold
                            window.setFrameOrigin(snapPoint)
                        }
                        
                    case .verticalTrack:
                        // Rule 2: Free vertical glide. Only check horizontal strain for breakouts.
                        let horizontalPull = abs(virtualWindowOrigin.x - snapPoint.x)
                        
                        // Lower the threshold slightly for a smoother lateral slide-off effect (e.g., 70% of default difficulty)
                        let reducedThreshold = keyboardSnapDistance * 0.70
                        
                        if horizontalPull > reducedThreshold {
                            keyboardSessionHasSnap = false
                            keyboardSnapLockOrigin = nil
                            currentKeyboardSnapState = .none
                            window.setFrameOrigin(virtualWindowOrigin)
                            refreshPositionGuide(for: window)
                        } else {
                            // Update window tracking smoothly down the X track, allowing completely free Y transit
                            window.setFrameOrigin(NSPoint(x: snapPoint.x, y: virtualWindowOrigin.y))
                            refreshPositionGuide(for: window)
                        }
                        
                    case .none:
                        window.setFrameOrigin(virtualWindowOrigin)
                        refreshPositionGuide(for: window)
                    }
                } else {
                    // Standard Mouse Window Snapping logic
                    let pullDistance = originDistance(between: virtualWindowOrigin, and: snapPoint)
                    if pullDistance > mouseSnapDistance {
                        mouseSessionHasSnap = false
                        mouseSnapLockOrigin = nil
                        window.setFrameOrigin(virtualWindowOrigin)
                        refreshPositionGuide(for: window)
                    }
                }
            } else {
                window.setFrameOrigin(virtualWindowOrigin)
                refreshPositionGuide(for: window)
            }
            
        case .ended:
            isMouseTrackingActive = false
            clearPositionGuide()
        }
    }
}
