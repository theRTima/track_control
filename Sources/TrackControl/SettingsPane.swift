import AppKit
import TrackControlCore

/// Settings window contents: one popup per trackpad edge.
/// Plain AppKit, because SwiftUI's macros are not part of Command Line Tools.
@MainActor
final class SettingsPane: NSView {
    private let settings: Settings
    private var popups: [TrackpadSide: NSPopUpButton] = [:]
    /// Called when the menu bar icon checkbox changes.
    var onMenuBarIconChanged: ((Bool) -> Void)?
    private let zoneSlider = NSSlider()
    private let zoneValue = NSTextField(labelWithString: "")
    private let accessibilityNotice = NSStackView()
    private let separator = NSBox()

    init(settings: Settings = .shared) {
        self.settings = settings
        super.init(frame: .zero)
        build()
        refreshAccessibilityNotice()
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification, object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let header = NSTextField(labelWithString: "Swipe with two fingers along the edge of the trackpad.")
        header.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        header.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [header])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12

        for side in TrackpadSide.allCases {
            stack.addArrangedSubview(row(for: side))
        }

        stack.addArrangedSubview(zoneRow())
        stack.addArrangedSubview(menuBarIconCheckbox())

        separator.boxType = .separator
        stack.addArrangedSubview(separator)

        accessibilityNotice.orientation = .vertical
        accessibilityNotice.alignment = .leading
        accessibilityNotice.spacing = 6

        let noticeText = NSTextField(wrappingLabelWithString:
            "Accessibility access is needed to keep the window from scrolling while you swipe, and for keyboard brightness, which presses the brightness keys for you.")
        noticeText.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        noticeText.textColor = .secondaryLabelColor
        noticeText.preferredMaxLayoutWidth = Layout.contentWidth

        let grantButton = NSButton(
            title: "Open Accessibility settings…",
            target: self,
            action: #selector(requestAccessibility)
        )
        accessibilityNotice.addArrangedSubview(noticeText)
        accessibilityNotice.addArrangedSubview(grantButton)
        stack.addArrangedSubview(accessibilityNotice)

        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.padding),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.padding),
            widthAnchor.constraint(equalToConstant: Layout.contentWidth + Layout.padding * 2),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func row(for side: TrackpadSide) -> NSView {
        let label = NSTextField(labelWithString: side.title)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: Layout.labelWidth).isActive = true

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        for action in ControlAction.allCases {
            let item = NSMenuItem(title: action.title, action: nil, keyEquivalent: "")
            item.representedObject = action.rawValue
            popup.menu?.addItem(item)
        }
        let current = settings.action(for: side).rawValue
        popup.select(popup.itemArray.first { ($0.representedObject as? String) == current })
        popup.target = self
        popup.action = #selector(actionChanged(_:))
        popup.widthAnchor.constraint(equalToConstant: Layout.popupWidth).isActive = true
        popups[side] = popup

        let row = NSStackView(views: [label, popup])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    private func zoneRow() -> NSView {
        let label = NSTextField(labelWithString: "Edge zone")
        label.widthAnchor.constraint(equalToConstant: Layout.labelWidth).isActive = true

        zoneSlider.minValue = Double(Settings.edgeZoneRange.lowerBound * 100)
        zoneSlider.maxValue = Double(Settings.edgeZoneRange.upperBound * 100)
        zoneSlider.doubleValue = Double(settings.edgeZone * 100)
        zoneSlider.isContinuous = true
        zoneSlider.target = self
        zoneSlider.action = #selector(zoneChanged(_:))
        zoneSlider.toolTip = "How far from the edge two fingers have to start to control a setting."
        zoneSlider.widthAnchor.constraint(equalToConstant: Layout.popupWidth - 40).isActive = true

        zoneValue.stringValue = Self.percentLabel(settings.edgeZone)
        zoneValue.textColor = .secondaryLabelColor
        zoneValue.alignment = .right
        zoneValue.widthAnchor.constraint(equalToConstant: 40).isActive = true

        let row = NSStackView(views: [label, zoneSlider, zoneValue])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    private func menuBarIconCheckbox() -> NSView {
        let checkbox = NSButton(
            checkboxWithTitle: "Show icon in the menu bar",
            target: self,
            action: #selector(menuBarIconToggled(_:))
        )
        checkbox.state = settings.showMenuBarIcon ? .on : .off
        return checkbox
    }

    @objc private func menuBarIconToggled(_ sender: NSButton) {
        let visible = sender.state == .on
        settings.showMenuBarIcon = visible
        onMenuBarIconChanged?(visible)
    }

    @objc private func zoneChanged(_ sender: NSSlider) {
        let zone = Float(sender.doubleValue / 100)
        settings.edgeZone = zone
        zoneValue.stringValue = Self.percentLabel(settings.edgeZone)
    }

    private static func percentLabel(_ zone: Float) -> String {
        "\(Int((zone * 100).rounded()))%"
    }

    @objc private func actionChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let action = ControlAction(rawValue: raw),
              let side = popups.first(where: { $0.value === sender })?.key
        else { return }
        settings.set(action, for: side)
        // Picking a setting that presses keys is the moment the permission is
        // actually needed; until then nothing is asked for.
        if action.needsAccessibility, !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
        }
        refreshAccessibilityNotice()
    }

    @objc private func appDidBecomeActive() {
        refreshAccessibilityNotice()
    }

    @objc private func requestAccessibility() {
        AccessibilityPermission.request()
        refreshAccessibilityNotice()
    }

    private func refreshAccessibilityNotice() {
        let show = !AccessibilityPermission.isGranted
        separator.isHidden = !show
        accessibilityNotice.isHidden = !show
    }

    private enum Layout {
        static let padding: CGFloat = 20
        static let contentWidth: CGFloat = 340
        static let labelWidth: CGFloat = 64
        static let popupWidth: CGFloat = 210
    }
}
