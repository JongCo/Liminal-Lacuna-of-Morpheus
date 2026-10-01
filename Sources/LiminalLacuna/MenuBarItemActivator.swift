import AppKit
import ApplicationServices

@MainActor
final class MenuBarItemActivator {
    enum Result {
        case activated
        case failed(String)
    }

    func activate(_ item: MenuBarItem, invocation: MenuBarInvocation) async -> Result {
        let action: CFString = switch invocation {
        case .primary:
            kAXPressAction as CFString
        case .secondary:
            kAXShowMenuAction as CFString
        }
        let observation = MenuOpeningObservation(pid: item.ownerPID, element: item.accessibilityElement)
        observation.start()
        defer {
            observation.stop()
        }

        let request = MenuBarActionRequest(element: item.accessibilityElement, action: action)
        let rawError = await Task.detached(priority: .userInitiated) {
            AXUIElementPerformAction(request.element, request.action).rawValue
        }.value
        let error = AXError(rawValue: rawError) ?? .failure
        observation.recordResult(ownerName: item.ownerName, error: error)
        switch error {
        case .success:
            return .activated
        case .cannotComplete:
            guard observation.didOpenMenu else {
                return .failed("\(item.ownerName)에서 접근성 요청을 완료하지 못했습니다. (AX 오류 \(error.rawValue))")
            }
            return .activated
        case .actionUnsupported:
            let actionName = invocation == .primary ? "기본 클릭" : "보조 클릭"
            return .failed("원본 항목이 \(actionName) 동작을 지원하지 않습니다. (AX 오류 \(error.rawValue))")
        default:
            return .failed("\(item.ownerName) 항목을 실행하는 중 접근성 오류가 발생했습니다. (AX 오류 \(error.rawValue))")
        }
    }
}

// AXUIElement and immutable CFString are retained for one worker's AX request.
private struct MenuBarActionRequest: @unchecked Sendable {
    let element: AXUIElement
    let action: CFString
}

@MainActor
private final class MenuOpeningObservation {
    private let pid: pid_t
    private let element: AXUIElement
    private let application: AXUIElement
    private var observer: AXObserver?
    private var registeredElements: [AXUIElement] = []
    private(set) var didOpenMenu = false
    private var confirmation = "none"
    private var notificationResults: [Int32] = []

    init(pid: pid_t, element: AXUIElement) {
        self.pid = pid
        self.element = element
        self.application = AXUIElementCreateApplication(pid)
    }

    func start() {
        var newObserver: AXObserver?
        let error = AXObserverCreate(pid, { _, _, _, context in
            guard let context else { return }
            MainActor.assumeIsolated {
                let observation = Unmanaged<MenuOpeningObservation>.fromOpaque(context).takeUnretainedValue()
                observation.didOpenMenu = true
                observation.confirmation = "AXMenuOpened"
            }
        }, &newObserver)
        guard error == .success, let newObserver else { return }
        observer = newObserver
        let context = Unmanaged.passUnretained(self).toOpaque()
        for target in [element, application] {
            let result = AXObserverAddNotification(newObserver, target, kAXMenuOpenedNotification as CFString, context)
            notificationResults.append(result.rawValue)
            if result == .success {
                registeredElements.append(target)
            }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
    }

    func stop() {
        guard let observer else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        for target in registeredElements {
            AXObserverRemoveNotification(observer, target, kAXMenuOpenedNotification as CFString)
        }
        self.observer = nil
    }

    func recordResult(ownerName: String, error: AXError) {
        #if DEBUG
        let line = "\(Date()) owner=\(ownerName) AX=\(error.rawValue) menu=\(confirmation) observer=\(notificationResults)\n"
        let url = URL(fileURLWithPath: "/tmp/liminal-lacuna-activation.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let file = try? FileHandle(forWritingTo: url) {
            defer { try? file.close() }
            _ = try? file.seekToEnd()
            try? file.write(contentsOf: Data(line.utf8))
        }
        #endif
    }

}
