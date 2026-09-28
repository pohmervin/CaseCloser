import AppKit

@MainActor
final class SelectionOverlayController {
    enum Result {
        case selected(CGRect, NSScreen)
        case cancelled
    }

    private var window: NSWindow?
    private var completion: ((Result) -> Void)?

    func begin(completion: @escaping (Result) -> Void) {
        self.completion = completion

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first else {
            finish(with: .cancelled)
            return
        }
        let selectionView = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        selectionView.onComplete = { [weak self] localRect in
            guard let self else { return }
            let globalRect = localRect.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)
            self.finish(with: .selected(globalRect, screen))
        }
        selectionView.onCancel = { [weak self] in
            self?.finish(with: .cancelled)
        }

        let window = SelectionWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .popUpMenu
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = selectionView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func finish(with result: Result) {
        window?.orderOut(nil)
        window = nil
        let callback = completion
        completion = nil
        callback?(result)
    }
}

@MainActor
private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class SelectionView: NSView {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.42).setFill()
        bounds.fill()

        if let selectionRect {
            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .copy
            NSColor.clear.setFill()
            selectionRect.fill()
            NSGraphicsContext.current?.restoreGraphicsState()

            let border = NSBezierPath(rect: selectionRect)
            border.lineWidth = 2
            NSColor.systemBlue.setStroke()
            border.stroke()
        }

        let heading = "Drag around the signature box"
        let detail = "Press Escape to cancel"
        drawCenteredText(heading, y: bounds.midY + 28, font: .systemFont(ofSize: 24, weight: .semibold), color: .white)
        drawCenteredText(detail, y: bounds.midY - 8, font: .systemFont(ofSize: 14), color: .white.withAlphaComponent(0.82))
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width >= 40, rect.height >= 24 else {
            startPoint = nil
            currentPoint = nil
            needsDisplay = true
            NSSound.beep()
            return
        }
        onComplete?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    private func drawCenteredText(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .shadow: {
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
                shadow.shadowBlurRadius = 4
                return shadow
            }()
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }
}
