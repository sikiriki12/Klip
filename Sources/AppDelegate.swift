import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    // Observe transcription state
    private var coordinator = TranscriptionCoordinator.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateStatusBarIcon(recording: false)
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusBarView())
        
        // Register global hotkey (Option + K)
        HotkeyManager.shared.registerHotkey { [weak self] in
            self?.handleHotkey()
        }
        
        // Observe recording state changes
        setupRecordingObserver()
        
        print("✅ Klip is running! Press ⌥K (Option+K) to start recording.")
        print("💡 Make sure to add your ElevenLabs API key in Settings first.")
    }
    
    private func setupRecordingObserver() {
        // Use a timer to poll state (simple approach for now)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateStatusBarIcon(recording: TranscriptionCoordinator.shared.isRecording)
        }
    }
    
    private func updateStatusBarIcon(recording: Bool) {
        guard let button = statusItem.button else { return }
        
        if recording {
            // Red microphone when recording
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")?
                .withSymbolConfiguration(config)
        } else {
            // Default microphone
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Klip")
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func handleHotkey() {
        print("⌨️ Hotkey pressed: ⌥K")
        TranscriptionCoordinator.shared.toggleRecording()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregisterHotkey()
    }
}
