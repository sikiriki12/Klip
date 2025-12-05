import SwiftUI
import AppKit

struct StatusBarView: View {
    @ObservedObject private var coordinator = TranscriptionCoordinator.shared
    @State private var currentMode = "Raw"  // Will be dynamic in Phase 2
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Klip")
                    .font(.headline)
                Spacer()
                Text("v0.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Recording status
            HStack {
                Circle()
                    .fill(coordinator.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 0.3), value: coordinator.isRecording)
                
                Text(coordinator.isRecording ? "Recording..." : "Ready")
                    .font(.subheadline)
                    .fontWeight(coordinator.isRecording ? .semibold : .regular)
                
                Spacer()
                
                if coordinator.isRecording {
                    Image(systemName: "waveform")
                        .foregroundColor(.red)
                }
            }
            
            // Partial transcript preview
            if coordinator.isRecording && !coordinator.partialTranscript.isEmpty {
                Text(coordinator.partialTranscript)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Last transcript
            if !coordinator.lastTranscript.isEmpty && !coordinator.isRecording {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcription:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(coordinator.lastTranscript)
                        .font(.caption)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Error message
            if let error = coordinator.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
            
            // Current mode
            HStack {
                Text("Mode:")
                    .foregroundColor(.secondary)
                Text(currentMode)
                    .fontWeight(.medium)
                Spacer()
            }
            .font(.subheadline)
            
            // Shortcut hint
            HStack {
                Text("⌥K")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                Text(coordinator.isRecording ? "to stop" : "to start recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Divider()
            
            // Buttons
            HStack {
                Button("Settings...") {
                    AppDelegate.shared?.openSettings()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    StatusBarView()
}
