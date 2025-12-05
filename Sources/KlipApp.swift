import SwiftUI

@main
struct KlipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We use a menu bar app, so no main window
        Settings {
            SettingsView()
        }
    }
}
