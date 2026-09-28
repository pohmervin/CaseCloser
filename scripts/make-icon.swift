#!/usr/bin/env swift

import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets/CaseCloserIcon.png")
let size = NSSize(width: 1024, height: 1024)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create icon canvas")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 205, yRadius: 205)
tile.addClip()
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.025, green: 0.13, blue: 0.38, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.55, blue: 0.66, alpha: 1)
])!
background.draw(
    from: NSPoint(x: 110, y: 120),
    to: NSPoint(x: 900, y: 900),
    options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
)

NSColor(calibratedRed: 0.11, green: 0.36, blue: 0.64, alpha: 0.96).setFill()
NSBezierPath(roundedRect: NSRect(x: 225, y: 205, width: 560, height: 610), xRadius: 76, yRadius: 76).fill()

NSColor(calibratedWhite: 0.82, alpha: 0.72).setFill()
for rect in [
    NSRect(x: 315, y: 680, width: 380, height: 34),
    NSRect(x: 315, y: 606, width: 330, height: 34),
    NSRect(x: 315, y: 532, width: 235, height: 34)
] {
    NSBezierPath(roundedRect: rect, xRadius: 17, yRadius: 17).fill()
}

NSColor(calibratedRed: 0.96, green: 0.67, blue: 0.14, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 675, y: 260, width: 160, height: 160)).fill()

let signature = NSBezierPath()
signature.move(to: NSPoint(x: 250, y: 330))
signature.curve(to: NSPoint(x: 420, y: 470), controlPoint1: NSPoint(x: 330, y: 350), controlPoint2: NSPoint(x: 430, y: 560))
signature.curve(to: NSPoint(x: 520, y: 350), controlPoint1: NSPoint(x: 400, y: 390), controlPoint2: NSPoint(x: 430, y: 310))
signature.curve(to: NSPoint(x: 660, y: 380), controlPoint1: NSPoint(x: 575, y: 420), controlPoint2: NSPoint(x: 580, y: 315))
signature.line(to: NSPoint(x: 730, y: 305))
signature.line(to: NSPoint(x: 850, y: 455))
signature.lineWidth = 44
signature.lineCapStyle = .round
signature.lineJoinStyle = .round
NSColor.white.setStroke()
signature.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: outputURL)
