// Draws the app icon and packs it into Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift
//
// The drawing is resolution independent, so every size in the iconset is
// rendered instead of downscaled from one bitmap.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvas: CGFloat = 1024
/// Apple's macOS icon grid: the artwork sits on a 824 pt square inset by 100 pt.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)

/// Continuous-curvature ("squircle") rounded rect, which is what Apple's icons
/// use; a plain rounded rect looks noticeably boxier next to them.
func squircle(_ rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 360
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2 / n), st)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon(into context: CGContext) {
    let s = context.width > 0 ? CGFloat(context.width) / canvas : 1
    context.scaleBy(x: s, y: s)

    // Plate: graphite gradient with a light rim so it sits on light and dark
    // wallpapers alike.
    let platePath = squircle(plate)
    context.saveGState()
    context.addPath(platePath)
    context.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [rgb(0x46536B), rgb(0x1E2431)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: plate.midX, y: plate.maxY),
        end: CGPoint(x: plate.midX, y: plate.minY),
        options: []
    )
    context.restoreGState()

    context.addPath(platePath)
    context.setStrokeColor(rgb(0xFFFFFF, 0.16))
    context.setLineWidth(4)
    context.strokePath()

    // Trackpad.
    let pad = CGRect(x: 262, y: 330, width: 500, height: 372)
    let padPath = squircle(pad, exponent: 6)
    context.saveGState()
    context.addPath(padPath)
    context.setFillColor(rgb(0xE9EEF6, 0.94))
    context.fillPath()
    context.restoreGState()

    // Volume level: a track with the filled part growing upwards, like the
    // system HUD, centred so the icon reads the same at every size.
    let track = CGRect(x: pad.midX - 62, y: 358, width: 124, height: 316)
    context.addPath(CGPath(roundedRect: track, cornerWidth: 62, cornerHeight: 62, transform: nil))
    context.setFillColor(rgb(0x5C6880, 0.55))
    context.fillPath()

    let level: CGFloat = 0.62
    let filled = CGRect(
        x: track.minX,
        y: track.minY,
        width: track.width,
        height: (track.height * level).rounded()
    )
    context.saveGState()
    context.addPath(CGPath(roundedRect: filled, cornerWidth: 62, cornerHeight: 62, transform: nil))
    context.clip()
    let accent = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [rgb(0x1466D8), rgb(0x5FCBF4)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        accent,
        start: CGPoint(x: filled.midX, y: filled.minY),
        end: CGPoint(x: filled.midX, y: filled.maxY),
        options: []
    )
    context.restoreGState()
}

func render(size: Int) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    drawIcon(into: context)
    return context.makeImage()
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { throw NSError(domain: "icon", code: 1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "icon", code: 2) }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(name: String, size: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    guard let image = render(size: variant.size) else { fatalError("cannot render \(variant.size)") }
    try write(image, to: iconset.appendingPathComponent("\(variant.name).png"))
}

let icns = resources.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }

// A 1024 px copy lives next to the icns: the README shows it and it is the
// easiest way to look at the drawing when tweaking it.
try write(render(size: 1024)!, to: resources.appendingPathComponent("AppIcon.png"))
print("wrote \(icns.path)")
