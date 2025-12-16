import SwiftUI
import AppKit

struct StatusBarView: View {
    @ObservedObject private var coordinator = TranscriptionCoordinator.shared
    @ObservedObject private var modeManager = ModeManager.shared
    @State private var showCopiedFeedback = false
    
    var body: some View {
        VStack(spacing: 14) {
            // Transcription area (main focus)
            VStack(spacing: 8) {
                if coordinator.isRecording {
                    // Live recording view
                    VStack(spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Recording...")
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        
                        if !coordinator.partialTranscript.isEmpty {
                            ScrollView {
                                Text(coordinator.partialTranscript)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 100)
                        }
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(10)
                } else if !coordinator.lastTranscript.isEmpty {
                    // Last transcript with copy
                    HStack(alignment: .top, spacing: 8) {
                        ScrollView {
                            Text(coordinator.lastTranscript)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 110)
                        
                        Button(action: {
                            ClipboardManager.shared.copyToClipboard(coordinator.lastTranscript)
                            showCopiedFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedFeedback = false
                            }
                        }) {
                            Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(showCopiedFeedback ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(10)
                }
            }
            .frame(minHeight: 80)
            
            // Mode selector
            Picker("", selection: Binding(
                get: { modeManager.currentModeIndex },
                set: { modeManager.selectMode(modeManager.modes[$0]) }
            )) {
                ForEach(0..<min(modeManager.modes.count, 5), id: \.self) { index in
                    Text(modeManager.modes[index].name).tag(index)
                }
            }
            .pickerStyle(.segmented)
            
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
            
            // Big start/stop button with shortcut
            Button(action: {
                coordinator.toggleRecording()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: coordinator.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16))
                    Text(coordinator.isRecording ? "Stop" : "Start")
                        .fontWeight(.semibold)
                    
                    Text("⌥K")
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(coordinator.isRecording ? .red : .blue)
            
            Divider()
            
            // Footer buttons
            HStack {
                Button(action: {
                    AppDelegate.shared?.openSettings()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

#Preview {
    StatusBarView()
}
