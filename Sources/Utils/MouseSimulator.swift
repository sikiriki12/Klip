import Foundation
import CoreGraphics

/// Simulates mouse clicks using CGEvents
class MouseSimulator {
    
    /// Click at absolute screen coordinates
    /// - Parameters:
    ///   - x: X coordinate (screen space)
    ///   - y: Y coordinate (screen space)
    static func clickAt(x: CGFloat, y: CGFloat) {
        let point = CGPoint(x: x, y: y)
        
        // Mouse down
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        
        // Small delay
        usleep(50000) // 50ms
        
        // Mouse up
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
        
        print("🖱️ Clicked at (\(Int(x)), \(Int(y)))")
    }
}
