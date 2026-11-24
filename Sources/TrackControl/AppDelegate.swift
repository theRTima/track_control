import AppKit
import TrackControlCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let monitor = GestureMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        Debug.log("accessibility granted: \(AccessibilityPermission.isGranted)")

        // Blocking the scroll during a swipe needs Accessibility access, so ask
        // for it once instead of silently doing less than expected.
        if !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
        }

        if !monitor.start() {
            Debug.log("gesture monitor failed to start")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.icon()
        item.button?.toolTip = "Track Control"

        let menu = NSMenu()
        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit Track Control", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private static func icon() -> NSImage? {
        let symbol = NSImage(systemSymbolName: "rectangle.and.hand.point.up.left", accessibilityDescription: "Track Control")
            ?? NSImage(systemSymbolName: "hand.draw", accessibilityDescription: "Track Control")
        symbol?.isTemplate = true
        return symbol
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let pane = SettingsPane()
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Track Control"
            window.contentView = pane
            window.setContentSize(window.contentView?.fittingSize ?? NSSize(width: 380, height: 260))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
