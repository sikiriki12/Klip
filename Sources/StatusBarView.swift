import SwiftUI
import AppKit

struct StatusBarView: View {
    @ObservedObject private var coordinator = TranscriptionCoordinator.shared
    @ObservedObject private var modeManager = ModeManager.shared
    @State private var showCopiedFeedback = false
    
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
                Text("v0.3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Recording status with Start/Stop button
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
            
            // Last transcript with copy button
            if !coordinator.lastTranscript.isEmpty && !coordinator.isRecording {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Last transcription:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            ClipboardManager.shared.copyToClipboard(coordinator.lastTranscript)
                            showCopiedFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedFeedback = false
                            }
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                Text(showCopiedFeedback ? "Copied!" : "Copy")
                            }
                            .font(.caption2)
                            .foregroundColor(showCopiedFeedback ? .green : .blue)
                        }
                        .buttonStyle(.plain)
                    }
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
            
            // Current mode selector
            HStack {
                Text("Mode:")
                    .foregroundColor(.secondary)
                
                Picker("", selection: Binding(
                    get: { modeManager.currentModeIndex },
                    set: { modeManager.selectMode(modeManager.modes[$0]) }
                )) {
                    ForEach(0..<modeManager.modes.count, id: \.self) { index in
                        Text(modeManager.modes[index].name).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 150)
                
                Spacer()
            }
            .font(.subheadline)
            
            // Translation toggle
            HStack {
                Toggle(isOn: $modeManager.translateEnabled) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .foregroundColor(modeManager.translateEnabled ? .green : .secondary)
                        Text("Translate to")
                            .foregroundColor(.secondary)
                        Text(modeManager.targetLanguage)
                            .fontWeight(.medium)
                            .foregroundColor(modeManager.translateEnabled ? .primary : .secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .font(.subheadline)
            
            // Shortcut hint + Start/Stop button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("⌥K")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        if coordinator.isRecording {
                            if UserDefaults.standard.bool(forKey: "waitForSilence") {
                                Text("auto-stops on silence")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("to stop")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("to start")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Start/Stop Recording button
                Button(action: {
                    coordinator.toggleRecording()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: coordinator.isRecording ? "stop.fill" : "mic.fill")
                        Text(coordinator.isRecording ? "Stop" : "Start")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(coordinator.isRecording ? .red : .blue)
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
