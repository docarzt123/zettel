// Der Inhalt des Popovers bzw. des angepinnten Fensters: ein Textfeld,
// darunter eine schmale Leiste mit Pin-Knopf und „Speichern unter …".
import AppKit
import UniformTypeIdentifiers

protocol ZettelHost: AnyObject {
    var zettelIsPinned: Bool { get }
    func zettelRequestClose()
    func zettelTogglePin()
    /// Während ein Systemdialog (Sichern-Panel) offen ist, darf das Popover
    /// nicht als „Klick daneben" verschwinden.
    func zettelSetModal(_ modal: Bool)
}

final class ZettelViewController: NSViewController, NSTextViewDelegate {
    static let minSize = NSSize(width: 280, height: 180)
    static let defaultSize = NSSize(width: 420, height: 300)
    private static let sizeKey = "contentSize"

    let store: NoteStore
    weak var host: ZettelHost?
    private(set) var textView: NSTextView!
    private var pinButton: NSButton!
    private var pendingExternalText: String?

    init(store: NoteStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("nicht unterstützt") }

    // MARK: Größe merken

    static func savedSize() -> NSSize {
        let d = UserDefaults.standard
        let w = d.double(forKey: sizeKey + "Width")
        let h = d.double(forKey: sizeKey + "Height")
        guard w >= minSize.width, h >= minSize.height else { return defaultSize }
        return NSSize(width: w, height: h)
    }

    private func rememberSize(_ size: NSSize) {
        guard size.width >= Self.minSize.width, size.height >= Self.minSize.height else { return }
        let d = UserDefaults.standard
        d.set(Double(size.width), forKey: Self.sizeKey + "Width")
        d.set(Double(size.height), forKey: Self.sizeKey + "Height")
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        rememberSize(view.frame.size)
    }

    // MARK: Aufbau

    override func loadView() {
        let root = NSView(frame: NSRect(origin: .zero, size: Self.savedSize()))

        let scroll = NSTextView.scrollableTextView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let tv = scroll.documentView as! NSTextView
        tv.isRichText = false
        tv.font = NSFont.systemFont(ofSize: 14)
        tv.textColor = .textColor
        tv.drawsBackground = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.delegate = self
        textView = tv

        let pin = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: L("pin"))!,
                           target: self, action: #selector(togglePin))
        pin.isBordered = false
        pin.toolTip = L("pin.tooltip")
        pin.translatesAutoresizingMaskIntoConstraints = false
        pinButton = pin

        let saveAs = NSButton(title: L("saveas"), target: self, action: #selector(saveAs))
        saveAs.bezelStyle = .rounded
        saveAs.controlSize = .small
        saveAs.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        saveAs.translatesAutoresizingMaskIntoConstraints = false

        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(pin)
        bar.addSubview(saveAs)

        root.addSubview(scroll)
        root.addSubview(bar)

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minSize.width),
            root.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minSize.height),

            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -4),
            scroll.bottomAnchor.constraint(equalTo: bar.topAnchor),

            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 32),

            pin.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            pin.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            saveAs.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            saveAs.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])

        view = root
        textView.string = store.load()
        refreshPin()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        applyPendingExternalText()
        refreshPin()
    }

    func focusText() {
        view.window?.makeFirstResponder(textView)
    }

    // MARK: Externe Änderungen

    /// Vom Store gemeldeter neuer Dateiinhalt. Wird sofort übernommen, wenn
    /// gerade nicht getippt wird, sonst beim nächsten Öffnen.
    func applyExternal(_ text: String) {
        let editing = view.window?.isVisible == true
            && view.window?.isKeyWindow == true
            && view.window?.firstResponder === textView
        if editing {
            pendingExternalText = text
        } else {
            replaceText(text)
        }
    }

    private func applyPendingExternalText() {
        guard let text = pendingExternalText else { return }
        pendingExternalText = nil
        replaceText(text)
    }

    private func replaceText(_ text: String) {
        guard textView.string != text else { return }
        let sel = textView.selectedRange()
        textView.string = text
        let len = (text as NSString).length
        textView.setSelectedRange(NSRange(location: min(sel.location, len), length: 0))
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        store.scheduleSave(textView.string)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            host?.zettelRequestClose()
            return true
        }
        return false
    }

    // MARK: Aktionen

    @objc private func togglePin() {
        host?.zettelTogglePin()
        refreshPin()
    }

    func refreshPin() {
        let pinned = host?.zettelIsPinned ?? false
        pinButton?.image = NSImage(systemSymbolName: pinned ? "pin.fill" : "pin",
                                   accessibilityDescription: L("pin"))
        pinButton?.contentTintColor = pinned ? .controlAccentColor : .secondaryLabelColor
    }

    @objc private func saveAs() {
        store.flush()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.title = L("saveas.title")
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmm"
        panel.nameFieldStringValue = "Zettel-\(stamp.string(from: Date())).txt"

        let text = textView.string
        host?.zettelSetModal(true)
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] result in
            self?.host?.zettelSetModal(false)
            guard result == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
}
