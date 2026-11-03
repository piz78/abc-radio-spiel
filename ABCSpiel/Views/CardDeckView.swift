import SwiftUI

/// Charte generiere, aaluege und teile – z.B. zum Vorläse am Tisch.
struct CardDeckView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLetter = "?"
    @State private var card: Card?
    @State private var showAnswers = true

    private var letters: [String] { ["?"] + app.generator.eligibleLetters }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        letterPicker
                        if let card {
                            cardView(card)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Chartestapel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let card {
                        ShareLink(item: card.shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .onAppear { if card == nil { draw() } }
    }

    private var letterPicker: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(letters, id: \.self) { letter in
                        Button {
                            selectedLetter = letter
                            draw()
                        } label: {
                            Text(letter == "?" ? "🎲" : letter)
                                .font(.headline.weight(.black))
                                .frame(width: 40, height: 40)
                                .background(selectedLetter == letter ? Theme.accent : Theme.bubble,
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundStyle(selectedLetter == letter ? Theme.cardText : .white)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Toggle("Lösige", isOn: $showAnswers)
                    .toggleStyle(.button)
                    .tint(Theme.accent)
                Button {
                    draw()
                } label: {
                    Label("Nöii Charte", systemImage: "shuffle")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func cardView(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.letter)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                Spacer()
                VStack(alignment: .trailing) {
                    Text("ABC")
                        .font(.title.weight(.black))
                    Text("\(card.questions.count) Frage")
                        .font(.caption.weight(.semibold))
                        .opacity(0.6)
                }
            }
            .foregroundStyle(Theme.cardText)
            .padding(.bottom, 8)

            ForEach(Array(card.questions.enumerated()), id: \.element.id) { index, question in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(width: 28, alignment: .trailing)
                        .opacity(0.5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(question.prompt)
                            .font(.subheadline)
                        if showAnswers {
                            Text(question.answer)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(Color(red: 0.55, green: 0.1, blue: 0.6))
                        }
                    }
                }
                .foregroundStyle(Theme.cardText)
                .padding(.vertical, 6)
                if index < card.questions.count - 1 {
                    Divider()
                }
            }
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.accent, lineWidth: 3)
                .padding(6)
        }
    }

    private func draw() {
        withAnimation(.snappy) {
            card = app.generator.makeCard(letter: selectedLetter == "?" ? nil : selectedLetter)
        }
    }
}
