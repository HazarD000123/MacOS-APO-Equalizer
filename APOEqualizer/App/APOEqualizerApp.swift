import SwiftUI

@main
struct APOEqualizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    private var colorScheme: ColorScheme? {
        (AppearanceMode(rawValue: appearanceModeRaw) ?? .system).colorScheme
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appDelegate.engine)
                .frame(minWidth: 880, minHeight: 620)
                .preferredColorScheme(colorScheme)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("APO Equalizer", systemImage: "slider.horizontal.3") {
            MenuBarView()
                .environmentObject(appDelegate.engine)
                .preferredColorScheme(colorScheme)
        }
        .menuBarExtraStyle(.window)
    }
}
