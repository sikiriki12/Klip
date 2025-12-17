import Foundation
import AppKit
import ApplicationServices

/// Detects browser state and current URL via Accessibility API
class BrowserDetector {
    static let shared = BrowserDetector()
    
    /// Known browser bundle identifiers
    private let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "com.brave.Browser",
        "company.thebrowser.Browser", // Arc
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi"
    ]
    
    private init() {}
    
    /// Get bundle ID of the frontmost application
    func getFrontmostAppBundleId() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    /// Get the bounds (position and size) of the frontmost window
    func getFrontmostWindowBounds() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = getFirstWindow(axApp) else { return nil }
        
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        
        return CGRect(origin: position, size: size)
    }
    
    /// Check if the frontmost app is a known browser
    func isBrowser() -> Bool {
        guard let bundleId = getFrontmostAppBundleId() else { return false }
        return browserBundleIds.contains(bundleId)
    }
    
    /// Get the current URL from the browser's address bar via Accessibility API
    func getBrowserURL() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        guard browserBundleIds.contains(app.bundleIdentifier ?? "") else { return nil }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        // Try to find the URL bar/address bar
        // Different browsers expose this differently
        
        if let url = getURLFromChromiumBrowser(axApp) {
            return url
        }
        
        if let url = getURLFromSafari(axApp) {
            return url
        }
        
        return nil
    }
    
    // MARK: - Browser-specific URL extraction
    
    /// Get URL from Chromium-based browsers (Chrome, Edge, Arc, Brave, etc.)
    private func getURLFromChromiumBrowser(_ app: AXUIElement) -> String? {
        // Chromium browsers typically have the URL in a text field with role "AXTextField"
        // and subrole "AXSearchField" or description containing "Address"
        
        guard let window = getFirstWindow(app) else { return nil }
        
        // Look for address bar - usually a text field with specific properties
        if let addressBar = findElement(in: window, matching: { element in
            guard let role = getRole(element), role == kAXTextFieldRole as String else { return false }
            
            // Check for address bar indicators
            if let description = getDescription(element) {
                let desc = description.lowercased()
                if desc.contains("address") || desc.contains("url") || desc.contains("search") {
                    return true
                }
            }
            
            if let title = getTitle(element) {
                let t = title.lowercased()
                if t.contains("address") || t.contains("url") {
                    return true
                }
            }
            
            return false
        }) {
            return getValue(addressBar)
        }
        
        return nil
    }
    
    /// Get URL from Safari
    private func getURLFromSafari(_ app: AXUIElement) -> String? {
        guard let window = getFirstWindow(app) else { return nil }
        
        // Safari has a specific structure - look for the URL field
        if let addressBar = findElement(in: window, matching: { element in
            guard let role = getRole(element) else { return false }
            
            // Safari uses AXTextField or AXComboBox for URL bar
            if role == kAXTextFieldRole as String || role == kAXComboBoxRole as String {
                if let description = getDescription(element) {
                    let desc = description.lowercased()
                    return desc.contains("address") || desc.contains("url") || 
                           desc.contains("search") || desc.contains("smart search")
                }
            }
            
            return false
        }) {
            return getValue(addressBar)
        }
        
        return nil
    }
    
    // MARK: - Accessibility Helpers
    
    private func getFirstWindow(_ app: AXUIElement) -> AXUIElement? {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let firstWindow = windows.first else {
            return nil
        }
        return firstWindow
    }
    
    private func findElement(in element: AXUIElement, matching predicate: (AXUIElement) -> Bool, maxDepth: Int = 10) -> AXUIElement? {
        guard maxDepth > 0 else { return nil }
        
        if predicate(element) {
            return element
        }
        
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        
        for child in children {
            if let found = findElement(in: child, matching: predicate, maxDepth: maxDepth - 1) {
                return found
            }
        }
        
        return nil
    }
    
    private func getRole(_ element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success else {
            return nil
        }
        return roleRef as? String
    }
    
    private func getDescription(_ element: AXUIElement) -> String? {
        var descRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success else {
            return nil
        }
        return descRef as? String
    }
    
    private func getTitle(_ element: AXUIElement) -> String? {
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success else {
            return nil
        }
        return titleRef as? String
    }
    
    private func getValue(_ element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success else {
            return nil
        }
        return valueRef as? String
    }
}
