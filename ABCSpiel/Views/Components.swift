import SwiftUI

/// Sprechblase des Moderators mit Avatar.
struct ModeratorBubble: View {
    let text: String
    var isSpeaking: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent)
                Image(systemName: "mic.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.cardText)
            }
            .frame(width: 44, height: 44)
            .overlay(alignment: .bottom) {
                Text(ModeratorScript.moderatorName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .offset(y: 16)
            }

            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.bubble, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: text)
        }
        .padding(.bottom, 8)
    }
}

/// Die Spielkarte: Rückseite «ABC», Vorderseite mit dem Buchstaben.
struct LetterCardView: View {
    let letter: String
    let revealed: Bool
    var size: CGFloat = 220

    var body: some View {
        ZStack {
            back.opacity(revealed ? 0 : 1)
            front
                .opacity(revealed ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: size * 0.72, height: size)
        .rotation3DEffect(.degrees(revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
            .fill(Theme.card)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 4)
                    .padding(8)
            }
            .overlay {
                Text(letter)
                    .font(.system(size: size * 0.55, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.cardText)
            }
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
            .fill(LinearGradient(colors: [Theme.accent, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                VStack(spacing: 2) {
                    Text("ABC")
                        .font(.system(size: size * 0.2, weight: .black, design: .rounded))
                    Text("?")
                        .font(.system(size: size * 0.22, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Theme.cardText)
            }
    }
}

/// Runder Timer mit Restsekunden.
struct TimerRing: View {
    let remaining: TimeInterval
    let duration: TimeInterval
    let letter: String

    private var fraction: Double { duration > 0 ? max(0, min(1, remaining / duration)) : 0 }
    private var color: Color {
        if remaining <= 5 { return Theme.pass }
        if remaining <= 15 { return .orange }
        return Theme.accent
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -4) {
                Text(letter)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(Int(remaining.rounded(.up)))")
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .frame(width: 150, height: 150)
        .animation(.linear(duration: 0.05), value: fraction)
    }
}

/// Kleine Statistik-Kachel.
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.black).monospacedDigit())
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.bubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
