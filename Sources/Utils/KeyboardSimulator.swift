import Foundation
import CoreGraphics

/// Simulates keyboard input using CGEvents
class KeyboardSimulator {
    
    // MARK: - Key Codes
    
    /// Common key codes for macOS
    enum KeyCode: CGKeyCode {
        case a = 0
        case b = 11
        case c = 8
        case d = 2
        case e = 14
        case f = 3
        case g = 5
        case h = 4
        case i = 34
        case j = 38
        case k = 40
        case l = 37
        case m = 46
        case n = 45
        case o = 31
        case p = 35
        case q = 12
        case r = 15
        case s = 1
        case t = 17
        case u = 32
        case v = 9
        case w = 13
        case x = 7
        case y = 16
        case z = 6
        
        case returnKey = 36
        case tab = 48
        case space = 49
        case delete = 51
        case escape = 53
        
        case command = 55
        case shift = 56
        case option = 58
        case control = 59
    }
    
    // MARK: - Public Methods
    
    /// Press a key with optional modifiers
    /// - Parameters:
    ///   - key: The key to press
    ///   - modifiers: Modifier flags (command, shift, option, control)
    static func pressKey(_ key: KeyCode, modifiers: CGEventFlags = []) {
        pressKey(key.rawValue, modifiers: modifiers)
    }
    
    /// Press a key by raw key code with optional modifiers
    static func pressKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)
        
        // Small delay between down and up
        usleep(10000) // 10ms
        
        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)
    }
    
    /// Type a string by pressing each character
    static func typeString(_ string: String) {
        for char in string {
            if let keyCode = keyCodeForCharacter(char) {
                let needsShift = char.isUppercase || "~!@#$%^&*()_+{}|:\"<>?".contains(char)
                pressKey(keyCode, modifiers: needsShift ? .maskShift : [])
                usleep(20000) // 20ms between characters
            }
        }
    }
    
    /// Paste from clipboard (Cmd+V)
    static func paste() {
        pressKey(.v, modifiers: .maskCommand)
    }
    
    // MARK: - Private Helpers
    
    private static func keyCodeForCharacter(_ char: Character) -> CGKeyCode? {
        let lowercased = char.lowercased().first!
        
        switch lowercased {
        case "a": return KeyCode.a.rawValue
        case "b": return KeyCode.b.rawValue
        case "c": return KeyCode.c.rawValue
        case "d": return KeyCode.d.rawValue
        case "e": return KeyCode.e.rawValue
        case "f": return KeyCode.f.rawValue
        case "g": return KeyCode.g.rawValue
        case "h": return KeyCode.h.rawValue
        case "i": return KeyCode.i.rawValue
        case "j": return KeyCode.j.rawValue
        case "k": return KeyCode.k.rawValue
        case "l": return KeyCode.l.rawValue
        case "m": return KeyCode.m.rawValue
        case "n": return KeyCode.n.rawValue
        case "o": return KeyCode.o.rawValue
        case "p": return KeyCode.p.rawValue
        case "q": return KeyCode.q.rawValue
        case "r": return KeyCode.r.rawValue
        case "s": return KeyCode.s.rawValue
        case "t": return KeyCode.t.rawValue
        case "u": return KeyCode.u.rawValue
        case "v": return KeyCode.v.rawValue
        case "w": return KeyCode.w.rawValue
        case "x": return KeyCode.x.rawValue
        case "y": return KeyCode.y.rawValue
        case "z": return KeyCode.z.rawValue
        case " ": return KeyCode.space.rawValue
        case "\n": return KeyCode.returnKey.rawValue
        case "\t": return KeyCode.tab.rawValue
        default: return nil
        }
    }
}
