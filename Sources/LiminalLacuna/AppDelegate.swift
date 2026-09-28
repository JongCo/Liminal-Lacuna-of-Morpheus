import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let scanner = MenuBarScanner()
    private let activator = MenuBarItemActivator()
    private let hiddenSection = HiddenSectionController()
    private lazy var panelController = MenuBarPanelController { [weak self] item, invocation in
        self?.activate(item, invocation: invocation)
    }

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hiddenSection.install()
        configureStatusItem()
        if AXIsProcessTrusted() {
            hiddenSection.collapse()
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = HiddenSectionController.mainAutosaveName

        guard let button = item.button else {
            return
        }

        button.image = NSImage(
            systemSymbolName: "rectangle.bottomhalf.inset.filled",
            accessibilityDescription: "메뉴 막대 확장"
        )
        button.image?.isTemplate = true
        button.toolTip = "Liminal Lacuna"
        button.target = self
        button.action = #selector(statusItemPressed(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusItem = item
    }

    @objc private func statusItemPressed(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        togglePanel(from: sender)
    }

    private func togglePanel(from button: NSStatusBarButton) {
        if panelController.isVisible {
            panelController.close()
            return
        }

        guard ensureAccessibilityPermission() else {
            showPermissionExplanation()
            return
        }

        hiddenSection.collapse()
        let items = scanner.scan(excluding: ProcessInfo.processInfo.processIdentifier)
        panelController.present(items: items, relativeTo: button)
    }

    private func activate(_ item: MenuBarItem, invocation: MenuBarInvocation) {
        panelController.close()

        hiddenSection.reveal()
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(140))
            let result = activator.activate(item, invocation: invocation)
            if case let .failed(message) = result {
                hiddenSection.collapse()
                presentError(message)
                return
            }
            hiddenSection.collapseAfterNextInteraction()
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func showPermissionExplanation() {
        let alert = NSAlert()
        alert.messageText = "손쉬운 사용 권한이 필요합니다"
        alert.informativeText = "다른 앱의 메뉴 막대 항목을 찾고 원래 동작을 실행하려면 시스템 설정의 개인정보 보호 및 보안 > 손쉬운 사용에서 Liminal Lacuna를 허용해 주세요."
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "메뉴 막대 항목을 열 수 없습니다"
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    private func showContextMenu() {
        guard let statusItem else {
            return
        }

        let menu = NSMenu()
        let visibilityTitle = hiddenSection.isCollapsed ? "원본 아이콘 보기" : "원본 아이콘 숨기기"
        menu.addItem(
            withTitle: visibilityTitle,
            action: #selector(toggleOriginalItems),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "손쉬운 사용 설정 열기",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "종료",
            action: #selector(terminate),
            keyEquivalent: "q"
        ).target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleOriginalItems() {
        panelController.close()
        hiddenSection.toggle()
    }

    @objc private func terminate() {
        NSApp.terminate(nil)
    }
}
