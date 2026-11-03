import SwiftUI

struct ResultView: View {
    let controller: GameController
    let onPlayAgain: () -> Void
    let onClose: () -> Void

    private var won: Bool { controller.round.score >= controller.target }

    var body: some View {
        VStack(spacing: 16) {
            scoreHeader
            ModeratorBubble(text: controller.bubble)

            Text("Tipp uf e Frag zum d'Wertig korrigiere")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(controller.round.log) { entry in
                        Button {
                            withAnimation(.snappy) { controller.toggle(entry.id) }
                        } label: {
                            row(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Fertig", action: onClose)
                    .buttonStyle(SecondaryButtonStyle())
                Button {
                    onPlayAgain()
                } label: {
                    Label("Nomal", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var scoreHeader: some View {
        HStack(spacing: 16) {
            LetterCardView(letter: controller.card.letter, revealed: true, size: 90)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(controller.round.score) Pünkt")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(won ? Theme.accent : .white)
                    .contentTransition(.numericText())
                Text(won ? "🎉 Gwunne! (Ziel: \(controller.target))" : "Ziel: \(controller.target) Pünkt")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(controller.round.passedCount)× wiiter")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private func row(_ entry: AnsweredQuestion) -> some View {
        let icon: String
        let color: Color
        switch entry.outcome {
        case .correct:
            icon = "checkmark.circle.fill"; color = Theme.correct
        case .passed:
            icon = "arrow.right.circle.fill"; color = Theme.pass
        case .open:
            icon = "clock.fill"; color = .orange
        }
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.question.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(entry.question.answer)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.bubble, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
    }
}
