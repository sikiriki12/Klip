import Cocoa
import Carbon

/// Manages global keyboard shortcuts using Carbon Event Manager
class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotkeyRefs: [EventHotKeyRef] = []
    
    // Callbacks
    private var recordingCallback: (() -> Void)?
    private var modeCallback: ((Int) -> Void)?
    
    private init() {}
    
    /// Register all hotkeys
    /// - Parameters:
    ///   - onRecording: Called when ⌥K is pressed
    ///   - onModeSwitch: Called when ⌘1-5 is pressed, with the number
    func registerHotkeys(onRecording: @escaping () -> Void, onModeSwitch: @escaping (Int) -> Void) {
        self.recordingCallback = onRecording
        self.modeCallback = onModeSwitch
        
        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData, let event = event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            // Get hotkey ID
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            
            // ID 1 = recording, ID 2-6 = mode 1-5
            if hotkeyID.id == 1 {
                manager.recordingCallback?()
            } else if hotkeyID.id >= 2 && hotkeyID.id <= 6 {
                manager.modeCallback?(Int(hotkeyID.id) - 1)  // Convert to 1-5
            }
            
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, selfPtr, &eventHandler)
        
        // Register Option+K for recording (ID: 1)
        registerHotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey), id: 1, name: "⌥K")
        
        // Register ⌘1-5 for mode switching (ID: 2-6)
        let numberKeyCodes: [UInt32] = [
            UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3), 
            UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5)
        ]
        for (index, keyCode) in numberKeyCodes.enumerated() {
            registerHotkey(keyCode: keyCode, modifiers: UInt32(cmdKey), id: UInt32(index + 2), name: "⌘\(index + 1)")
        }
    }
    
    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, id: UInt32, name: String) {
        let hotkeyID = EventHotKeyID(signature: OSType(0x4B4C4950), id: id) // "KLIP"
        var hotkeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr, let ref = hotkeyRef {
            hotkeyRefs.append(ref)
            print("✅ Hotkey registered: \(name)")
        } else {
            print("❌ Failed to register \(name): \(status)")
        }
    }
    
    /// Unregister all hotkeys
    func unregisterHotkeys() {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        print("Hotkeys unregistered")
    }
    
    deinit {
        unregisterHotkeys()
    }
}
