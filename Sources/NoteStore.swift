// Persistenz des Zettels: eine Klartextdatei in ~/Documents/Zettel.txt.
//
// - Jede Änderung wird nach 300 ms Ruhe atomar geschrieben (kein Speichern-Knopf).
// - Die Datei und ihr Ordner werden überwacht. Ändert sie ein anderer Editor,
//   meldet der Store den neuen Inhalt über `onExternalChange`. Der Ordner wird
//   mitüberwacht, weil viele Editoren atomar über eine Umbenennung speichern
//   und dabei der überwachte Datei-Deskriptor ins Leere zeigt.
import Foundation

final class NoteStore {
    let url: URL

    /// Zuletzt gelesener oder geschriebener Inhalt. Dient dazu, eigene Schreib-
    /// vorgänge nicht als externe Änderung zu melden.
    private(set) var lastText: String = ""

    /// Wird auf dem Main-Thread gerufen, wenn sich die Datei von außen geändert hat.
    var onExternalChange: ((String) -> Void)?

    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private var saveTimer: Timer?
    private var pendingText: String?
    private var checkScheduled = false

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        url = docs.appendingPathComponent("Zettel.txt")
    }

    // MARK: Lesen

    func load() -> String {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        lastText = text
        return text
    }

    // MARK: Schreiben

    /// Merkt sich den Text und schreibt ihn nach kurzer Ruhepause.
    func scheduleSave(_ text: String) {
        pendingText = text
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.flush()
        }
    }

    /// Schreibt sofort, falls etwas aussteht. Wird auch beim Beenden gerufen.
    func flush() {
        saveTimer?.invalidate()
        saveTimer = nil
        guard let text = pendingText else { return }
        pendingText = nil
        let exists = FileManager.default.fileExists(atPath: url.path)
        guard text != lastText || !exists else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            lastText = text
        } catch {
            NSLog("Zettel: Speichern fehlgeschlagen: \(error.localizedDescription)")
        }
        // Atomares Schreiben ersetzt die Datei (neuer Inode) → Überwachung neu setzen.
        watchFile()
    }

    // MARK: Überwachung

    func startWatching() {
        watchFile()
        guard dirSource == nil else { return }
        let dirFD = open(url.deletingLastPathComponent().path, O_EVTONLY)
        guard dirFD >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: dirFD, eventMask: .write, queue: .main)
        src.setEventHandler { [weak self] in self?.checkForExternalChange() }
        src.setCancelHandler { close(dirFD) }
        src.resume()
        dirSource = src
    }

    private func watchFile() {
        fileSource?.cancel()
        fileSource = nil
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        src.setEventHandler { [weak self] in self?.checkForExternalChange() }
        src.setCancelHandler { close(fd) }
        src.resume()
        fileSource = src
    }

    private func checkForExternalChange() {
        // Editoren schreiben in Schüben → kurz sammeln, dann einmal prüfen.
        guard !checkScheduled else { return }
        checkScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.checkScheduled = false
            self.watchFile()
            // Eigener Schreibvorgang steht noch aus → nicht dazwischenfunken.
            guard self.pendingText == nil else { return }
            guard let text = try? String(contentsOf: self.url, encoding: .utf8) else { return }
            if text != self.lastText {
                self.lastText = text
                self.onExternalChange?(text)
            }
        }
    }
}
