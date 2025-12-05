import Cocoa
import Carbon

/// Manages global keyboard shortcuts using Carbon Event Manager
class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyCallback: (() -> Void)?
    
    // Hotkey ID
    private let hotkeyID = EventHotKeyID(signature: OSType(0x4B4C4950), id: 1) // "KLIP"
    
    private init() {}
    
    /// Register Option+K as the global hotkey
    func registerHotkey(callback: @escaping () -> Void) {
        self.hotkeyCallback = callback
        
        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.hotkeyCallback?()
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, selfPtr, &eventHandler)
        
        // Register Option+K (keycode 40 = 'k', optionKey modifier)
        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_K),      // 'K' key
            UInt32(optionKey),        // Option modifier
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr {
            self.hotkeyRef = hotkeyRef
            print("✅ Hotkey registered: ⌥K (Option+K)")
        } else {
            print("❌ Failed to register hotkey: \(status)")
        }
    }
    
    /// Unregister the hotkey
    func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        print("Hotkey unregistered")
    }
    
    deinit {
        unregisterHotkey()
    }
}
