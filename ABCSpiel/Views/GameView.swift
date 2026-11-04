import SwiftUI

struct GameView: View {
    let controller: GameController
    let onClose: () -> Void
    let onPlayAgain: () -> Void

    @State private var confirmClose = false

    var body: some View {
        VStack(spacing: 20) {
            topBar
            switch controller.phase {
            case .intro:
                introView
            case .countdown(let number):
                countdownView(number)
            case .playing:
                playingView
            case .finished:
                ResultView(controller: controller, onPlayAgain: onPlayAgain, onClose: onClose)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .confirmationDialog("Spiel abbräche?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Abbräche", role: .destructive, action: onClose)
            Button("Wiiterspile", role: .cancel) {}
        }
    }

    // MARK: Kopfzeile

    private var topBar: some View {
        HStack {
            Button {
                if controller.phase == .finished || controller.phase == .intro {
                    onClose()
                } else {
                    confirmClose = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.bubble, in: Circle())
            }
            .accessibilityLabel("Schliesse")

            Spacer()

            if controller.mode == .friends {
                Label("Du moderiersch", systemImage: "person.2.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            if controller.phase == .playing {
                Label("\(controller.round.score)", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.black).monospacedDigit())
                    .foregroundStyle(Theme.correct)
                    .contentTransition(.numericText())
                    .animation(.spring, value: controller.round.score)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Intro

    private var introView: some View {
        VStack(spacing: 28) {
            ModeratorBubble(text: controller.bubble)
            Spacer(minLength: 0)
            LetterCardView(letter: controller.card.letter, revealed: controller.cardRevealed, size: 260)
            Spacer(minLength: 0)
            if controller.readyToStart {
                Button {
                    controller.startCountdown()
                } label: {
                    Label("Bereit – los!", systemImage: "flag.checkered")
                }
                .buttonStyle(PrimaryButtonStyle())
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button("Überspringe") {
                    controller.startCountdown()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: Countdown

    private func countdownView(_ number: Int) -> some View {
        VStack(spacing: 28) {
            ModeratorBubble(text: controller.bubble)
            Spacer(minLength: 0)
            // Gleiche Karte wie im Intro – der Buchstabe bleibt bis zum Start gross sichtbar.
            LetterCardView(letter: controller.card.letter, revealed: true, size: 230)
                .accessibilityLabel("Buechstabe \(controller.card.letter)")
            Text("\(number)")
                .font(.system(size: 110, weight: .black, design: .rounded))
                .foregroundStyle(Theme.accent)
                .id(number)
                .transition(.scale(scale: 1.8).combined(with: .opacity))
                .animation(.spring(duration: 0.4), value: number)
                .accessibilityLabel("Countdown \(number)")
            Spacer(minLength: 0)
        }
    }

    // MARK: Spiel

    private var playingView: some View {
        VStack(spacing: 18) {
            TimerRing(remaining: controller.remaining,
                      duration: controller.round.duration,
                      letter: controller.card.letter)

            questionCard

            feedbackChip
                .frame(height: 34)

            if controller.isListening {
                listeningIndicator
            } else if let error = controller.listeningError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Button {
                    controller.pass()
                } label: {
                    Label("Wiiter", systemImage: "forward.fill")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.pass, foreground: .white))

                Button {
                    controller.markCorrect()
                } label: {
                    Label("Richtig", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.correct, foreground: .white))
            }
        }
    }

    private var questionCard: some View {
        let question = controller.round.currentQuestion
        return VStack(spacing: 12) {
            Text("Frag \(controller.round.currentIndex + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.cardText.opacity(0.5))
            Text(question?.prompt ?? "")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.cardText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
            if controller.showAnswersWhilePlaying, let question {
                Text(question.answer)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Theme.correct, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .id(question?.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
        .animation(.easeOut(duration: 0.18), value: question?.id)
    }

    @ViewBuilder
    private var feedbackChip: some View {
        if let feedback = controller.lastFeedback {
            HStack(spacing: 6) {
                Image(systemName: feedback.correct ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                Text(feedback.correct ? feedback.answer : "Lösig: \(feedback.answer)")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background((feedback.correct ? Theme.correct : Theme.pass).opacity(0.85), in: Capsule())
            .id(feedback.id)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var listeningIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, isActive: true)
                .foregroundStyle(Theme.accent)
            Text(controller.transcript.isEmpty ? "Ich lose zue …" : controller.transcript)
                .lineLimit(1)
                .truncationMode(.head)
                .foregroundStyle(.white.opacity(0.8))
        }
        .font(.subheadline)
    }
}
