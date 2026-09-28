import AppKit

@MainActor
final class MenuBarPanelController: NSObject {
    private enum Layout {
        static let itemSize = NSSize(width: 34, height: 34)
        static let itemSpacing: CGFloat = 6
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 9
        static let emptyWidth: CGFloat = 180
    }

    private let panel: NSPanel
    private let stackView = NSStackView()
    private let onSelect: (MenuBarItem, MenuBarInvocation) -> Void
    private var outsideClickMonitor: Any?

    var isVisible: Bool {
        panel.isVisible
    }

    init(onSelect: @escaping (MenuBarItem, MenuBarInvocation) -> Void) {
        self.onSelect = onSelect
        self.panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
    }

    func present(items: [MenuBarItem], relativeTo button: NSStatusBarButton) {
        rebuildContent(with: items)

        guard let anchorWindow = button.window,
              let screen = anchorWindow.screen ?? NSScreen.main else {
            return
        }

        let panelSize = desiredSize(itemCount: items.count, screen: screen)
        let anchorFrame = anchorWindow.frame
        let x = min(
            max(anchorFrame.maxX - panelSize.width, screen.visibleFrame.minX + 4),
            screen.visibleFrame.maxX - panelSize.width - 4
        )
        let finalOrigin = NSPoint(
            x: x,
            y: anchorFrame.minY - panelSize.height - 4
        )

        panel.setFrame(NSRect(origin: finalOrigin, size: panelSize), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.setFrameOrigin(NSPoint(x: finalOrigin.x, y: finalOrigin.y + 8))

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(finalOrigin)
        }

        installOutsideClickMonitor()
    }

    func close() {
        guard panel.isVisible else {
            return
        }

        removeOutsideClickMonitor()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
            }
        }
    }

    private func configurePanel() {
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 11
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.spacing = Layout.itemSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        effectView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: Layout.horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -Layout.horizontalPadding),
            stackView.topAnchor.constraint(equalTo: effectView.topAnchor, constant: Layout.verticalPadding),
            stackView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -Layout.verticalPadding)
        ])
        panel.contentView = effectView
    }

    private func rebuildContent(with items: [MenuBarItem]) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if items.isEmpty {
            let label = NSTextField(labelWithString: "메뉴 막대 항목이 없습니다")
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            stackView.addArrangedSubview(label)
            return
        }

        for item in items {
            let button = ActionButton(frame: NSRect(origin: .zero, size: Layout.itemSize))
            button.bezelStyle = .texturedRounded
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.image = item.icon
            button.toolTip = item.title == item.ownerName ? item.ownerName : "\(item.ownerName) — \(item.title)"
            button.onPress = { [weak self] in
                self?.onSelect(item, .primary)
            }
            button.onSecondaryPress = { [weak self] in
                self?.onSelect(item, .secondary)
            }
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: Layout.itemSize.width),
                button.heightAnchor.constraint(equalToConstant: Layout.itemSize.height)
            ])
            stackView.addArrangedSubview(button)
        }
    }

    private func desiredSize(itemCount: Int, screen: NSScreen) -> NSSize {
        return NSSize(
            width: PanelLayoutMetrics.width(
                itemCount: itemCount,
                itemWidth: Layout.itemSize.width,
                spacing: Layout.itemSpacing,
                horizontalPadding: Layout.horizontalPadding,
                emptyWidth: Layout.emptyWidth,
                maximumWidth: screen.visibleFrame.width - 8
            ),
            height: Layout.itemSize.height + Layout.verticalPadding * 2
        )
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else {
            return
        }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}

@MainActor
private final class ActionButton: NSButton {
    var onPress: (() -> Void)?
    var onSecondaryPress: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(pressed)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pressed() {
        onPress?()
    }

    override func rightMouseUp(with event: NSEvent) {
        onSecondaryPress?()
    }
}
