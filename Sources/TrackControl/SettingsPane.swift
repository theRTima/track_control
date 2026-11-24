import AppKit
import TrackControlCore

/// Settings window contents: one popup per trackpad edge.
/// Plain AppKit, because SwiftUI's macros are not part of Command Line Tools.
@MainActor
final class SettingsPane: NSView {
    private let settings: Settings
    private var popups: [TrackpadSide: NSPopUpButton] = [:]
    private let accessibilityNotice = NSStackView()
    private let separator = NSBox()

    init(settings: Settings = .shared) {
        self.settings = settings
        super.init(frame: .zero)
        build()
        refreshAccessibilityNotice()
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

        separator.boxType = .separator
        stack.addArrangedSubview(separator)

        accessibilityNotice.orientation = .vertical
        accessibilityNotice.alignment = .leading
        accessibilityNotice.spacing = 6

        let noticeText = NSTextField(wrappingLabelWithString:
            "Keyboard brightness needs Accessibility access, because it presses the brightness keys for you.")
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
        popup.selectItem(withTitle: settings.action(for: side).title)
        popup.target = self
        popup.action = #selector(actionChanged(_:))
        popup.tag = TrackpadSide.allCases.firstIndex(of: side) ?? 0
        popup.widthAnchor.constraint(equalToConstant: Layout.popupWidth).isActive = true
        popups[side] = popup

        let row = NSStackView(views: [label, popup])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    @objc private func actionChanged(_ sender: NSPopUpButton) {
        let sides = TrackpadSide.allCases
        guard sides.indices.contains(sender.tag) else { return }
        let side = sides[sender.tag]
        let action = ControlAction.allCases.first { $0.title == sender.titleOfSelectedItem } ?? .none
        settings.set(action, for: side)
        refreshAccessibilityNotice()
    }

    @objc private func requestAccessibility() {
        AccessibilityPermission.request()
        refreshAccessibilityNotice()
    }

    private func refreshAccessibilityNotice() {
        let needed = popups.values.contains { popup in
            popup.titleOfSelectedItem == ControlAction.keyboardBrightness.title
        }
        let show = needed && !AccessibilityPermission.isGranted
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
