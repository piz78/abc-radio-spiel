import SwiftUI

/// «Am Stück ufneh»: zeigt einen Satz nach dem anderen gross an (wie ein Teleprompter).
/// Antippen = aufnehmen, nochmals antippen = speichern und automatisch zum nächsten Satz.
/// So lassen sich alle ~580 Fragen ohne Stimm-Klon in ein paar Sitzungen einsprechen.
struct RecordingSessionView: View {
    let title: String
    let clips: [Clip]
    let recorder: VoiceRecorder
    var hint: String?

    @Environment(AppModel.self) private var app
    @State private var index = 0
    @State private var onlyMissing = true
    @State private var didStart = false

    private var current: Clip? { clips.indices.contains(index) ? clips[index] : nil }

    private var doneCount: Int {
        _ = recorder.revision
        return clips.filter { app.clips.hasRecording($0.key) }.count
    }

    var body: some View {
        let _ = recorder.revision
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                ProgressView(value: Double(doneCount), total: Double(max(clips.count, 1)))
                    .tint(.green)
                HStack {
                    Text("\(doneCount) vo \(clips.count) ufgnoh")
                    Spacer()
                    if current != nil {
                        Text("Satz \(index + 1)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Toggle("Nur Sätz ohni Ufnahm", isOn: $onlyMissing)
                    .font(.subheadline)
            }

            Spacer(minLength: 0)

            if let clip = current {
                VStack(spacing: 14) {
                    Text(clip.group)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(clip.text)
                        .font(.title.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                    statusLabel(clip)
                        .font(.caption)
                    ProgressView(value: Double(recorder.level))
                        .tint(.red)
                        .opacity(recorder.recordingKey == clip.key ? 1 : 0)
                }
            } else {
                ContentUnavailableView(
                    "Alles ufgnoh! 🎉",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Schalt «Nur Sätz ohni Ufnahm» us, zum einzelni Sätz nomal z'mache.")
                )
            }

            Spacer(minLength: 0)

            if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            controls
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            recorder.prepareSession()
            if !didStart {
                didStart = true
                index = firstIndex(from: 0)
            }
        }
        .onDisappear {
            recorder.tearDown()
        }
        .onChange(of: onlyMissing) { _, missing in
            if missing, let clip = current, app.clips.hasRecording(clip.key) {
                index = firstIndex(from: index)
            } else if !missing, current == nil {
                index = max(0, clips.count - 1)
            }
        }
    }

    private var controls: some View {
        let isRecording = current.map { recorder.recordingKey == $0.key } ?? false
        let hasOwn = current.map { app.clips.hasRecording($0.key) } ?? false
        return HStack(spacing: 28) {
            Button {
                recorder.tearDown()
                index = max(0, min(index, clips.count) - 1)
            } label: {
                Image(systemName: "chevron.backward.circle").font(.largeTitle)
            }
            .disabled(index == 0 || isRecording)
            .accessibilityLabel("Zrugg")

            Button {
                if let clip = current {
                    recorder.play(clip.key, url: app.clips.recordingURL(for: clip.key))
                }
            } label: {
                Image(systemName: current.map { recorder.playingKey == $0.key } == true
                      ? "speaker.wave.3.fill" : "play.circle")
                    .font(.largeTitle)
            }
            .disabled(!hasOwn || isRecording)
            .accessibilityLabel("Abhöre")

            Button {
                toggleRecording()
            } label: {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: isRecording)
            }
            .disabled(current == nil)
            .accessibilityLabel(isRecording ? "Stopp" : "Ufneh")

            Button {
                recorder.tearDown()
                advance()
            } label: {
                Image(systemName: "chevron.forward.circle").font(.largeTitle)
            }
            .disabled(current == nil || isRecording)
            .accessibilityLabel("Überspringe")
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func statusLabel(_ clip: Clip) -> some View {
        if recorder.recordingKey == clip.key {
            Label("Nimmt uf …", systemImage: "record.circle").foregroundStyle(.red)
        } else if app.clips.hasRecording(clip.key) {
            Label("Eigeni Ufnahm – nomal tippe zum Ersetze", systemImage: "mic.fill").foregroundStyle(.green)
        } else if app.clips.bundledURL(for: clip.key) != nil {
            Label("Generiert", systemImage: "sparkles").foregroundStyle(.orange)
        } else {
            Label("No kei Ufnahm", systemImage: "speaker.wave.1").foregroundStyle(.secondary)
        }
    }

    private func toggleRecording() {
        guard let clip = current else { return }
        if recorder.recordingKey == clip.key {
            if recorder.stopRecording() {
                let recorded = index
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    // Nur weiter, wenn inzwischen niemand navigiert oder neu aufgenommen hat.
                    if index == recorded, recorder.recordingKey == nil { advance() }
                }
            }
        } else {
            recorder.startRecording(clip.key)
        }
    }

    private func advance() {
        index = firstIndex(from: index + 1)
    }

    /// Nächster Satz ab `start` (bei «Nur Sätz ohni Ufnahm» der nächste ohne Aufnahme).
    private func firstIndex(from start: Int) -> Int {
        guard start < clips.count else { return clips.count }
        guard onlyMissing else { return start }
        return clips[start...].firstIndex { !app.clips.hasRecording($0.key) } ?? clips.count
    }
}
