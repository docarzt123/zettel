// Menüleisten-Symbol, Popover, angepinntes Fenster, Rechtsklick-Menü,
// globales Tastenkürzel und Autostart.
import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate, ZettelHost {
    static let repoURL = URL(string: "https://github.com/docarzt123/zettel")!
    private static let pinnedKey = "pinned"

    private var statusItem: NSStatusItem!
    private let store = NoteStore()
    private lazy var controller = ZettelViewController(store: store)
    private var popover: NSPopover?
    private var panel: NSPanel?
    private var hotKey: HotKey?
    private let menu = NSMenu()
    private var loginItem: NSMenuItem!

    var zettelIsPinned: Bool {
        get { UserDefaults.standard.bool(forKey: Self.pinnedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.pinnedKey) }
    }

    // MARK: Start / Ende

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Zettel")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Zettel (⌃⌥Z)"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        buildContextMenu()

        controller.host = self
        store.onExternalChange = { [weak self] text in self?.controller.applyExternal(text) }
        store.startWatching()

        hotKey = HotKey(keyCode: kVK_ANSI_Z, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggle()
        }

        // Angepinntes Fenster nach Neustart wiederherstellen.
        if zettelIsPinned { showPanel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
    }

    /// Doppelklick auf die App im Finder (oder `open -a Zettel`), während sie
    /// schon läuft → Zettel zeigen statt nichts zu tun.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if zettelIsPinned { showPanel() } else if popover?.isShown != true { showPopover() }
        return false
    }

    /// Ohne Hauptmenü funktionieren ⌘C/⌘V/⌘A/⌘Z im Textfeld nicht, auch bei
    /// einer App ohne Dock-Symbol. Das Menü ist unsichtbar, aber nötig.
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        let find = edit.addItem(withTitle: "Find", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        find.tag = 1 // NSFindPanelAction.showFindPanel
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    // MARK: Rechtsklick-Menü

    private func buildContextMenu() {
        let open = menu.addItem(withTitle: L("menu.open"), action: #selector(toggle), keyEquivalent: "")
        open.target = self
        menu.addItem(.separator())
        let reveal = menu.addItem(withTitle: L("menu.reveal"), action: #selector(revealFile), keyEquivalent: "")
        reveal.target = self
        loginItem = menu.addItem(withTitle: L("menu.login"), action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(.separator())
        let about = menu.addItem(withTitle: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        let quit = menu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle()
        }
    }

    // MARK: Öffnen / Schließen

    @objc func toggle() {
        if zettelIsPinned {
            if let panel, panel.isVisible, panel.isKeyWindow {
                panel.orderOut(nil)
            } else {
                showPanel()
            }
        } else {
            if let popover, popover.isShown {
                popover.performClose(nil)
            } else {
                showPopover()
            }
        }
    }

    private func showPopover() {
        panel?.orderOut(nil)
        panel?.contentViewController = nil
        guard let button = statusItem.button else { return }
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.delegate = self
        pop.contentViewController = controller
        pop.contentSize = ZettelViewController.savedSize()
        popover = pop
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        controller.focusText()
    }

    /// Zeigt das angepinnte Fenster. `contentRect` (Bildschirmkoordinaten)
    /// gibt die Position vor, z. B. die des gerade geschlossenen Popovers,
    /// damit das Fenster beim Anpinnen an Ort und Stelle bleibt.
    private func showPanel(at contentRect: NSRect? = nil) {
        popover?.performClose(nil)
        popover = nil
        if panel == nil {
            let size = ZettelViewController.savedSize()
            let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.titled, .closable, .resizable, .utilityWindow],
                            backing: .buffered, defer: false)
            p.title = "Zettel"
            p.titlebarAppearsTransparent = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isReleasedWhenClosed = false
            p.hidesOnDeactivate = false
            p.isMovableByWindowBackground = true
            p.minSize = ZettelViewController.minSize
            p.delegate = self
            // Autosave-Name ZUERST setzen: er holt die gemerkte Position zurück.
            // Erst danach die gewünschte Position setzen, sonst überschreibt er sie.
            if !p.setFrameUsingName("ZettelPanel") {
                p.center()
            }
            p.setFrameAutosaveName("ZettelPanel")
            panel = p
        }
        guard let panel else { return }
        panel.contentViewController = controller
        if let contentRect {
            var frame = panel.frameRect(forContentRect: contentRect)
            if let screen = NSScreen.screens.first(where: { $0.frame.intersects(contentRect) }) ?? NSScreen.main {
                let vis = screen.visibleFrame
                frame.origin.x = min(max(frame.origin.x, vis.minX), vis.maxX - frame.width)
                frame.origin.y = min(max(frame.origin.y, vis.minY), vis.maxY - frame.height)
            }
            panel.setFrame(frame, display: false)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.focusText()
        controller.refreshPin()
    }

    /// Bildschirmposition des Textfelds, solange es noch im Popover sitzt.
    private func currentContentRect() -> NSRect? {
        guard let window = controller.view.window, popover?.isShown == true else { return nil }
        let inWindow = controller.view.convert(controller.view.bounds, to: nil)
        return window.convertToScreen(inWindow)
    }

    func zettelRequestClose() {
        if zettelIsPinned {
            panel?.orderOut(nil)
        } else {
            popover?.performClose(nil)
        }
    }

    func zettelTogglePin() {
        zettelIsPinned.toggle()
        if zettelIsPinned {
            showPanel(at: currentContentRect())
        } else {
            showPopover()
        }
    }

    func zettelSetModal(_ modal: Bool) {
        popover?.behavior = modal ? .applicationDefined : .transient
    }

    func popoverDidClose(_ notification: Notification) {
        store.flush()
    }

    func windowWillClose(_ notification: Notification) {
        store.flush()
    }

    // MARK: Menüaktionen

    @objc private func revealFile() {
        store.flush()
        if !FileManager.default.fileExists(atPath: store.url.path) {
            try? "".write(to: store.url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.activateFileViewerSelecting([store.url])
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "Zettel \(version)"
        alert.informativeText = String(format: L("about.text"), store.url.path)
        alert.addButton(withTitle: L("about.github"))
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(Self.repoURL)
        }
    }
}
