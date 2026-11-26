import AppKit
import TrackControlCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let monitor = GestureMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyMenuBarVisibility()
        Debug.log("accessibility granted: \(AccessibilityPermission.isGranted)")

        // With no menu bar icon there is nothing to click, so launch into the
        // settings window instead of an invisible process.
        if statusItem == nil {
            openSettings()
        }

        if !monitor.start() {
            Debug.log("gesture monitor failed to start")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    /// Returning from System Settings is how a grant arrives; pick it up without
    /// asking for anything up front.
    func applicationDidBecomeActive(_ notification: Notification) {
        monitor.refreshScrollSuppression()
    }

    /// Opening the running app again is the way back when the icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if statusItem == nil {
            openSettings()
        }
        return true
    }

    private func applyMenuBarVisibility() {
        if Settings.shared.showMenuBarIcon {
            if statusItem == nil { setUpStatusItem() }
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            Debug.log("menu bar icon hidden")
        }
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
            pane.onMenuBarIconChanged = { [weak self] _ in self?.applyMenuBarVisibility() }
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
