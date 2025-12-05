import AppKit
import AVFoundation

/// Plays sound effects for user feedback
class SoundPlayer {
    static let shared = SoundPlayer()
    
    private init() {}
    
    /// Play a completion/success sound
    func playCompletionSound() {
        // Use built-in macOS sounds
        // Available sounds: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.play()
        } else {
            // Fallback to system sound
            NSSound.beep()
        }
    }
    
    /// Play an error sound
    func playErrorSound() {
        if let sound = NSSound(named: NSSound.Name("Basso")) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
    
    /// Play a start recording sound
    func playStartSound() {
        if let sound = NSSound(named: NSSound.Name("Pop")) {
            sound.play()
        }
    }
    
    /// Play a custom sound from a file path
    func playSound(at path: String) {
        if let sound = NSSound(contentsOfFile: path, byReference: true) {
            sound.play()
        }
    }
}
