//
//  TutorialView.swift
//  ConType
//
//  Created by Ethan John Lagera on 5/27/26.
//

import SwiftUI

struct TutorialView: View {
    let settings: AppSettings
    
    @State var currentPage: Int = 0
    
    init(settings: AppSettings) {
        self.settings = settings
    }
    
    var body: some View {
        ZStack {
            Image("Wallpaper")
                .resizable()
                .antialiased(true)
                .interpolation(.high)
                .scaledToFill()
            
            Group {
                switch currentPage {
                case 0:
                    VStack {
                        Text("Welcome to ConType!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .shadow(radius: 10)
                        
                        Button("Continue") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }
                        .roundGlassProminent()
                    }
                    .transition(.opacity)
                    
                    
                case 1:
                    VStack {
                        Text("Before we begin the tutorial, would you like to look over the settings?")
                            .font(.title2)
                            .foregroundStyle(.white)
                        
                        Button("Open Settings") {
                            // Open Settings
                        }
                        .roundGlassProminent()
                        
                        Button("Continue") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }
                        .roundGlassProminent()
                    }
                    .transition(.opacity)
                    
                case 2:
                    VStack {
                        Text("Let's try opening the keyboard.")
                            .font(.title2)
                            .foregroundStyle(.white)
                        
                        Text("Pick up your controller and press the following buttons.")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        keyboardShortcut()
                            .padding(4)
                            .background(
                                .ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        
                        Text("You can change this in the settings")
                            .font(.footnote)
                            .foregroundStyle(.white)
                    }
                    .transition(.opacity)
                    
                    // Move in the Keyboard
                    
                    // Try typing "Hello World!" (Show shift shortcut)
                    
                    // Open the mouse (Listen for mouse shortcut)
                    
                    // Move the mouse
                    
                default:
                    // Press (Guide Button) or (Shortcut) to end tutorial
                    
                    VStack {
                        Text("This is the end of the tutorial. Enjoy using ConType!")
                            .font(.title2)
                            .foregroundStyle(.white)
                        
                        Button("Close") {
                            // Close window
                        }
                        .roundGlassProminent()
                    }
                    .transition(.opacity)
                }
            }
        }
    }
    
    func genericGuideGlyph(size: CGFloat = 20) -> some View {
        ControllerGlyphBadge(
            assetName: "gamecontroller.circle.fill",
            fallbackText: "Guide",
            size: size
        )
    }
    
    private func buttonGlyph(_ button: ControllerAssignableButton, size: CGFloat = 20) -> some View {
        ControllerGlyphBadge(
            assetName: button.glyphAssetName(for: settings.controllerGlyphStyle),
            fallbackText: button.fallbackGlyphText,
            size: size
        )
    }
    
    func keyboardShortcut() -> some View {
        let selectedButton = settings.controllerToggleBindings.binding(for: .keyboardToggle)
        
        return HStack(spacing: 8) {
            genericGuideGlyph(size: 32)
            Text("+")
            buttonGlyph(selectedButton, size: 32)
                .colorInvert()
            Text(selectedButton.displayTitle(for: settings.controllerGlyphStyle))
                .font(.system(.body, design: .monospaced))
        }
        .foregroundStyle(.white)
        .frame(width: 220, alignment: .center)
        .frame(minHeight: 44)
    }
}

struct RoundGlassProminent: ViewModifier {
    let padding: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, padding)
            .padding(.vertical, padding / 2)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(
                .regular
                .interactive()
                .tint(.accentColor),
                in: Capsule()
            )
    }
}

extension View {
    func roundGlassProminent(padding: CGFloat = 16) -> some View {
        self.modifier(RoundGlassProminent(padding: padding))
    }
}

#Preview {
    TutorialView(settings: AppSettings())
}
