#if os(macOS)
import AppKit
#else
import SwiftUI
#endif

#if os(macOS)
@main
struct AccountActivityIOSApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AccountActivityIOSMacAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        installAppMenu(appName: "AccountActivityIOS")
        NSWindow.allowsAutomaticWindowTabbing = false
        app.activate(ignoringOtherApps: true)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
#else
@main
struct AccountActivityIOSApp: App {
    var body: some Scene {
        WindowGroup {
            AccountActivityView()
        }
    }
}
#endif
