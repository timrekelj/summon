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
- Drag the handle on the left of a shortcut onto another row to reorder it. The order is saved and also used in the menu bar.
- Pressing a shortcut launches the app, or brings it to the front if it's already running.
- Turn on **Launch at login** in settings (works best from `/Applications`).

Hotkeys use Carbon's `RegisterEventHotKey`, so no Accessibility permission is needed. Remove the same shortcuts from Raycast, otherwise both apps will respond.
