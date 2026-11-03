# Summon

A tiny menu bar app that launches or focuses apps with global keyboard shortcuts (e.g. ⌃⌘1 → Ghostty). Replaces Raycast's app hotkeys.

## Build

```sh
./build.sh           # builds build/Summon.app
./build.sh install   # also copies it to /Applications and launches it
```

Requires macOS 26+ and Xcode / the Swift 6.2+ toolchain.

## Usage

- Open settings from the ⌘ icon in the menu bar.
- Add apps with **+**, then click the shortcut button and press a key combination. Esc cancels, Delete clears.
- Drag an app's icon or name to reorder it. The order is saved and also used in the menu bar.
- Pressing a shortcut launches the app, or brings it to the front if it's already running. With **Press again to hide** on, pressing it while the app is in front hides the app.
- Settings: **Launch at login** (works best from `/Applications`), **Show in Dock**, **Show menu bar icon** and **Press again to hide**.
- ⌘W and ⌘Q both just close the settings window; Summon keeps running. Quit from the menu bar icon or the Dock. If you've hidden the menu bar icon, open Summon again (Dock, Finder or Spotlight) to get back to settings.

Hotkeys use Carbon's `RegisterEventHotKey`, so no Accessibility permission is needed. Remove the same shortcuts from Raycast, otherwise both apps will respond.
