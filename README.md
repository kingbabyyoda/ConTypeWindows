# ConTypeWindows

This repository now includes a **Windows 11 port** of the ConType concept built with **Avalonia UI** and **C#**.

## What changed

The original source in this repo was a macOS SwiftUI app. The new Windows implementation lives under:

- `ConTypeAvalonia.sln`
- `ConTypeAvalonia/src/ConType.Core`
- `ConTypeAvalonia/src/ConType.App`

## Windows port goals

- Controller-driven virtual keyboard overlay
- Mouse emulation from controller input
- Configurable controller bindings
- Saved settings in `%LocalAppData%`
- A native-feeling Windows 11 desktop app with Avalonia UI

## Build target

- `.NET 8`
- `Avalonia UI`
- `Windows.Gaming.Input` for controller polling
- Win32 `SendInput` for keyboard and mouse injection

## Notes

The macOS Swift source remains in the repository for reference, but the Windows port is the active implementation path.

## Credits

- The original ConType concept and layout inspiration came from the macOS version in this repository.
- The Windows port is designed as a fresh C# implementation rather than a direct Swift port.
