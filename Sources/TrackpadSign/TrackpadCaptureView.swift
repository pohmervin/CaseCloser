import AppKit

@MainActor
final class TrackpadCaptureView: NSView {
    var onStrokePoint: ((CGPoint, InputInjector.StrokePhase) -> Void)?
    var onStrokeEnded: (() -> Void)?

    private(set) var strokes: [[CGPoint]] = []
    private var activeIdentity: (any NSCopying & NSObjectProtocol)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clear() {
        activeIdentity = nil
        strokes.removeAll(keepingCapacity: false)
        needsDisplay = true
    }

    override func touchesBegan(with event: NSEvent) {
        guard activeIdentity == nil,
              let touch = event.touches(matching: .began, in: self).first else {
            return
        }

        activeIdentity = touch.identity
        let point = clamped(touch.normalizedPosition)
        strokes.append([point])
        onStrokePoint?(point, .began)
        needsDisplay = true
    }

    override func touchesMoved(with event: NSEvent) {
        guard let touch = activeTouch(in: event) else { return }
        let point = clamped(touch.normalizedPosition)
        guard strokes.indices.contains(strokes.count - 1) else { return }

        if let previous = strokes[strokes.count - 1].last,
           hypot(point.x - previous.x, point.y - previous.y) < 0.0012 {
            return
        }

        strokes[strokes.count - 1].append(point)
        onStrokePoint?(point, .moved)
        needsDisplay = true
    }

    override func touchesEnded(with event: NSEvent) {
        finishTouch(with: event, cancelled: false)
    }

    override func touchesCancelled(with event: NSEvent) {
        finishTouch(with: event, cancelled: true)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.separatorColor.setStroke()
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        outline.lineWidth = 1
        outline.stroke()

        NSColor.labelColor.setStroke()
        for stroke in strokes where !stroke.isEmpty {
            let path = NSBezierPath()
            path.lineWidth = 2.4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            for (index, point) in stroke.enumerated() {
                let drawPoint = CGPoint(
                    x: 10 + point.x * max(bounds.width - 20, 1),
                    y: 10 + point.y * max(bounds.height - 20, 1)
                )
                if index == 0 {
                    path.move(to: drawPoint)
                } else {
                    path.line(to: drawPoint)
                }
            }

            if stroke.count == 1, let point = stroke.first {
                let dotRect = CGRect(
                    x: 10 + point.x * max(bounds.width - 20, 1) - 1.2,
                    y: 10 + point.y * max(bounds.height - 20, 1) - 1.2,
                    width: 2.4,
                    height: 2.4
                )
                NSBezierPath(ovalIn: dotRect).fill()
            } else {
                path.stroke()
            }
        }
    }

    private func activeTouch(in event: NSEvent) -> NSTouch? {
        guard let activeIdentity else { return nil }
        return event.touches(matching: .touching, in: self).first { $0.identity.isEqual(activeIdentity) }
    }

    private func finishTouch(with event: NSEvent, cancelled: Bool) {
        guard activeIdentity != nil else { return }
        if !cancelled,
           let activeIdentity,
           let touch = event.touches(matching: .ended, in: self).first(where: { $0.identity.isEqual(activeIdentity) }) {
            let point = clamped(touch.normalizedPosition)
            if strokes.indices.contains(strokes.count - 1) {
                strokes[strokes.count - 1].append(point)
            }
            onStrokePoint?(point, .ended)
        } else if let lastPoint = strokes.last?.last {
            onStrokePoint?(lastPoint, .ended)
        }

        activeIdentity = nil
        needsDisplay = true
        onStrokeEnded?()
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
    }
}
