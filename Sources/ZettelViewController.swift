// Der Inhalt des Popovers bzw. des angepinnten Fensters: ein Textfeld mit
// einem Kopieren-Knopf am Ende jeder Zeile, darunter eine schmale Leiste mit
// Pin, Leeren, Alles kopieren, „Speichern unter …" und einem Griff zum
// Größerziehen.
import AppKit
import UniformTypeIdentifiers

protocol ZettelHost: AnyObject {
    var zettelIsPinned: Bool { get }
    func zettelRequestClose()
    func zettelTogglePin()
    /// Während ein Systemdialog (Sichern-Panel) offen ist, darf das Popover
    /// nicht als „Klick daneben" verschwinden.
    func zettelSetModal(_ modal: Bool)
    /// Popover bzw. Fenster auf die gewünschte Inhaltsgröße bringen.
    func zettelResize(to size: NSSize)
}

final class ZettelViewController: NSViewController, NSTextViewDelegate {
    static let minSize = NSSize(width: 380, height: 180)
    static let defaultSize = NSSize(width: 460, height: 300)
    private static let sizeKey = "contentSize"
    /// Breite der Spalte rechts, in der die Zeilen-Kopierknöpfe sitzen.
    private static let gutterWidth: CGFloat = 30

    let store: NoteStore
    weak var host: ZettelHost?
    private(set) var textView: NSTextView!
    private var pinButton: NSButton!
    private var copyAllButton: NSButton!
    private var pendingExternalText: String?
    private var lineButtons: [NSButton] = []
    private var lineRanges: [NSRange] = []
    private var layoutScheduled = false

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
        updateExclusion()
        scheduleLineButtonLayout()
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
        tv.postsFrameChangedNotifications = true
        textView = tv
        NotificationCenter.default.addObserver(self, selector: #selector(textViewFrameChanged),
                                               name: NSView.frameDidChangeNotification, object: tv)

        let pin = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: L("pin"))!,
                           target: self, action: #selector(togglePin))
        pin.isBordered = false
        pin.toolTip = L("pin.tooltip")
        pin.translatesAutoresizingMaskIntoConstraints = false
        pinButton = pin

        let clear = smallButton(L("clear"), #selector(clearAll), tooltip: L("clear.tooltip"))
        let copyAll = smallButton(L("copyall"), #selector(copyAll), tooltip: L("copyall.tooltip"))
        copyAllButton = copyAll
        let saveAs = smallButton(L("saveas"), #selector(saveAs), tooltip: nil)

        let grip = ResizeGrip()
        grip.translatesAutoresizingMaskIntoConstraints = false
        grip.toolTip = L("resize.tooltip")
        grip.onDrag = { [weak self] delta in self?.resize(by: delta) }

        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        [pin, clear, copyAll, saveAs, grip].forEach { bar.addSubview($0) }

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

            grip.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -2),
            grip.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -2),
            grip.widthAnchor.constraint(equalToConstant: 16),
            grip.heightAnchor.constraint(equalToConstant: 16),

            saveAs.trailingAnchor.constraint(equalTo: grip.leadingAnchor, constant: -6),
            saveAs.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            copyAll.trailingAnchor.constraint(equalTo: saveAs.leadingAnchor, constant: -6),
            copyAll.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            clear.trailingAnchor.constraint(equalTo: copyAll.leadingAnchor, constant: -6),
            clear.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])

        view = root
        textView.string = store.load()
        refreshPin()
        updateExclusion()
        scheduleLineButtonLayout()
    }

    private func smallButton(_ title: String, _ action: Selector, tooltip: String?) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .small
        b.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        b.toolTip = tooltip
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        return b
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        applyPendingExternalText()
        refreshPin()
        scheduleLineButtonLayout()
    }

    func focusText() {
        view.window?.makeFirstResponder(textView)
    }

    // MARK: Größe ziehen

    private func resize(by delta: NSSize) {
        var size = view.frame.size
        size.width = max(Self.minSize.width, size.width + delta.width)
        size.height = max(Self.minSize.height, size.height + delta.height)
        host?.zettelResize(to: size)
    }

    // MARK: Zeilen-Kopierknöpfe

    /// Hält rechts eine Spalte frei, damit der Text nicht unter den Knöpfen liegt.
    private func updateExclusion() {
        guard let container = textView.textContainer else { return }
        let w = textView.bounds.width - textView.textContainerInset.width * 2
        let rect = NSRect(x: w - Self.gutterWidth, y: 0, width: Self.gutterWidth + 10, height: 1_000_000)
        container.exclusionPaths = [NSBezierPath(rect: rect)]
    }

    @objc private func textViewFrameChanged() {
        scheduleLineButtonLayout()
    }

    private func scheduleLineButtonLayout() {
        guard !layoutScheduled else { return }
        layoutScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.layoutScheduled = false
            self?.layoutLineButtons()
        }
    }

    private func layoutLineButtons() {
        guard let layout = textView.layoutManager, let container = textView.textContainer else { return }
        let text = textView.string as NSString
        layout.ensureLayout(for: container)
        let origin = textView.textContainerOrigin
        let x = textView.bounds.width - textView.textContainerInset.width - Self.gutterWidth + 4

        var ranges: [NSRange] = []
        var frames: [NSRect] = []
        var pos = 0
        while pos < text.length {
            let lineRange = text.lineRange(for: NSRange(location: pos, length: 0))
            var content = lineRange
            while content.length > 0,
                  let last = Unicode.Scalar(text.character(at: content.location + content.length - 1)),
                  CharacterSet.newlines.contains(last) {
                content.length -= 1
            }
            if content.length > 0, !text.substring(with: content).trimmingCharacters(in: .whitespaces).isEmpty {
                let glyph = layout.glyphIndexForCharacter(at: content.location)
                let frag = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let y = frag.minY + origin.y + (frag.height - 18) / 2
                ranges.append(content)
                frames.append(NSRect(x: x, y: y, width: 22, height: 18))
            }
            pos = NSMaxRange(lineRange)
        }

        while lineButtons.count < frames.count {
            let b = NSButton(image: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: L("copyline"))!,
                             target: self, action: #selector(copyLine(_:)))
            b.isBordered = false
            b.imageScaling = .scaleProportionallyDown
            b.contentTintColor = .tertiaryLabelColor
            b.toolTip = L("copyline")
            textView.addSubview(b)
            lineButtons.append(b)
        }
        for (i, b) in lineButtons.enumerated() {
            if i < frames.count {
                b.frame = frames[i]
                b.tag = i
                b.isHidden = false
            } else {
                b.isHidden = true
            }
        }
        lineRanges = ranges
    }

    @objc private func copyLine(_ sender: NSButton) {
        guard sender.tag < lineRanges.count else { return }
        let line = (textView.string as NSString).substring(with: lineRanges[sender.tag])
        copyToPasteboard(line)
        flash(sender, symbol: "checkmark", restore: "doc.on.doc")
    }

    @objc private func copyAll() {
        copyToPasteboard(textView.string)
        let title = copyAllButton.title
        copyAllButton.title = L("copied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.copyAllButton.title = title
        }
    }

    private func copyToPasteboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private func flash(_ button: NSButton, symbol: String, restore: String) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.contentTintColor = .controlAccentColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            button.image = NSImage(systemSymbolName: restore, accessibilityDescription: nil)
            button.contentTintColor = .tertiaryLabelColor
        }
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
        scheduleLineButtonLayout()
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        store.scheduleSave(textView.string)
        scheduleLineButtonLayout()
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

    /// Leert das Feld. Läuft über den Undo-Stapel, ⌘Z holt alles zurück.
    @objc private func clearAll() {
        let all = NSRange(location: 0, length: (textView.string as NSString).length)
        guard all.length > 0, textView.shouldChangeText(in: all, replacementString: "") else { return }
        textView.replaceCharacters(in: all, with: "")
        textView.didChangeText()
        focusText()
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

/// Kleiner Griff unten rechts. Ziehen meldet die Bewegung als Delta;
/// nach rechts und nach unten macht das Feld größer.
final class ResizeGrip: NSView {
    var onDrag: ((NSSize) -> Void)?
    private var last: NSPoint = .zero

    override func draw(_ dirtyRect: NSRect) {
        NSColor.tertiaryLabelColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        for offset: CGFloat in [3, 7, 11] {
            path.move(to: NSPoint(x: bounds.maxX - offset, y: bounds.minY + 1))
            path.line(to: NSPoint(x: bounds.maxX - 1, y: bounds.minY + offset))
        }
        path.stroke()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        last = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        onDrag?(NSSize(width: now.x - last.x, height: last.y - now.y))
        last = now
    }
}
