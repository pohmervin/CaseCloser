import AppKit
import CoreGraphics

@MainActor
final class SigningSessionController: NSObject, NSWindowDelegate {
    private let targetRect: CGRect
    private let targetScreen: NSScreen
    private let targetProcessIdentifier: pid_t
    private let targetApplicationName: String
    private let onStop: () -> Void
    private let injector: InputInjector
    private let originalMouseLocation: CGPoint

    private var panel: NSPanel?
    private var captureView: TrackpadCaptureView?
    private var statusLabel: NSTextField?
    private var localEscapeMonitor: Any?
    private var globalEscapeMonitor: Any?
    private var isRunning = false
    private var cursorHidden = false

    init(
        targetRectInAppKitCoordinates targetRect: CGRect,
        targetScreen: NSScreen,
        targetProcessIdentifier: pid_t,
        targetApplicationName: String,
        onStop: @escaping () -> Void
    ) {
        self.targetRect = targetRect
        self.targetScreen = targetScreen
        self.targetProcessIdentifier = targetProcessIdentifier
        self.targetApplicationName = targetApplicationName
        self.onStop = onStop
        self.originalMouseLocation = NSEvent.mouseLocation

        let mainTop = NSScreen.screens.first?.frame.maxY ?? targetScreen.frame.maxY
        let mapper = TargetMapper(
            targetRectInAppKitCoordinates: targetRect,
            mainScreenTop: mainTop
        )
        self.injector = InputInjector(mapper: mapper)
        super.init()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let panelFrame = preferredPanelFrame()
        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "CaseCloser — Signature Mode"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.delegate = self
        panel.contentView = makePanelContentView()
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        CGAssociateMouseAndMouseCursorPosition(0)
        hideCursor()
        parkCursorOverCaptureView()

        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let isCancelKey = event.keyCode == 53
            let isFinishKey = event.keyCode == 36
            let isCommandQ = event.keyCode == 12 && event.modifierFlags.contains(.command)
            guard isCancelKey || isFinishKey || isCommandQ else { return event }
            if isFinishKey {
                self?.finish()
            } else {
                self?.cancel()
            }
            return nil
        }
        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let isCancelKey = event.keyCode == 53
            let isFinishKey = event.keyCode == 36
            let isCommandQ = event.keyCode == 12 && event.modifierFlags.contains(.command)
            guard isCancelKey || isFinishKey || isCommandQ else { return }
            Task { @MainActor in
                if isFinishKey {
                    self?.finish()
                } else {
                    self?.cancel()
                }
            }
        }
    }

    func stop() {
        cancel()
    }

    func cancel() {
        guard isRunning else { return }
        isRunning = false
        removeKeyMonitors()
        injector.cancelReplay()
        captureView?.clear()
        captureView = nil
        panel?.orderOut(nil)
        panel = nil

        CGAssociateMouseAndMouseCursorPosition(1)
        CGWarpMouseCursorPosition(appKitToQuartz(originalMouseLocation))
        showCursor()
        onStop()
    }

    func finish() {
        guard isRunning else { return }
        let strokes = captureView?.strokes ?? []
        guard strokes.contains(where: { !$0.isEmpty }) else {
            cancel()
            return
        }

        isRunning = false
        removeKeyMonitors()
        statusLabel?.stringValue = "APPLYING SIGNATURE…"
        statusLabel?.textColor = .systemBlue

        CGAssociateMouseAndMouseCursorPosition(1)
        panel?.orderOut(nil)

        guard let targetApplication = NSRunningApplication(processIdentifier: targetProcessIdentifier),
              !targetApplication.isTerminated else {
            captureView?.clear()
            captureView = nil
            panel = nil
            CGWarpMouseCursorPosition(appKitToQuartz(originalMouseLocation))
            showCursor()
            onStop()
            return
        }

        targetApplication.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.injector.replay(strokes: strokes) { [weak self] in
                guard let self else { return }
                self.captureView?.clear()
                self.captureView = nil
                self.panel = nil
                self.showCursor()
                self.onStop()
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancel()
        return false
    }

    private func makePanelContentView() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 250))

        let status = NSTextField(labelWithString: "WAITING FOR TRACKPAD TOUCH")
        status.font = .systemFont(ofSize: 11, weight: .bold)
        status.textColor = .systemOrange
        status.alignment = .center
        statusLabel = status

        let instruction = NSTextField(labelWithString: "The whole trackpad maps to \(targetApplicationName) • Touch to draw • Lift between strokes")
        instruction.font = .systemFont(ofSize: 12)
        instruction.textColor = .secondaryLabelColor
        instruction.alignment = .center

        let capture = TrackpadCaptureView(frame: .zero)
        capture.translatesAutoresizingMaskIntoConstraints = false
        capture.onStrokePoint = { [weak self] point, phase in
            if phase == .began {
                self?.statusLabel?.stringValue = "TOUCH DETECTED — CAPTURING SIGNATURE"
                self?.statusLabel?.textColor = .systemGreen
            }
        }
        capture.onStrokeEnded = { [weak self] in
            self?.statusLabel?.stringValue = "READY — PRESS RETURN WHEN COMPLETE"
            self?.statusLabel?.textColor = .systemGreen
            self?.parkCursorOverCaptureView()
        }
        captureView = capture

        let finishButton = NSButton(title: "Apply to \(targetApplicationName) (Return)", target: self, action: #selector(finishPressed))
        finishButton.bezelStyle = .rounded
        finishButton.keyEquivalent = "\r"

        let footer = NSTextField(labelWithString: "Return applies • Escape cancels • Nothing is saved")
        footer.font = .systemFont(ofSize: 10)
        footer.textColor = .tertiaryLabelColor

        let headerStack = NSStackView(views: [status, instruction])
        headerStack.orientation = .vertical
        headerStack.spacing = 3

        let footerStack = NSStackView(views: [footer, finishButton])
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.distribution = .fill

        let stack = NSStackView(views: [headerStack, capture, footerStack])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 34),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            capture.heightAnchor.constraint(equalToConstant: 142)
        ])

        return root
    }

    @objc private func finishPressed() {
        finish()
    }

    private func removeKeyMonitors() {
        if let localEscapeMonitor {
            NSEvent.removeMonitor(localEscapeMonitor)
            self.localEscapeMonitor = nil
        }
        if let globalEscapeMonitor {
            NSEvent.removeMonitor(globalEscapeMonitor)
            self.globalEscapeMonitor = nil
        }
    }

    private func parkCursorOverCaptureView() {
        guard isRunning, let captureView, let window = captureView.window else { return }
        let localCenter = CGPoint(x: captureView.bounds.midX, y: captureView.bounds.midY)
        let windowPoint = captureView.convert(localCenter, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        CGWarpMouseCursorPosition(appKitToQuartz(screenPoint))
    }

    private func preferredPanelFrame() -> CGRect {
        let visible = targetScreen.visibleFrame
        let panelSize = CGSize(width: min(500, visible.width - 24), height: 250)
        let margin: CGFloat = 12
        let candidates = [
            CGRect(x: visible.minX + margin, y: visible.maxY - panelSize.height - margin, width: panelSize.width, height: panelSize.height),
            CGRect(x: visible.maxX - panelSize.width - margin, y: visible.maxY - panelSize.height - margin, width: panelSize.width, height: panelSize.height),
            CGRect(x: visible.minX + margin, y: visible.minY + margin, width: panelSize.width, height: panelSize.height),
            CGRect(x: visible.maxX - panelSize.width - margin, y: visible.minY + margin, width: panelSize.width, height: panelSize.height)
        ]

        return candidates.min { lhs, rhs in
            lhs.intersection(targetRect).area < rhs.intersection(targetRect).area
        } ?? candidates[0]
    }

    private func appKitToQuartz(_ point: CGPoint) -> CGPoint {
        let mainTop = NSScreen.screens.first?.frame.maxY ?? targetScreen.frame.maxY
        return CGPoint(x: point.x, y: mainTop - point.y)
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        CGDisplayHideCursor(CGMainDisplayID())
        cursorHidden = true
    }

    private func showCursor() {
        guard cursorHidden else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        cursorHidden = false
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isInfinite else { return 0 }
        return width * height
    }
}
