# Changelog

Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionen nach [SemVer](https://semver.org/lang/de/).
Deutsch zuerst, English below each entry.

## [Unreleased]

## [1.0.0] – 2026-09-02

### Hinzugefügt / Added
- Menüleisten-Symbol mit Popover-Textfeld, Systemschrift 14 pt, folgt Hell-
  und Dunkelmodus.
  Menu bar icon with a popover text field, system font 14 pt, follows light
  and dark mode.
- Automatisches Speichern nach `~/Documents/Zettel.txt`, atomar, kurz nach
  dem letzten Tastendruck sowie beim Schließen und Beenden.
  Automatic saving to `~/Documents/Zettel.txt`, atomic, shortly after the
  last keystroke and on close and quit.
- Nachladen, wenn die Datei von einem anderen Programm geändert wurde.
  Reload when another program changes the file.
- Pin-Knopf: Popover wird zu einem schwebenden Fenster über allen Apps,
  Zustand bleibt über Neustarts erhalten.
  Pin button: popover becomes a floating window above all apps, state
  survives restarts.
- Beim Anpinnen bleibt das Fenster an der Stelle des Popovers und lässt sich
  an jeder freien Fläche packen und verschieben.
  When pinning, the window stays where the popover was and can be dragged
  by any empty area.
- Globales Tastenkürzel `⌃⌥Y` zum Öffnen und Schließen, `Esc` schließt.
  Die Y-Taste wird aus dem aktiven Tastaturlayout ermittelt (deutsch wie US).
  Global hotkey `⌃⌥Y` to open and close, `Esc` closes. The Y key is
  resolved from the active keyboard layout (German and US alike).
- Größe per Ziehen änderbar und gemerkt.
  Resizable by dragging, size remembered.
- „Speichern unter …" exportiert eine Kopie als Textdatei.
  "Save As…" exports a copy as a text file.
- „Leeren" löscht den ganzen Text, ⌘Z holt ihn zurück.
  "Clear" deletes all text, ⌘Z brings it back.
- Rechtsklick-Menü: Öffnen, Datei im Finder zeigen, Bei Login starten,
  Über Zettel, Beenden.
  Context menu: Open, Show File in Finder, Launch at Login, About, Quit.
- Oberfläche auf Deutsch und Englisch.
  UI in German and English.
- Universal-Build (Apple Silicon und Intel), Developer-ID-Signatur,
  Notarisierung und DMG-Release über GitHub Actions.
  Universal build (Apple Silicon and Intel), Developer ID signing,
  notarization and DMG release via GitHub Actions.
