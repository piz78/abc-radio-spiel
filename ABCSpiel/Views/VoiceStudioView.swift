import SwiftUI

/// «Eigeni Stimm»: Moderator-Sätze und Fragen selber aufnehmen,
/// Aufnahmen an den Mac schicken (für den Stimm-Klon) und Status der Clips sehen.
struct VoiceStudioView: View {
    @Environment(AppModel.self) private var app
    @State private var recorder: VoiceRecorder?
    @State private var permissionDenied = false

    private var allClips: [Clip] { ClipCatalog.all(bank: app.bank) }

    private var moderatorGroups: [(String, [Clip])] {
        var order: [String] = []
        var grouped: [String: [Clip]] = [:]
        for clip in allClips where !clip.key.hasPrefix("q-") {
            if grouped[clip.group] == nil { order.append(clip.group) }
            grouped[clip.group, default: []].append(clip)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        @Bindable var settings = app.settings
        List {
            Section {
                Toggle("Eigeni Ufnahme & generierti Clips bruuche", isOn: $settings.useOwnVoice)
                    .onChange(of: settings.useOwnVoice) { _, _ in app.applySettings() }
                LabeledContent("Eigeni Ufnahme", value: "\(recordingCount)")
                LabeledContent("Generierti Clips i de App", value: "\(app.clips.bundledCount)")
            } footer: {
                Text("Wo's e Ufnahm git, redt de Moderator mit dinere Stimm. Suscht list d'iOS-Stimm vor. Eigeni Ufnahme gönd vor generierte Clips.")
            }

            Section("So gahts") {
                Label("Sprich d'Moderator-Sätz und d'Referenz-Sätz sälber ii.", systemImage: "1.circle")
                Label("Schick d'Ufnahme per AirDrop an din Mac (unde).", systemImage: "2.circle")
                Label("Uf em Mac erzüügt «tools/voice» mit eme lokale Modell alli Frage i dinere Stimm.", systemImage: "3.circle")
                Label("App nöi baue – fertig!", systemImage: "4.circle")
            }
            .font(.subheadline)

            if let recorder {
                Section("Moderator") {
                    ForEach(moderatorGroups, id: \.0) { group, clips in
                        NavigationLink {
                            ClipListView(title: group, clips: clips, recorder: recorder)
                        } label: {
                            groupLabel(group, clips: clips)
                        }
                    }
                }

                Section("Frage") {
                    ForEach(app.bank.letters, id: \.self) { letter in
                        let clips = app.bank.questions(for: letter).map(\.clip)
                        NavigationLink {
                            ClipListView(title: "Frage \(letter)", clips: clips, recorder: recorder)
                        } label: {
                            groupLabel("Buechstabe \(letter)", clips: clips)
                        }
                    }
                }

                Section {
                    let recordings = app.clips.allRecordings()
                    if recordings.isEmpty {
                        Text("No kei Ufnahme.")
                            .foregroundStyle(.secondary)
                    } else {
                        ShareLink(items: recordings) {
                            Label("\(recordings.count) Ufnahme exportiere", systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    Text("An de Mac schicke")
                } footer: {
                    Text("Am Mac i «tools/voice/referenz» lege. D'Ufnahme sind au i de Dateie-App under «ABC › Stimm».")
                }
                .id(recorder.revision)
            }
        }
        .navigationTitle("Eigeni Stimm")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if recorder == nil { recorder = VoiceRecorder(library: app.clips) }
            if !(await VoiceRecorder.requestPermission()) { permissionDenied = true }
        }
        .alert("Kei Mikrofon-Zuegriff", isPresented: $permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Bitte erlaub s'Mikrofon i de iOS-Iistellige, zum Ufnahme mache.")
        }
    }

    private var recordingCount: Int {
        _ = recorder?.revision
        return app.clips.allRecordings().count
    }

    private func groupLabel(_ title: String, clips: [Clip]) -> some View {
        _ = recorder?.revision
        let own = clips.filter { app.clips.hasRecording($0.key) }.count
        let generated = clips.filter { !app.clips.hasRecording($0.key) && app.clips.bundledURL(for: $0.key) != nil }.count
        return HStack {
            Text(title)
            Spacer()
            if own > 0 {
                Label("\(own)", systemImage: "mic.fill").foregroundStyle(.green)
            }
            if generated > 0 {
                Label("\(generated)", systemImage: "sparkles").foregroundStyle(.orange)
            }
            Text("/ \(clips.count)").foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .labelStyle(.titleAndIcon)
    }
}

/// Liste von Clips mit Aufnehmen / Abspielen / Löschen.
struct ClipListView: View {
    let title: String
    let clips: [Clip]
    let recorder: VoiceRecorder
    @Environment(AppModel.self) private var app

    var body: some View {
        List {
            Section {
                ForEach(clips, id: \.key) { clip in
                    ClipRow(clip: clip, recorder: recorder)
                        .swipeActions {
                            if app.clips.hasRecording(clip.key) {
                                Button("Lösche", role: .destructive) { recorder.delete(clip.key) }
                            }
                        }
                }
            } footer: {
                Text("Tipp uf 🎙️ zum Ufneh, nomal tippe zum Stoppe. Ruhig und dütlich rede, wie im Radio.")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recorder.prepareSession() }
        .onDisappear {
            recorder.tearDown()
            app.voice.stop()
        }
    }
}

struct ClipRow: View {
    let clip: Clip
    let recorder: VoiceRecorder
    @Environment(AppModel.self) private var app

    var body: some View {
        let _ = recorder.revision
        let isRecording = recorder.recordingKey == clip.key
        let own = app.clips.hasRecording(clip.key)
        let bundled = app.clips.bundledURL(for: clip.key)

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.text)
                    .font(.body)
                Group {
                    if isRecording {
                        ProgressView(value: Double(recorder.level))
                            .tint(.red)
                    } else if own {
                        Label("Eigeni Ufnahm", systemImage: "mic.fill").foregroundStyle(.green)
                    } else if bundled != nil {
                        Label("Generiert", systemImage: "sparkles").foregroundStyle(.orange)
                    } else {
                        Label("iOS-Stimm", systemImage: "speaker.wave.1").foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Button {
                if let url = own ? app.clips.recordingURL(for: clip.key) : bundled {
                    recorder.play(clip.key, url: url)
                } else {
                    app.applySettings()
                    app.voice.speak(ModeratorLine(clip.text))
                }
            } label: {
                Image(systemName: recorder.playingKey == clip.key ? "speaker.wave.3.fill" : "play.circle")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(isRecording)

            Button {
                recorder.toggleRecording(clip.key)
            } label: {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: isRecording)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
