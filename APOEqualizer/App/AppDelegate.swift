import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = AudioEngineManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
