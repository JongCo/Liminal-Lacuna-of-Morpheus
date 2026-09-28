import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum StatusItemConfiguration {
        static let autosaveName = "LiminalLacuna.MainStatusItem"
    }

    private let scanner = MenuBarScanner()
    private let iconSnapshotter = MenuBarIconSnapshotter()
    private let activator = MenuBarItemActivator()
    private lazy var panelController = MenuBarPanelController { [weak self] item, invocation in
        self?.activate(item, invocation: invocation)
    }

    private var statusItem: NSStatusItem?
    private var isPreparingPanel = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = StatusItemConfiguration.autosaveName

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

        guard ensureScreenCapturePermission() else {
            showScreenCapturePermissionExplanation()
            return
        }

        guard !isPreparingPanel else {
            return
        }
        isPreparingPanel = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isPreparingPanel = false }

            let scannedItems = scanner.scan(excluding: ProcessInfo.processInfo.processIdentifier)
            let clippedItems = await iconSnapshotter.notchClippedItems(from: scannedItems)
            panelController.present(items: clippedItems, relativeTo: button)
        }
    }

    private func activate(_ item: MenuBarItem, invocation: MenuBarInvocation) {
        panelController.close()

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(100))
            let result = activator.activate(item, invocation: invocation)
            if case let .failed(message) = result {
                presentError(message)
            }
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func ensureScreenCapturePermission() -> Bool {
        if iconSnapshotter.hasScreenCapturePermission {
            return true
        }
        return iconSnapshotter.requestScreenCapturePermission()
    }

    private func showPermissionExplanation() {
        let alert = NSAlert()
        alert.messageText = "손쉬운 사용 권한이 필요합니다"
        alert.informativeText = "다른 앱의 메뉴 막대 항목을 찾고 원래 동작을 실행하려면 시스템 설정의 개인정보 보호 및 보안 > 손쉬운 사용에서 Liminal Lacuna를 허용해 주세요."
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    private func showScreenCapturePermissionExplanation() {
        let alert = NSAlert()
        alert.messageText = "화면 기록 권한이 필요합니다"
        alert.informativeText = "메뉴 막대에 실제로 그려진 아이콘을 그대로 가져오려면 시스템 설정의 개인정보 보호 및 보안 > 화면 및 시스템 오디오 녹화에서 Liminal Lacuna를 허용해 주세요. 허용한 뒤 앱을 다시 실행해 주세요."
        alert.addButton(withTitle: "설정 열기")
        alert.addButton(withTitle: "나중에")
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenCaptureSettings()
        }
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
        menu.addItem(
            withTitle: "손쉬운 사용 설정 열기",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "화면 기록 설정 열기",
            action: #selector(openScreenCaptureSettings),
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

    @objc private func openScreenCaptureSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func terminate() {
        NSApp.terminate(nil)
    }
}
