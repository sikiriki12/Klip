import Foundation
import AppKit

/// Monitors clipboard for changes and tracks freshness
class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()
    
    /// Whether clipboard context is enabled
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "clipboardContextEnabled")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    /// Current clipboard content (if fresh and external)
    @Published private(set) var currentContent: String?
    
    /// When the clipboard was last changed (by external app)
    private var lastExternalChangeTime: Date?
    
    /// Last known change count
    private var lastChangeCount: Int = 0
    
    /// When WE last copied something
    private var lastAppCopyTime: Date?
    
    /// Polling timer
    private var pollTimer: Timer?
    
    /// Max age for clipboard to be considered "fresh" (seconds)
    private let maxFreshnessAge: TimeInterval = 60
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "clipboardContextEnabled")
        lastChangeCount = NSPasteboard.general.changeCount
        
        if isEnabled {
            startMonitoring()
        }
    }
    
    /// Start monitoring clipboard
    func startMonitoring() {
        guard pollTimer == nil else { return }
        
        // Poll every 5 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        
        // Check immediately
        checkClipboard()
        print("📋 Clipboard monitoring started")
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        currentContent = nil
        print("📋 Clipboard monitoring stopped")
    }
    
    /// Check if clipboard changed
    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            
            // Check if this was our own copy (within last 2 seconds)
            if let appCopyTime = lastAppCopyTime, Date().timeIntervalSince(appCopyTime) < 2.0 {
                // This change was from us, ignore
                currentContent = nil
                return
            }
            
            // External change - record time and content
            lastExternalChangeTime = Date()
            currentContent = NSPasteboard.general.string(forType: .string)
        }
    }
    
    /// Mark that we just copied something (so we can ignore it)
    func markAppCopy() {
        lastAppCopyTime = Date()
    }
    
    /// Get fresh clipboard content if available
    /// Returns nil if disabled, too old, or from our app
    func getFreshContent() -> String? {
        guard isEnabled else { return nil }
        
        // Check freshness
        guard let changeTime = lastExternalChangeTime,
              Date().timeIntervalSince(changeTime) < maxFreshnessAge else {
            return nil
        }
        
        return currentContent
    }
    
    /// Check if we have fresh context available
    var hasFreshContext: Bool {
        getFreshContent() != nil
    }
    
    deinit {
        pollTimer?.invalidate()
    }
}
