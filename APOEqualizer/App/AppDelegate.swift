import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = AudioEngineManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Release the mic/BlackHole engines cleanly if the app quits while running.
        engine.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
