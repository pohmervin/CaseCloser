import AppKit

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let onStart: () -> Void
    private let onQuit: () -> Void

    init(onStart: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onStart = onStart
        self.onQuit = onQuit

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 390),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CaseCloser"
        window.center()
        window.isReleasedWhenClosed = false
        window.sharingType = .readOnly
        super.init(window: window)

        window.delegate = self
        window.contentViewController = makeContentViewController()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onQuit()
        return false
    }

    private func makeContentViewController() -> NSViewController {
        let controller = NSViewController()
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 360))

        let icon = NSImageView(image: NSImage(systemSymbolName: "signature", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 42, weight: .regular)
        icon.contentTintColor = .controlAccentColor

        let title = NSTextField(labelWithString: "Sign naturally on your Mac trackpad")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.alignment = .center

        let explanation = NSTextField(wrappingLabelWithString: "The whole physical trackpad becomes the signature box you select: each corner and the centre map directly. Sign in the memory-only preview, then press Return to apply it to the selected app.")
        explanation.font = .systemFont(ofSize: 14)
        explanation.textColor = .secondaryLabelColor
        explanation.alignment = .center
        explanation.maximumNumberOfLines = 4

        let steps = NSTextField(wrappingLabelWithString: "1. Open the document or webpage containing the signature box.\n2. Select Choose Target & Select Area, then choose its window.\n3. CaseCloser brings it forward; drag around the box, then sign with one finger.")
        steps.font = .systemFont(ofSize: 13)
        steps.textColor = .labelColor
        steps.maximumNumberOfLines = 5

        let privacy = NSTextField(labelWithString: "Your strokes remain in memory and are erased when Signature Mode ends.")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .tertiaryLabelColor
        privacy.alignment = .center

        let startButton = NSButton(title: "Choose Target & Select Area…", target: self, action: #selector(startPressed))
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.keyEquivalent = "\r"

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitPressed))
        quitButton.bezelStyle = .inline

        let stack = NSStackView(views: [icon, title, explanation, steps, startButton, privacy, quitButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(22, after: explanation)
        stack.setCustomSpacing(22, after: steps)
        stack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 44),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -44),
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            explanation.widthAnchor.constraint(equalToConstant: 460),
            steps.widthAnchor.constraint(equalToConstant: 430),
            startButton.widthAnchor.constraint(equalToConstant: 270)
        ])

        controller.view = root
        return controller
    }

    @objc private func startPressed() {
        onStart()
    }

    @objc private func quitPressed() {
        onQuit()
    }
}
