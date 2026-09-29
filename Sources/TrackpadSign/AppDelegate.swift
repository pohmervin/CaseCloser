import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var selectionController: SelectionOverlayController?
    private var signingSession: SigningSessionController?
    private var statusItem: NSStatusItem?
    private var lastExternalApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalApplication = frontmost
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                return
            }
            Task { @MainActor in
                self?.lastExternalApplication = application
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        showMainWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        signingSession?.stop()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController(
                onStart: { [weak self] in self?.startSignatureMode() },
                onQuit: { NSApp.terminate(nil) }
            )
        }

        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func startSignatureMode() {
        guard signingSession == nil, selectionController == nil else { return }

        guard InputInjector.ensurePostingPermission() else {
            showPermissionAlert()
            return
        }

        guard let target = TargetPickerController.chooseTarget(
            preferredProcessIdentifier: lastExternalApplication?.processIdentifier
        ) else {
            if TargetPickerController.hasAvailableTargets == false {
                showAlert(
                    title: "No target application found",
                    message: "Open the document or browser containing the signature box, then try again."
                )
            }
            return
        }

        guard !target.application.isTerminated else {
            showAlert(
                title: "The selected application closed",
                message: "Open it again, then choose its window from CaseCloser."
            )
            return
        }

        mainWindowController?.window?.orderOut(nil)
        target.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard !target.application.isTerminated else {
                self?.showMainWindow()
                return
            }
            target.activate()
            self?.presentSelectionOverlay(targetApplication: target.application)
        }
    }

    @objc func stopSignatureMode() {
        signingSession?.stop()
        signingSession = nil
        rebuildStatusMenu(isSigning: false)
    }

    private func presentSelectionOverlay(targetApplication: NSRunningApplication) {
        let controller = SelectionOverlayController()
        selectionController = controller
        controller.begin { [weak self] result in
            guard let self else { return }
            self.selectionController = nil

            switch result {
            case .cancelled:
                self.rebuildStatusMenu(isSigning: false)
            case .selected(let targetRect, let screen):
                self.beginSigning(
                    targetRect: targetRect,
                    screen: screen,
                    targetApplication: targetApplication
                )
            }
        }
    }

    private func beginSigning(
        targetRect: CGRect,
        screen: NSScreen,
        targetApplication: NSRunningApplication
    ) {
        let session = SigningSessionController(
            targetRectInAppKitCoordinates: targetRect,
            targetScreen: screen,
            targetProcessIdentifier: targetApplication.processIdentifier,
            targetApplicationName: targetApplication.localizedName ?? "selected application",
            onStop: { [weak self] in
                self?.signingSession = nil
                NSApp.terminate(nil)
            }
        )
        signingSession = session
        session.start()
        rebuildStatusMenu(isSigning: true)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "signature", accessibilityDescription: "CaseCloser")
        item.button?.toolTip = "CaseCloser"
        statusItem = item
        rebuildStatusMenu(isSigning: false)
    }

    private func rebuildStatusMenu(isSigning: Bool) {
        let menu = NSMenu()

        if isSigning {
            let stopItem = NSMenuItem(title: "Finish Signature Mode", action: #selector(stopSignatureMode), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(title: "Choose Target & Select Area…", action: #selector(startSignatureMode), keyEquivalent: "s")
            startItem.keyEquivalentModifierMask = [.command, .option]
            startItem.target = self
            menu.addItem(startItem)
        }

        menu.addItem(.separator())
        let showItem = NSMenuItem(title: "Show CaseCloser", action: #selector(showMainWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func showPermissionAlert() {
        showAlert(
            title: "Accessibility permission required",
            message: "CaseCloser needs Accessibility permission to send your live strokes to the selected signature box. Enable CaseCloser in System Settings › Privacy & Security › Accessibility, then try again."
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
