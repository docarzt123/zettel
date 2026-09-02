# Zettel

*[English version: README.en.md](README.en.md)*

Ein Textfeld in der Menüleiste. Nicht mehr.

Klick auf das Symbol neben der Uhr, ein Textfeld geht auf, man tippt oder
fügt etwas ein, klickt woanders hin, weg ist es. Der Text bleibt erhalten und
liegt als ganz normale Textdatei in `~/Documents/Zettel.txt`. Gedacht als
Zwischenablage für Textbausteine, Links, halbe Gedanken, alles, was man kurz
irgendwo parken will, ohne dafür einen Editor zu öffnen.

## Installation

**Fertige App:** Neueste `Zettel.dmg` unter
[Releases](https://github.com/docarzt123/zettel/releases) laden, öffnen,
`Zettel` in den Ordner `Programme` ziehen, starten. Die App ist mit
Developer-ID signiert und bei Apple notarisiert, macOS öffnet sie ohne
Nachfrage.

**Beim ersten Start** fragt macOS, ob Zettel auf den Ordner „Dokumente"
zugreifen darf. Das muss man erlauben, dort liegt die Textdatei.

**Aus dem Quellcode:** Xcode oder die Command Line Tools installieren, dann

```bash
./build.sh
```

Das baut `dist/Zettel.app` (Apple Silicon und Intel), signiert sie mit dem
Developer-ID-Zertifikat aus dem Schlüsselbund, falls eines da ist, sonst
ad hoc, kopiert sie nach `/Applications` und startet sie. Mit
`./build.sh --no-install` bleibt es beim Bauen.

Mindestens macOS 13 (Ventura).

## Bedienung

| Aktion | Wie |
|---|---|
| Öffnen und schließen | Klick auf das Symbol in der Menüleiste oder `⌃⌥Z` (Control + Option + Z), von überall |
| Schließen | Klick irgendwo anders hin, `Esc`, oder nochmal `⌃⌥Z` |
| Anpinnen | Pin-Symbol unten links. Das Feld wird zu einem kleinen Fenster, das über allen anderen Apps schwebt, auch über Vollbild-Apps. Nochmal klicken hebt es auf. |
| Größe ändern | Am Rand ziehen. Die Größe wird gemerkt, im Popover wie im angepinnten Fenster. |
| Kopie speichern | „Speichern unter …" unten rechts. Der Inhalt bleibt im Zettel stehen, die Kopie ist eine eigene Datei. |
| Rechtsklick auf das Symbol | Zettel öffnen · Datei im Finder zeigen · Bei Login starten · Über Zettel · Beenden |

Im Textfeld funktionieren die üblichen Kürzel: `⌘A`, `⌘C`, `⌘V`, `⌘X`,
`⌘Z`, `⌘⇧Z` und `⌘F` für die Suche.

**Speichern** passiert von selbst, etwa eine Drittelsekunde nach dem letzten
Tastendruck, sowie beim Schließen und Beenden. Es gibt keinen
Speichern-Knopf, weil es nichts zu entscheiden gibt.

**Die Datei** `~/Documents/Zettel.txt` ist reiner Text in UTF-8. Man kann sie
mit jedem anderen Programm öffnen und ändern. Zettel merkt das und lädt den
neuen Inhalt nach, sobald man nicht gerade selbst darin tippt.

## Aufbau

Native Swift-App mit AppKit, ohne Xcode-Projekt und ohne Abhängigkeiten.
`build.sh` ruft direkt `swiftc` auf.

| Datei | Aufgabe |
|---|---|
| `Sources/main.swift` | Startet die App als Menüleisten-Programm ohne Dock-Symbol |
| `Sources/AppDelegate.swift` | Menüleisten-Symbol, Popover, angepinntes Fenster, Rechtsklick-Menü, Tastenkürzel, Autostart, Über-Dialog |
| `Sources/ZettelViewController.swift` | Das Textfeld mit Pin-Knopf und „Speichern unter", Größe merken, externe Änderungen übernehmen |
| `Sources/NoteStore.swift` | Lesen und verzögertes atomares Schreiben der Textdatei, Überwachung von Datei und Ordner |
| `Sources/HotKey.swift` | Globales Tastenkürzel über die Carbon-Hotkey-API (braucht keine Bedienungshilfen-Freigabe) |
| `Sources/L10n.swift` | Kurzform für lokalisierte Texte |
| `Resources/de.lproj`, `Resources/en.lproj` | Oberflächentexte Deutsch und Englisch, macOS wählt nach Systemsprache |
| `Resources/Info.plist` | Bundle-Beschreibung, `__VERSION__` wird beim Bauen aus `VERSION` ersetzt |
| `scripts/make_icon.swift` | Rendert das App-Symbol beim Bauen |
| `scripts/macos_sign.sh`, `scripts/build_dmg.sh`, `scripts/macos_notarize.sh` | Signieren, DMG packen, notarisieren |
| `.github/workflows/build.yml` | CI: bei jedem Push kompilieren, bei einem Tag `vX.Y.Z` signieren, notarisieren und das DMG ans Release hängen |

Einstellungen (Größe, angepinnt, Fensterposition) liegen in den
UserDefaults von `com.reisezoom.zettel`.

## Release

1. `VERSION` hochzählen, `CHANGELOG.md` pflegen.
2. `./build.sh` und kurz testen.
3. Tag setzen und pushen:
   ```bash
   git tag v1.0.0 && git push origin main v1.0.0
   ```
4. GitHub Actions baut, signiert, notarisiert und veröffentlicht das DMG.

Dafür braucht das Repo diese Secrets (Settings → Secrets and variables →
Actions): `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD` für das
Developer-ID-Zertifikat, `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`
für die Notarisierung. Fehlen sie, baut die CI trotzdem, nur unsigniert.

## Stand für die Weiterarbeit

Version 1.0.0, alle Funktionen aus der Planung sind umgesetzt. Offen ist
nichts. Bei Änderungen: `CHANGELOG.md` und beide READMEs pflegen, dann
`./build.sh` zum Testen. Die Oberflächentexte gibt es in beiden Sprachen,
neue Texte gehören in beide `Localizable.strings`.

## Lizenz

MIT, siehe `LICENSE`.
