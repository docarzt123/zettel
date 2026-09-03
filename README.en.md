# Zettel

*[Deutsche Version: README.md](README.md)*

A text field in your menu bar. Nothing more.

Click the icon next to the clock, a text field opens, you type or paste
something, click somewhere else, and it is gone. The text is kept and lives
in a plain text file at `~/Documents/Zettel.txt`. Meant as a scratch pad for
snippets, links, half thoughts, anything you want to park for a moment
without opening an editor. "Zettel" is German for a slip of paper.

## Installation

**Prebuilt app:** Download the latest `Zettel.dmg` from
[Releases](https://github.com/docarzt123/zettel/releases), open it, drag
`Zettel` into `Applications`, launch it. The app is signed with a Developer
ID and notarized by Apple, so macOS opens it without complaint.

**On first launch** macOS asks whether Zettel may access your "Documents"
folder. Allow it, that is where the text file lives.

**From source:** Install Xcode or the Command Line Tools, then

```bash
./build.sh
```

This builds `dist/Zettel.app` (Apple Silicon and Intel), signs it with the
Developer ID certificate in your keychain if there is one, otherwise ad hoc,
copies it to `/Applications` and launches it. `./build.sh --no-install`
only builds.

Requires macOS 13 (Ventura) or newer.

## Usage

| Action | How |
|---|---|
| Open and close | Click the menu bar icon or press `⌃⌥Y` (Control + Option + Y) from anywhere |
| Close | Click anywhere else, press `Esc`, or press `⌃⌥Y` again |
| Pin | Pin icon at the bottom left. The field becomes a small window floating above all other apps, including full-screen ones. Click again to unpin. |
| Resize | Drag the edge. The size is remembered, both for the popover and the pinned window. |
| Clear | "Clear" at the bottom right deletes everything. `⌘Z` brings the text back. |
| Save a copy | "Save As…" at the bottom right. The text stays in Zettel, the copy is a separate file. |
| Right-click the icon | Open Zettel · Show File in Finder · Launch at Login · About Zettel · Quit |

The usual shortcuts work inside the field: `⌘A`, `⌘C`, `⌘V`, `⌘X`, `⌘Z`,
`⌘⇧Z` and `⌘F` for find.

**Saving** happens by itself, about a third of a second after the last
keystroke, and again on close and quit. There is no save button because
there is nothing to decide.

**The file** `~/Documents/Zettel.txt` is plain UTF-8 text. You can open and
edit it with any other program. Zettel notices and reloads the new content
as soon as you are not typing in it yourself.

## Architecture

Native Swift app using AppKit, no Xcode project, no dependencies.
`build.sh` calls `swiftc` directly.

| File | Purpose |
|---|---|
| `Sources/main.swift` | Starts the app as a menu bar program without a Dock icon |
| `Sources/AppDelegate.swift` | Menu bar icon, popover, pinned window, context menu, hotkey, launch at login, About dialog |
| `Sources/ZettelViewController.swift` | The text field with pin button and "Save As", size memory, applying external changes |
| `Sources/NoteStore.swift` | Reading and debounced atomic writing of the text file, watching the file and its folder |
| `Sources/HotKey.swift` | Global hotkey via the Carbon hotkey API (needs no Accessibility permission) |
| `Sources/L10n.swift` | Shorthand for localized strings |
| `Resources/de.lproj`, `Resources/en.lproj` | UI strings in German and English, macOS picks by system language |
| `Resources/Info.plist` | Bundle description, `__VERSION__` is replaced from `VERSION` at build time |
| `scripts/make_icon.swift` | Renders the app icon during the build |
| `scripts/macos_sign.sh`, `scripts/build_dmg.sh`, `scripts/macos_notarize.sh` | Signing, DMG packaging, notarization |
| `.github/workflows/build.yml` | CI: compile on every push; on a `vX.Y.Z` tag sign, notarize and attach the DMG to the release |

Settings (size, pinned state, window position) live in the UserDefaults of
`com.reisezoom.zettel`.

## Release

1. Bump `VERSION`, update `CHANGELOG.md`.
2. Run `./build.sh` and test briefly.
3. Tag and push:
   ```bash
   git tag v1.0.0 && git push origin main v1.0.0
   ```
4. GitHub Actions builds, signs, notarizes and publishes the DMG.

The repository needs these secrets (Settings → Secrets and variables →
Actions): `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD` for the Developer ID
certificate, `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` for
notarization. Without them CI still builds, just unsigned.

## Status for future work

Version 1.0.0, everything from the plan is implemented, nothing is open.
When changing things: update `CHANGELOG.md` and both READMEs, then
`./build.sh` to test. UI strings exist in both languages, new strings go
into both `Localizable.strings` files.

## License

MIT, see `LICENSE`.
