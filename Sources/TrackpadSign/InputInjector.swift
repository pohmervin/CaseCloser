import AppKit
import ApplicationServices

struct TargetMapper: Sendable {
    let targetRect: CGRect
    let mainScreenTop: CGFloat
    let insetFraction: CGFloat

    init(targetRectInAppKitCoordinates: CGRect, mainScreenTop: CGFloat, insetFraction: CGFloat = 0.035) {
        let quartzY = mainScreenTop - targetRectInAppKitCoordinates.maxY
        self.targetRect = CGRect(
            x: targetRectInAppKitCoordinates.minX,
            y: quartzY,
            width: targetRectInAppKitCoordinates.width,
            height: targetRectInAppKitCoordinates.height
        )
        self.mainScreenTop = mainScreenTop
        self.insetFraction = insetFraction
    }

    func screenPoint(for normalizedTrackpadPoint: CGPoint) -> CGPoint {
        let xInset = targetRect.width * insetFraction
        let yInset = targetRect.height * insetFraction
        let drawable = targetRect.insetBy(dx: xInset, dy: yInset)
        let x = drawable.minX + clamp(normalizedTrackpadPoint.x) * drawable.width
        let y = drawable.minY + (1 - clamp(normalizedTrackpadPoint.y)) * drawable.height
        return CGPoint(x: x, y: y)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

@MainActor
final class InputInjector {
    enum StrokePhase {
        case began
        case moved
        case ended
    }

    private let mapper: TargetMapper
    private let source = CGEventSource(stateID: .combinedSessionState)
    private var replaySteps: [ReplayStep] = []
    private var replayIndex = 0
    private var replayCompletion: (() -> Void)?

    private struct ReplayStep {
        let eventType: CGEventType
        let point: CGPoint
        let delayAfter: TimeInterval
    }

    init(mapper: TargetMapper) {
        self.mapper = mapper
        source?.localEventsSuppressionInterval = 0
    }

    static func ensurePostingPermission() -> Bool {
        if CGPreflightPostEventAccess() {
            return true
        }
        return CGRequestPostEventAccess()
    }

    func replay(strokes: [[CGPoint]], completion: @escaping () -> Void) {
        cancelReplay()

        for stroke in strokes where !stroke.isEmpty {
            guard let first = stroke.first, let last = stroke.last else { continue }
            replaySteps.append(
                ReplayStep(
                    eventType: .leftMouseDown,
                    point: mapper.screenPoint(for: first),
                    delayAfter: 1.0 / 120.0
                )
            )

            for point in stroke.dropFirst() {
                replaySteps.append(
                    ReplayStep(
                        eventType: .leftMouseDragged,
                        point: mapper.screenPoint(for: point),
                        delayAfter: 1.0 / 120.0
                    )
                )
            }

            replaySteps.append(
                ReplayStep(
                    eventType: .leftMouseUp,
                    point: mapper.screenPoint(for: last),
                    delayAfter: 0.035
                )
            )
        }

        guard !replaySteps.isEmpty else {
            completion()
            return
        }

        replayCompletion = completion
        postNextReplayStep()
    }

    func cancelReplay() {
        replaySteps.removeAll(keepingCapacity: false)
        replayIndex = 0
        replayCompletion = nil
    }

    private func postNextReplayStep() {
        guard replayIndex < replaySteps.count else {
            replaySteps.removeAll(keepingCapacity: false)
            replayIndex = 0
            let completion = replayCompletion
            replayCompletion = nil
            completion?()
            return
        }

        let step = replaySteps[replayIndex]
        replayIndex += 1

        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: step.eventType,
            mouseCursorPosition: step.point,
            mouseButton: .left
        ) else {
            DispatchQueue.main.async { [weak self] in
                self?.postNextReplayStep()
            }
            return
        }

        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + step.delayAfter) { [weak self] in
            self?.postNextReplayStep()
        }
    }
}
