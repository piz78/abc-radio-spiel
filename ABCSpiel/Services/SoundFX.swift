import AudioToolbox
import UIKit

/// Kurze System-Töne und Haptik.
@MainActor
enum SoundFX {
    static var isEnabled = true

    static func correct() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1057)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func pass() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1104)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func tick() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1103)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func buzzer() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1005)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func reveal() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1025)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
