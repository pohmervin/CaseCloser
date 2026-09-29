import AppKit
import ApplicationServices

@MainActor
struct SignatureTarget {
    let application: NSRunningApplication
    let window: AXUIElement?
    let windowTitle: String?

    var displayName: String {
        let applicationName = application.localizedName ?? "Unknown application"
        guard let windowTitle, !windowTitle.isEmpty else {
            return applicationName
        }
        return "\(applicationName) — \(windowTitle)"
    }

    func activate() {
        guard !application.isTerminated else { return }

        application.activate(options: [])

        guard let window else { return }
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }
}

@MainActor
enum TargetPickerController {
    static var hasAvailableTargets: Bool {
        !availableTargets(preferredProcessIdentifier: nil).isEmpty
    }

    static func chooseTarget(preferredProcessIdentifier: pid_t?) -> SignatureTarget? {
        let targets = availableTargets(preferredProcessIdentifier: preferredProcessIdentifier)
        guard !targets.isEmpty else { return nil }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 480, height: 30), pullsDown: false)
        for target in targets {
            popup.addItem(withTitle: target.displayName)
            if let image = target.application.icon?.copy() as? NSImage {
                image.size = NSSize(width: 20, height: 20)
                popup.lastItem?.image = image
            }
        }

        if let preferredProcessIdentifier,
           let preferredIndex = targets.firstIndex(where: {
               $0.application.processIdentifier == preferredProcessIdentifier
           }) {
            popup.selectItem(at: preferredIndex)
        }

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 44))
        let label = NSTextField(labelWithString: "Window or application")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        popup.translatesAutoresizingMaskIntoConstraints = false
        accessory.addSubview(label)
        accessory.addSubview(popup)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            label.topAnchor.constraint(equalTo: accessory.topAnchor),
            popup.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            popup.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
            popup.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4)
        ])

        let alert = NSAlert()
        alert.messageText = "Choose where the signature will go"
        alert.informativeText = "CaseCloser will bring this window forward. Then drag around its signature box."
        alert.alertStyle = .informational
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return targets[popup.indexOfSelectedItem]
    }

    private static func availableTargets(preferredProcessIdentifier: pid_t?) -> [SignatureTarget] {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications
            .filter {
                $0.processIdentifier != ownProcessIdentifier &&
                !$0.isTerminated &&
                $0.activationPolicy == .regular
            }
            .sorted { lhs, rhs in
                if lhs.processIdentifier == preferredProcessIdentifier { return true }
                if rhs.processIdentifier == preferredProcessIdentifier { return false }
                return (lhs.localizedName ?? "").localizedCaseInsensitiveCompare(rhs.localizedName ?? "") == .orderedAscending
            }

        return applications.flatMap { application in
            let windows = accessibilityWindows(for: application)
            if windows.isEmpty {
                return [SignatureTarget(application: application, window: nil, windowTitle: nil)]
            }
            return windows.map {
                SignatureTarget(application: application, window: $0.element, windowTitle: $0.title)
            }
        }
    }

    private static func accessibilityWindows(for application: NSRunningApplication) -> [(element: AXUIElement, title: String)] {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success,
        let windows = value as? [AXUIElement] else {
            return []
        }

        return windows.enumerated().map { index, window in
            let title = stringAttribute(kAXTitleAttribute, from: window)
            let fallback = windows.count == 1 ? "Main window" : "Window \(index + 1)"
            return (window, title?.isEmpty == false ? title! : fallback)
        }
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
