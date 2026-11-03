import SwiftUI

struct GameSession: Identifiable {
    let id = UUID()
    let mode: GameMode
}

struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var session: GameSession?
    @State private var showSettings = false
    @State private var showDeck = false
    @State private var showRules = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        ModeratorBubble(text: "Hoi! Ich bi de \(ModeratorScript.moderatorName). Ein Buechstabe, \(app.settings.roundSeconds) Sekunde, \(app.settings.targetScore) richtigi Antworte – schaffsch du das?")
                        statsRow
                        VStack(spacing: 12) {
                            Button {
                                session = GameSession(mode: .solo)
                            } label: {
                                Label("Spiel starte", systemImage: "play.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Button {
                                session = GameSession(mode: .friends)
                            } label: {
                                Label("Mit Fründe spiele", systemImage: "person.2.fill")
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                showDeck = true
                            } label: {
                                Label("Charte aaluege", systemImage: "rectangle.stack.fill")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        rules
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Iistellige")
                }
            }
            .fullScreenCover(item: $session) { session in
                GameContainerView(mode: session.mode)
                    .environment(app)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environment(app)
            }
            .sheet(isPresented: $showDeck) {
                CardDeckView().environment(app)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(["A", "B", "C"], id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.cardText)
                        .frame(width: 78, height: 92)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .rotationEffect(.degrees(letter == "A" ? -6 : letter == "C" ? 6 : 0))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
            }
            Text("S'Radiospiel für dihei")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(app.stats.gamesPlayed)", label: "Gspilt")
            StatTile(value: "\(app.stats.bestScore)", label: "Rekord")
            StatTile(value: "\(app.stats.wins)", label: "Gwunne")
        }
    }

    private var rules: some View {
        DisclosureGroup(isExpanded: $showRules) {
            VStack(alignment: .leading, spacing: 8) {
                Text("• Du ziehsch e Charte mit eme Buechstabe.")
                Text("• De Moderator stellt dir Frag um Frag – all Antworte fanged mit dem Buechstabe aa.")
                Text("• Du hesch \(app.settings.roundSeconds) Sekunde Ziit.")
                Text("• Weisch öppis nid, säg «wiiter» oder drück «Wiiter».")
                Text("• Mit \(app.settings.targetScore) richtige Antworte hesch gwunne!")
                Text("• Spracherchennig (Iistellige): d'App ghört dini Antwort sälber.")
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.top, 8)
        } label: {
            Label("So gaht s'Spiel", systemImage: "questionmark.circle")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .tint(.white)
        .padding(16)
        .background(Theme.bubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Hält den GameController und ersetzt ihn bei «Nomal spiele».
struct GameContainerView: View {
    let mode: GameMode
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var controller: GameController?
    @State private var noCards = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let controller {
                GameView(controller: controller, onClose: close, onPlayAgain: playAgain)
                    .id(controller.card.id)
                    .transition(.opacity)
            } else if noCards {
                VStack(spacing: 16) {
                    Text("Kei Frage gfunde 😕")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Button("Zrugg", action: close)
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 200)
                }
            }
        }
        .onAppear {
            if controller == nil { start() }
        }
    }

    private func start() {
        guard let card = app.newCard() else {
            noCards = true
            return
        }
        let newController = GameController(card: card, mode: mode, app: app)
        withAnimation { controller = newController }
        newController.begin()
    }

    private func playAgain() {
        controller?.commitResult()
        controller?.tearDown()
        start()
    }

    private func close() {
        controller?.commitResult()
        controller?.tearDown()
        dismiss()
    }
}
