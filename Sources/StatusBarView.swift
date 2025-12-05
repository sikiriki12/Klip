import SwiftUI

struct StatusBarView: View {
    @State private var isRecording = false
    @State private var currentMode = "Translate"
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Klip")
                    .font(.headline)
                Spacer()
                Text("v0.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Recording status
            HStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.gray)
                    .frame(width: 10, height: 10)
                Text(isRecording ? "Recording..." : "Ready")
                    .font(.subheadline)
                Spacer()
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
                Text("to start recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Divider()
            
            // Buttons
            HStack {
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
        .frame(width: 260)
    }
}

#Preview {
    StatusBarView()
}
