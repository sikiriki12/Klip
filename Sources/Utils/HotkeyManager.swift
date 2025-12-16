import Cocoa
import Carbon

/// Manages global keyboard shortcuts using Carbon Event Manager
class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotkeyRefs: [EventHotKeyRef] = []
    
    // Callbacks
    // Bool parameter: true = invert silence setting
    private var recordingCallback: ((Bool) -> Void)?
    private var modeCallback: ((Int) -> Void)?
    
    private init() {}
    
    /// Register all hotkeys
    /// - Parameters:
    ///   - onRecording: Called when ⌥K or ⇧⌥K is pressed. Bool = true to invert silence setting.
    ///   - onModeSwitch: Called when ⌘1-5 is pressed, with the number
    func registerHotkeys(onRecording: @escaping (Bool) -> Void, onModeSwitch: @escaping (Int) -> Void) {
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
            
            // ID 1 = recording (⌥K), ID 100 = recording inverted (⇧⌥K), ID 2-10 = mode 1-9
            if hotkeyID.id == 1 {
                manager.recordingCallback?(false)  // Normal mode
            } else if hotkeyID.id == 100 {
                manager.recordingCallback?(true)   // Inverted silence mode
            } else if hotkeyID.id >= 2 && hotkeyID.id <= 10 {
                manager.modeCallback?(Int(hotkeyID.id) - 1)  // Convert to 1-9
            }
            
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, selfPtr, &eventHandler)
        
        // Register Option+K for recording (ID: 1) - normal mode
        registerHotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey), id: 1, name: "⌥K")
        
        // Register Shift+Option+K for recording with inverted silence (ID: 100 - avoid collision with ⌘6)
        registerHotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey | shiftKey), id: 100, name: "⇧⌥K")
        
        // Register ⌘1-9 for mode switching (ID: 2-10)
        let numberKeyCodes: [UInt32] = [
            UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3), 
            UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5), UInt32(kVK_ANSI_6),
            UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9)
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
