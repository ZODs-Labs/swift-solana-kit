import AppKit

@main
struct BalanceMacApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = BalanceMacAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        NSWindow.allowsAutomaticWindowTabbing = false
        app.activate(ignoringOtherApps: true)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
