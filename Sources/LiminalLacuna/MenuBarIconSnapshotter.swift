import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class MenuBarIconSnapshotter {
    private let statusWindowLevel = Int(CGWindowLevelForKey(.statusWindow))
    private var cache: [String: NSImage] = [:]

    var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenCapturePermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func notchClippedItems(from items: [MenuBarItem]) async -> [MenuBarItem] {
        guard hasScreenCapturePermission else {
            return []
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
            let statusWindows = content.windows.filter {
                $0.windowLayer == statusWindowLevel
            }
            var clippedItems: [MenuBarItem] = []

            for item in items {
                guard let window = matchingWindow(for: item, in: statusWindows),
                      !window.isOnScreen
                else {
                    continue
                }

                let image: NSImage
                do {
                    image = try await capture(window: window)
                } catch {
                    if let cached = cache[item.snapshotKey] {
                        item.replaceIcon(with: cached)
                        clippedItems.append(item)
                    }
                    continue
                }

                cache[item.snapshotKey] = image
                item.replaceIcon(with: image)
                clippedItems.append(item)
            }
            return clippedItems
        } catch {
            return []
        }
    }

    private func matchingWindow(for item: MenuBarItem, in windows: [SCWindow]) -> SCWindow? {
        windows
            .compactMap { window -> (SCWindow, CGFloat)? in
                guard let score = MenuBarWindowMatcher.score(
                    itemFrame: item.frame,
                    windowFrame: window.frame
                ) else {
                    return nil
                }
                return (window, score)
            }
            .min { lhs, rhs in
                lhs.1 < rhs.1
            }?
            .0
    }
}

struct MenuBarWindowMatcher {
    static func score(itemFrame: CGRect, windowFrame: CGRect) -> CGFloat? {
        let tolerance: CGFloat = 2
        let expandedWindow = windowFrame.insetBy(dx: -tolerance, dy: -tolerance)
        guard expandedWindow.contains(
            CGPoint(x: itemFrame.midX, y: itemFrame.midY)
        ) else {
            return nil
        }

        return abs(itemFrame.midX - windowFrame.midX)
            + abs(itemFrame.midY - windowFrame.midY)
            + max(0, windowFrame.width - itemFrame.width) * 0.01
    }
}

private extension MenuBarIconSnapshotter {
    func capture(window: SCWindow) async throws -> NSImage {
        let scale = backingScaleFactor(for: window.frame)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((window.frame.width * scale).rounded()))
        configuration.height = max(1, Int((window.frame.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        return NSImage(cgImage: image, size: window.frame.size)
    }

    func backingScaleFactor(for frame: CGRect) -> CGFloat {
        guard let screen = NSScreen.screens.first(where: { screen in
            frame.midX >= screen.frame.minX && frame.midX <= screen.frame.maxX
        }) else {
            return NSScreen.main?.backingScaleFactor ?? 2
        }
        return screen.backingScaleFactor
    }

}
