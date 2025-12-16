import Foundation

/// Manages user identity for context-aware modes
class UserProfile: ObservableObject {
    static let shared = UserProfile()
    
    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "userProfileName") }
    }
    
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: "userProfileEmail") }
    }
    
    @Published var company: String {
        didSet { UserDefaults.standard.set(company, forKey: "userProfileCompany") }
    }
    
    /// Whether to include user identity in context-aware modes (default: ON)
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "userProfileEnabled") }
    }
    
    /// Whether user profile has any data
    var hasIdentity: Bool {
        isEnabled && (!name.isEmpty || !email.isEmpty)
    }
    
    /// Format identity for injection into prompts
    var contextString: String? {
        guard hasIdentity else { return nil }
        
        var lines: [String] = []
        if !name.isEmpty { lines.append("Name: \(name)") }
        if !email.isEmpty { lines.append("Email: \(email)") }
        if !company.isEmpty { lines.append("Company: \(company)") }
        
        return """
        [Your identity - you are writing as]:
        \(lines.joined(separator: "\n"))
        """
    }
    
    private init() {
        // Load saved values or use empty
        name = UserDefaults.standard.string(forKey: "userProfileName") ?? ""
        email = UserDefaults.standard.string(forKey: "userProfileEmail") ?? ""
        company = UserDefaults.standard.string(forKey: "userProfileCompany") ?? ""
        
        // Load enabled state (default: true)
        if UserDefaults.standard.object(forKey: "userProfileEnabled") == nil {
            isEnabled = true  // Default ON
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: "userProfileEnabled")
        }
        
        // Auto-detect on first run if empty
        if name.isEmpty && email.isEmpty {
            autoDetect()
        }
    }
    
    /// Auto-detect user info from system
    func autoDetect() {
        // Get full name from macOS user account
        let fullName = NSFullUserName()
        if !fullName.isEmpty && name.isEmpty {
            name = fullName
            print("👤 Auto-detected name: \(fullName)")
        }
        
        // Try to get email from git config
        detectGitEmail()
    }
    
    /// Get email from git config (async)
    private func detectGitEmail() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["config", "--global", "user.email"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let gitEmail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !gitEmail.isEmpty {
                    DispatchQueue.main.async {
                        if self?.email.isEmpty == true {
                            self?.email = gitEmail
                            print("📧 Auto-detected email from git: \(gitEmail)")
                        }
                    }
                }
            } catch {
                // Git not available or not configured - that's fine
            }
        }
    }
}
