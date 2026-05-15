#if os(macOS)
import AppKit
#else
import SwiftUI
#endif

#if os(macOS)
@main
struct AirdropIOSApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AirdropIOSMacAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        installAppMenu(appName: "AirdropIOS")
        NSWindow.allowsAutomaticWindowTabbing = false
        app.activate(ignoringOtherApps: true)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
#else
@main
struct AirdropIOSApp: App {
    var body: some Scene {
        WindowGroup {
            AirdropRequestView()
        }
    }
}
#endif
