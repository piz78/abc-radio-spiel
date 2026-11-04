import SwiftUI

/// «Eigeni Stimm»: Moderator-Sätze, Zahlen-Bausteine und Fragen selber aufnehmen,
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

    private var questionClips: [Clip] { ClipCatalog.questionClips(app.bank) }

    /// Tipps zur Betonung für Gruppen mit Bausteinen (wie bei den SBB-Ansagen).
    static func hint(for group: String) -> String? {
        typealias G = ModeratorScript.Group
        switch group {
        case G.numbers:
            return "Säg jedi Zahl wie mitts im Satz – d'Stimm obe laa, nid abesänke. Si wird zwüsche «Du hesch …» und «… Sekunde.» igsetzt."
        case G.rules:
            return "Sätz mit «…» sind Baustei: det chunnt e Zahl dezwüsche. Vor de Zahl d'Stimm obe laa, nach de Zahl normal fertig rede."
        case G.score:
            return "«… Pünkt.» chunnt grad nach ere Zahl – also ohni Pause aafange und am Schluss d'Stimm abesänke."
        default:
            return nil
        }
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

            Section {
                Label("Sprich d'Moderator-Sätz und d'Zahle sälber ii. Sätz mit Zahle setzt d'App us Baustei zäme – wie d'Aasage a de SBB.", systemImage: "1.circle")
                Label("Sprich d'Frage am Stück ii (unde). Frage ohni Ufnahm list d'iOS-Stimm vor – du chasch also nach und nach ufneh.", systemImage: "2.circle")
                Label("Optional: Referenz-Sätz ufneh, per AirDrop an de Mac schicke und d'restliche Frage mit «tools/voice» generiere.", systemImage: "3.circle")
            } header: {
                Text("So gahts")
            }
            .font(.subheadline)

            if let recorder {
                Section("Moderator") {
                    let moderatorClips = moderatorGroups.flatMap(\.1).filter { !$0.key.hasPrefix("ref-") }
                    NavigationLink {
                        RecordingSessionView(title: "Moderator ufneh", clips: moderatorClips, recorder: recorder,
                                             hint: "Bi Sätz mit «…» und bi de Zahle d'Stimm obe laa – die werde zämegsetzt.")
                    } label: {
                        sessionLabel("Alli Moderator-Sätz am Stück", clips: moderatorClips)
                    }
                    Button {
                        // Zämegsetzti Sätz probehöre: Regle mit Ziit/Ziel und es Resultat.
                        recorder.tearDown()
                        app.applySettings()
                        let rules = ModeratorScript.rules(seconds: app.settings.roundSeconds, target: app.settings.targetScore)
                        let score = Int.random(in: 0...max(1, app.settings.targetScore + 3))
                        let verdict = ModeratorScript.verdict(score: score, target: app.settings.targetScore)
                        app.voice.speak(ModeratorLine(display: rules.display + " " + verdict.display,
                                                      clips: rules.clips + verdict.clips))
                    } label: {
                        Label("Zämegsetzti Sätz probehöre", systemImage: "play.circle")
                    }
                    ForEach(moderatorGroups, id: \.0) { group, clips in
                        NavigationLink {
                            ClipListView(title: group, clips: clips, recorder: recorder, hint: Self.hint(for: group))
                        } label: {
                            groupLabel(group, clips: clips)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        RecordingSessionView(title: "Frage ufneh", clips: questionClips, recorder: recorder,
                                             hint: "Ruhig und dütlich, wie im Radio. Nach em Stopp gahts grad zur nächschte Frag.")
                    } label: {
                        sessionLabel("Alli Frage am Stück", clips: questionClips)
                    }
                    ForEach(app.bank.letters, id: \.self) { letter in
                        let clips = app.bank.questions(for: letter).map(\.clip)
                        NavigationLink {
                            ClipListView(title: "Frage \(letter)", clips: clips, recorder: recorder)
                        } label: {
                            groupLabel("Buechstabe \(letter)", clips: clips)
                        }
                    }
                } header: {
                    Text("Frage")
                } footer: {
                    Text("Jedi Frag als ganze Satz – das tönt am natürlichschte. Rund 580 churzi Sätz sind öppe 30–45 Minute Rede, verteilt uf es paar Abig.")
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

    private func sessionLabel(_ title: String, clips: [Clip]) -> some View {
        _ = recorder?.revision
        let own = clips.filter { app.clips.hasRecording($0.key) }.count
        return VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "record.circle")
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(own), total: Double(max(clips.count, 1)))
                .tint(.green)
            Text("\(own) vo \(clips.count) mit eigener Ufnahm")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
    var hint: String?
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
                VStack(alignment: .leading, spacing: 6) {
                    if let hint { Text(hint) }
                    Text("Tipp uf 🎙️ zum Ufneh, nomal tippe zum Stoppe. Ruhig und dütlich rede, wie im Radio.")
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RecordingSessionView(title: title, clips: clips, recorder: recorder, hint: hint)
                } label: {
                    Label("Am Stück", systemImage: "record.circle")
                }
            }
        }
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
