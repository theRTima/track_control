// Renders the settings window into Resources/settings-window.png, so the README
// can show the app without needing Screen Recording permission.
//
//   swiftc -O scripts/make-screenshot.swift Sources/TrackControl/SettingsPane.swift \
//       Sources/TrackControlCore/*.swift Sources/TrackControlCore/Controls/*.swift \
//       -o /tmp/settings-shot && /tmp/settings-shot
//
// The picture comes from the same `SettingsPane` the app puts in its window, so
// it cannot drift away from the real UI.

import AppKit

@main
struct SettingsShot {
    @MainActor
    static func main() {
        // Defaults of a fresh install: the script has its own bundle id, so it
        // reads nothing from the user's Track Control settings.
        let pane = SettingsPane()
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Track Control"
        window.contentView = pane
        window.setContentSize(pane.fittingSize)
        // Offscreen, so running this does not put a window in the way.
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        // The window has to be key, otherwise macOS draws the traffic lights
        // greyed out as if the window were in the background.
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // Let AppKit lay out and draw the title bar before grabbing pixels.
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        pane.layoutSubtreeIfNeeded()
        guard let frameView = pane.superview else { fatalError("no window frame view") }
        frameView.layoutSubtreeIfNeeded()

        let scale: CGFloat = 2
        let bounds = frameView.bounds
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width * scale),
            pixelsHigh: Int(bounds.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { fatalError("no bitmap") }
        rep.size = bounds.size
        frameView.cacheDisplay(in: bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let out = root.appendingPathComponent("Resources/settings-window.png")
        try! png.write(to: out)
        print("wrote \(out.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")

        window.orderOut(nil)
    }
}
