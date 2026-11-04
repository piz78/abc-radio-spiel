import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false
    @State private var confirmReset = false

    private let voices = ModeratorVoice.germanVoices()

    var body: some View {
        @Bindable var settings = app.settings
        NavigationStack {
            Form {
                Section("Spiel") {
                    Picker("Spielziit", selection: $settings.roundSeconds) {
                        ForEach([30, 45, 60, 90], id: \.self) { Text("\($0) Sekunde").tag($0) }
                    }
                    Stepper("Ziel: \(settings.targetScore) Pünkt", value: $settings.targetScore, in: 5...25)
                    Toggle("Schwierigi Buechstabe (C, I, J, U, V)", isOn: $settings.includeHardLetters)
                    Toggle("Regle am Afang erkläre", isOn: $settings.explainRules)
                }

                Section {
                    Toggle("Moderatorin redt", isOn: $settings.voiceEnabled)
                    if settings.voiceEnabled {
                        NavigationLink {
                            VoiceStudioView()
                        } label: {
                            Label("Eigeni Stimm", systemImage: "waveform.badge.mic")
                        }
                        Picker("Stimm", selection: $settings.voiceIdentifier) {
                            Text("Automatisch").tag(String?.none)
                            ForEach(voices, id: \.identifier) { voice in
                                Text(ModeratorVoice.describe(voice)).tag(Optional(voice.identifier))
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Tempo")
                            Slider(value: $settings.speechRate, in: 0.4...0.65) {
                                Text("Tempo")
                            } minimumValueLabel: {
                                Image(systemName: "tortoise.fill")
                            } maximumValueLabel: {
                                Image(systemName: "hare.fill")
                            }
                        }
                        Button {
                            app.applySettings()
                            AudioSession.configure(listening: false)
                            app.voice.speak(ModeratorScript.probe)
                        } label: {
                            Label("Probelose", systemImage: "speaker.wave.2.fill")
                        }
                    }
                } header: {
                    Text("Moderatorin")
                } footer: {
                    Text("Tipp: Under Iistellige › Bedienigshilfe › Gsprocheni Inhält › Stimme chasch besseri (verbesserti/Premium) dütschi Stimme abelade.")
                }

                Section {
                    Toggle("Antworte per Mikrofon erchenne", isOn: $settings.listeningEnabled)
                        .onChange(of: settings.listeningEnabled) { _, enabled in
                            guard enabled else { return }
                            Task {
                                let granted = await AnswerListener.requestAuthorization()
                                if !granted {
                                    settings.listeningEnabled = false
                                    permissionDenied = true
                                }
                            }
                        }
                    Toggle("Tön und Vibration", isOn: $settings.soundEnabled)
                } header: {
                    Text("Antworte")
                } footer: {
                    Text("Mit Mikrofon ghört d'App dini Antwort und zellt sie automatisch. Säg «wiiter» zum Passe. Funktioniert am beschte mit Chopfhörer.")
                }

                Section("Statistik") {
                    LabeledContent("Gspilti Runde", value: "\(app.stats.gamesPlayed)")
                    LabeledContent("Gwunne", value: "\(app.stats.wins)")
                    LabeledContent("Rekord", value: "\(app.stats.bestScore) Pünkt")
                    LabeledContent("Durchschnitt", value: String(format: "%.1f Pünkt", app.stats.averageScore))
                    Button("Statistik zruggsetze", role: .destructive) { confirmReset = true }
                }

                Section("Info") {
                    LabeledContent("Frage i de Datebank", value: "\(app.bank.questions.count)")
                    LabeledContent("Buechstabe", value: app.generator.eligibleLetters.joined(separator: " "))
                    Text("Inspiriert vom Kult-Radiospiel «ABC». Ein Fan-Projekt, nid offiziell.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Iistellige")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        app.applySettings()
                        app.voice.stop()
                        dismiss()
                    }
                }
            }
            .alert("Kei Zuegriff", isPresented: $permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Bitte erlaub Mikrofon und Spracherchennig i de iOS-Iistellige.")
            }
            .confirmationDialog("Statistik würkli lösche?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Lösche", role: .destructive) { app.resetStats() }
            }
        }
    }
}
