import CoreGraphics
import Testing
@testable import TrackpadSign

@Suite("Target coordinate mapping")
struct TargetMapperTests {
    @Test("AppKit rectangles and trackpad corners map to Quartz coordinates")
    func convertsAppKitRectangleAndMapsTrackpadCorners() {
        let mapper = TargetMapper(
            targetRectInAppKitCoordinates: CGRect(x: 100, y: 200, width: 400, height: 100),
            mainScreenTop: 900,
            insetFraction: 0
        )

        #expect(mapper.targetRect == CGRect(x: 100, y: 600, width: 400, height: 100))
        #expect(mapper.screenPoint(for: CGPoint(x: 0, y: 1)) == CGPoint(x: 100, y: 600))
        #expect(mapper.screenPoint(for: CGPoint(x: 1, y: 0)) == CGPoint(x: 500, y: 700))
    }

    @Test("Touch coordinates are clamped and inset")
    func clampsTouchCoordinatesAndAppliesInset() {
        let mapper = TargetMapper(
            targetRectInAppKitCoordinates: CGRect(x: 20, y: 20, width: 200, height: 100),
            mainScreenTop: 500,
            insetFraction: 0.1
        )

        #expect(mapper.screenPoint(for: CGPoint(x: -2, y: 4)) == CGPoint(x: 40, y: 390))
        #expect(mapper.screenPoint(for: CGPoint(x: 2, y: -4)) == CGPoint(x: 200, y: 470))
    }
}
