import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?
    private let settings = SettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController(settings: settings)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
