import AppKit
import ApplicationServices

@MainActor
final class MenuBarItem: Identifiable {
    let id: String
    let ownerPID: pid_t
    let ownerName: String
    let title: String
    let frame: CGRect
    let icon: NSImage
    let accessibilityElement: AXUIElement

    init(
        id: String,
        ownerPID: pid_t,
        ownerName: String,
        title: String,
        frame: CGRect,
        icon: NSImage,
        accessibilityElement: AXUIElement
    ) {
        self.id = id
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.title = title
        self.frame = frame
        self.icon = icon
        self.accessibilityElement = accessibilityElement
    }

    var isOnScreen: Bool {
        NSScreen.screens.contains { screen in
            screen.frame.intersects(frame) && frame.midX >= screen.frame.minX && frame.midX <= screen.frame.maxX
        }
    }
}
