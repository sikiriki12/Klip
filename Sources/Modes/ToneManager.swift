import Foundation

/// Manages tones for modes
class ToneManager: ObservableObject {
    static let shared = ToneManager()
    
    /// All available tones (built-in + custom)
    @Published var allTones: [Tone] = []
    
    /// Per-mode tone selection (modeId -> toneId)
    @Published var modeTonesMap: [String: String] = [:]
    
    private let customTonesKey = "customTones"
    private let modeTonesKey = "modeTones"
    
    private init() {
        loadTones()
        loadModeTones()
    }
    
    /// Load all tones
    private func loadTones() {
        allTones = Tone.builtInTones
        
        // Load custom tones from UserDefaults
        if let data = UserDefaults.standard.data(forKey: customTonesKey),
           let customTones = try? JSONDecoder().decode([Tone].self, from: data) {
            allTones.append(contentsOf: customTones)
        } else {
            // First run - add Gen Z example
            allTones.append(Tone.genZTone)
            saveCustomTones()
        }
    }
    
    /// Load per-mode tone selections
    private func loadModeTones() {
        if let map = UserDefaults.standard.dictionary(forKey: modeTonesKey) as? [String: String] {
            modeTonesMap = map
        }
    }
    
    /// Save custom tones
    private func saveCustomTones() {
        let customTones = allTones.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(customTones) {
            UserDefaults.standard.set(data, forKey: customTonesKey)
        }
    }
    
    /// Save mode tone selections
    private func saveModeTones() {
        UserDefaults.standard.set(modeTonesMap, forKey: modeTonesKey)
    }
    
    /// Get tone for a mode
    func getTone(for modeId: String, defaultToneId: String) -> Tone {
        let toneId = modeTonesMap[modeId] ?? defaultToneId
        return allTones.first { $0.id == toneId } ?? allTones.first { $0.id == "normal" }!
    }
    
    /// Set tone for a mode
    func setTone(for modeId: String, toneId: String) {
        modeTonesMap[modeId] = toneId
        saveModeTones()
    }
    
    /// Add custom tone
    func addCustomTone(name: String, promptModifier: String) {
        let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let tone = Tone(id: id, name: name, promptModifier: promptModifier, isBuiltIn: false)
        allTones.append(tone)
        saveCustomTones()
    }
    
    /// Delete custom tone
    func deleteCustomTone(id: String) {
        allTones.removeAll { $0.id == id && !$0.isBuiltIn }
        // Also remove from mode selections
        for (modeId, toneId) in modeTonesMap {
            if toneId == id {
                modeTonesMap[modeId] = "normal"
            }
        }
        saveCustomTones()
        saveModeTones()
    }
    
    /// Get custom tones only
    var customTones: [Tone] {
        allTones.filter { !$0.isBuiltIn }
    }
    
    /// Get built-in tones only
    var builtInTones: [Tone] {
        allTones.filter { $0.isBuiltIn }
    }
}
