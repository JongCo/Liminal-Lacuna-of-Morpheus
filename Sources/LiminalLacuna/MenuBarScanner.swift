import AppKit
import ApplicationServices

@MainActor
final class MenuBarScanner {
    func scan(excluding excludedPID: pid_t) -> [MenuBarItem] {
        var items: [MenuBarItem] = []
        var seen = Set<String>()

        for application in NSWorkspace.shared.runningApplications {
            let pid = application.processIdentifier
            guard pid != excludedPID, pid > 0 else {
                continue
            }

            let applicationElement = AXUIElementCreateApplication(pid)
            guard let extrasMenuBar: AXUIElement = AccessibilityHelpers.value(
                of: applicationElement,
                attribute: kAXExtrasMenuBarAttribute as CFString
            ) else {
                continue
            }

            let ownerName = application.localizedName ?? application.bundleIdentifier ?? "알 수 없는 앱"
            for element in menuBarItems(below: extrasMenuBar) {
                guard let item = makeItem(
                    from: element,
                    ownerPID: pid,
                    ownerName: ownerName
                ), seen.insert(item.id).inserted else {
                    continue
                }
                items.append(item)
            }
        }

        return items.sorted {
            if $0.frame.minX == $1.frame.minX {
                return $0.ownerName.localizedStandardCompare($1.ownerName) == .orderedAscending
            }
            return $0.frame.minX < $1.frame.minX
        }
    }

    private func menuBarItems(below root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue = AccessibilityHelpers.children(of: root).map { ($0, 0) }

        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            let role = AccessibilityHelpers.string(
                of: element,
                attribute: kAXRoleAttribute as CFString
            )

            if role == (kAXMenuBarItemRole as String) {
                result.append(element)
                continue
            }

            if depth < 3 {
                queue.append(contentsOf: AccessibilityHelpers.children(of: element).map { ($0, depth + 1) })
            }
        }

        return result
    }

    private func makeItem(
        from element: AXUIElement,
        ownerPID: pid_t,
        ownerName: String
    ) -> MenuBarItem? {
        guard let position = AccessibilityHelpers.point(
            of: element,
            attribute: kAXPositionAttribute as CFString
        ), let size = AccessibilityHelpers.size(
            of: element,
            attribute: kAXSizeAttribute as CFString
        ), size.width > 0, size.height > 0 else {
            return nil
        }

        let frame = CGRect(origin: position, size: size)
        let title = firstNonemptyString(
            AccessibilityHelpers.string(of: element, attribute: kAXTitleAttribute as CFString),
            AccessibilityHelpers.string(of: element, attribute: kAXDescriptionAttribute as CFString),
            AccessibilityHelpers.string(of: element, attribute: kAXHelpAttribute as CFString),
            ownerName
        )
        let identifier = firstNonemptyString(
            AccessibilityHelpers.string(of: element, attribute: kAXIdentifierAttribute as CFString),
            title
        )
        let id = "\(ownerPID)|\(identifier)|\(Int(frame.minX))|\(Int(frame.width))"
        let snapshotKey = "\(ownerPID)|\(identifier)"

        return MenuBarItem(
            id: id,
            snapshotKey: snapshotKey,
            ownerPID: ownerPID,
            ownerName: ownerName,
            title: title,
            frame: frame,
            icon: fallbackIcon,
            accessibilityElement: element
        )
    }

    private func firstNonemptyString(_ candidates: String?...) -> String {
        candidates.compactMap { $0 }.first { value in
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? "메뉴 막대 항목"
    }

    private var fallbackIcon: NSImage {
        NSImage(systemSymbolName: "circle", accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 20, height: 20))
    }
}
