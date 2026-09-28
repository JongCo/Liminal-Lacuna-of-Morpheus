import AppKit

@MainActor
final class HiddenSectionController {
    static let mainAutosaveName = "LiminalLacuna.MainStatusItem"
    static let spacerAutosaveName = "LiminalLacuna.HiddenSectionSpacer"

    private enum Length {
        static let revealed = NSStatusItem.variableLength
        static let collapsed: CGFloat = 10_000
    }

    private(set) var isCollapsed = false
    private var spacerItem: NSStatusItem?
    private var interactionMonitor: Any?
    private var fallbackTimer: Timer?

    func install() {
        setInitialPreferredPositions()

        let item = NSStatusBar.system.statusItem(withLength: Length.revealed)
        item.autosaveName = Self.spacerAutosaveName
        item.button?.image = nil
        item.button?.title = ""
        item.button?.isEnabled = false
        spacerItem = item
    }

    func collapse() {
        cancelScheduledCollapse()
        spacerItem?.length = Length.collapsed
        isCollapsed = true
    }

    func reveal() {
        cancelScheduledCollapse()
        spacerItem?.length = Length.revealed
        isCollapsed = false
    }

    func toggle() {
        isCollapsed ? reveal() : collapse()
    }

    /// Keeps the original item available while its menu is in use. The next user
    /// interaction usually means the menu has been dismissed or a command selected.
    /// A timer is retained as a fallback for keyboard-only or custom interfaces.
    func collapseAfterNextInteraction() {
        cancelScheduledCollapse()

        interactionMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                self?.collapse()
            }
        }

        fallbackTimer = .scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.collapse()
            }
        }
    }

    private func cancelScheduledCollapse() {
        if let interactionMonitor {
            NSEvent.removeMonitor(interactionMonitor)
            self.interactionMonitor = nil
        }
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    private func setInitialPreferredPositions() {
        let defaults = UserDefaults.standard
        let mainKey = "NSStatusItem Preferred Position \(Self.mainAutosaveName)"
        let spacerKey = "NSStatusItem Preferred Position \(Self.spacerAutosaveName)"

        if defaults.object(forKey: mainKey) == nil {
            defaults.set(0.0, forKey: mainKey)
        }
        if defaults.object(forKey: spacerKey) == nil {
            defaults.set(1.0, forKey: spacerKey)
        }
    }
}
