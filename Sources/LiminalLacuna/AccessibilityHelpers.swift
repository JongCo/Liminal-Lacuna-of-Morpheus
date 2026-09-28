import AppKit
import ApplicationServices

enum AccessibilityHelpers {
    static func value<T>(of element: AXUIElement, attribute: CFString, as type: T.Type = T.self) -> T? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &rawValue)
        guard error == .success else {
            return nil
        }
        return rawValue as? T
    }

    static func string(of element: AXUIElement, attribute: CFString) -> String? {
        value(of: element, attribute: attribute, as: String.self)
    }

    static func point(of element: AXUIElement, attribute: CFString) -> CGPoint? {
        guard let value = value(of: element, attribute: attribute, as: AXValue.self),
              AXValueGetType(value) == .cgPoint
        else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    static func size(of element: AXUIElement, attribute: CFString) -> CGSize? {
        guard let value = value(of: element, attribute: attribute, as: AXValue.self),
              AXValueGetType(value) == .cgSize
        else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else {
            return nil
        }
        return size
    }

    static func children(of element: AXUIElement) -> [AXUIElement] {
        value(of: element, attribute: kAXChildrenAttribute as CFString, as: [AXUIElement].self) ?? []
    }
}
