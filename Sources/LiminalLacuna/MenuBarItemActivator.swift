import AppKit
import ApplicationServices

@MainActor
final class MenuBarItemActivator {
    enum Result {
        case activated
        case failed(String)
    }

    func activate(_ item: MenuBarItem, invocation: MenuBarInvocation) -> Result {
        let action: CFString = switch invocation {
        case .primary:
            kAXPressAction as CFString
        case .secondary:
            kAXShowMenuAction as CFString
        }
        let error = AXUIElementPerformAction(item.accessibilityElement, action)
        guard error == .success else {
            let actionName = invocation == .primary ? "기본 클릭" : "보조 클릭"
            return .failed("원본 항목이 \(actionName) 동작을 허용하지 않았습니다. (AX 오류 \(error.rawValue))")
        }
        return .activated
    }
}
