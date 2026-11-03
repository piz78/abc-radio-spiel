import SwiftUI

enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.13, green: 0.05, blue: 0.30), Color(red: 0.36, green: 0.06, blue: 0.42)],
        startPoint: .top, endPoint: .bottom
    )
    static let accent = Color(red: 1.0, green: 0.80, blue: 0.10)
    static let correct = Color(red: 0.20, green: 0.80, blue: 0.45)
    static let pass = Color(red: 0.95, green: 0.35, blue: 0.40)
    static let card = Color.white
    static let cardText = Color(red: 0.12, green: 0.08, blue: 0.25)
    static let bubble = Color.white.opacity(0.12)
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    var foreground: Color = Theme.cardText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .foregroundStyle(foreground)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(configuration.isPressed ? 0.25 : 0.15),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
    }
}
