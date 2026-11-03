import Foundation
import Observation
import SwiftUI
import UIKit

/// Steuert eine Spielrunde: Intro → Countdown → Spiel → Resultat.
@MainActor
@Observable
final class GameController {
    enum Phase: Equatable {
        case intro
        case countdown(Int)
        case playing
        case finished
    }

    struct Feedback: Identifiable, Equatable {
        let id = UUID()
        let correct: Bool
        let answer: String
    }

    let mode: GameMode
    private let app: AppModel

    private(set) var phase: Phase = .intro
    private(set) var round: GameRound
    private(set) var remaining: TimeInterval
    private(set) var bubble = ""
    private(set) var cardRevealed = false
    private(set) var readyToStart = false
    private(set) var lastFeedback: Feedback?
    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var listeningError: String?
    @ObservationIgnored private var recorded = false
    @ObservationIgnored private var flowTask: Task<Void, Never>?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private var lastTickSecond = -1
    @ObservationIgnored private let listener = AnswerListener()

    var card: Card { round.card }
    var target: Int { app.settings.targetScore }
    var showAnswersWhilePlaying: Bool { mode == .friends }

    init(card: Card, mode: GameMode, app: AppModel) {
        self.mode = mode
        self.app = app
        let duration = TimeInterval(app.settings.roundSeconds)
        self.round = GameRound(card: card, duration: duration)
        self.remaining = duration
    }

    // MARK: - Ablauf

    func begin() {
        app.applySettings()
        UIApplication.shared.isIdleTimerDisabled = true
        AudioSession.configure(listening: false)
        flowTask?.cancel()
        flowTask = Task { await runIntro() }
    }

    private func runIntro() async {
        let voice = app.voice
        let greeting = ModeratorScript.pick(ModeratorScript.greetings)
        bubble = greeting.display
        await voice.say(greeting.spoken)
        if Task.isCancelled { return }

        if app.settings.explainRules {
            let rules = ModeratorScript.rules(seconds: app.settings.roundSeconds, target: target)
            bubble = rules.display
            await voice.say(rules.spoken)
            if Task.isCancelled { return }
        }

        if !app.settings.voiceEnabled { try? await Task.sleep(for: .seconds(1.2)) }
        let announcement = ModeratorScript.letterAnnouncement(card.letter)
        withAnimation(.spring(duration: 0.8)) { cardRevealed = true }
        SoundFX.reveal()
        bubble = announcement.display
        await voice.say(announcement.spoken)
        if Task.isCancelled { return }
        withAnimation { readyToStart = true }
    }

    /// Vom «Los»-Knopf ausgelöst.
    func startCountdown() {
        guard phase == .intro else { return }
        flowTask?.cancel()
        app.voice.stop()
        withAnimation { cardRevealed = true }
        flowTask = Task { await runCountdown() }
    }

    private func runCountdown() async {
        // Mikrofon vorbereiten, bevor die Zeit läuft.
        if app.settings.listeningEnabled && mode == .solo {
            await prepareListening()
        }
        for (index, line) in ModeratorScript.countdown.enumerated() {
            if Task.isCancelled { return }
            phase = .countdown(3 - index)
            bubble = line.display
            SoundFX.tick()
            app.voice.speak(line.spoken)
            try? await Task.sleep(for: .milliseconds(index == 2 ? 450 : 850))
        }
        if Task.isCancelled { return }
        startPlaying()
    }

    private func prepareListening() async {
        if !AnswerListener.isAuthorized {
            let granted = await AnswerListener.requestAuthorization()
            if !granted {
                listeningError = "Mikrofon oder Spracherchennig nid erlaubt – spil mit de Chnöpf."
                return
            }
        }
        AudioSession.configure(listening: true)
        listener.onTranscript = { [weak self] text in
            self?.handleTranscript(text)
        }
        do {
            try listener.start(hints: card.questions.flatMap(\.acceptedAnswers))
            isListening = listener.isRunning
            if !isListening {
                listeningError = "Spracherchennig grad nid verfüegbar – spil mit de Chnöpf."
            }
        } catch {
            listeningError = "Mikrofon chan nid gstartet wärde – spil mit de Chnöpf."
            AudioSession.configure(listening: false)
        }
    }

    private func startPlaying() {
        round.start(at: .now)
        phase = .playing
        askCurrentQuestion()
        tickerTask?.cancel()
        tickerTask = Task { await runTicker() }
    }

    private func runTicker() async {
        while !Task.isCancelled && phase == .playing {
            remaining = round.remaining(at: .now)
            let second = Int(remaining.rounded(.up))
            if second <= 5 && second > 0 && second != lastTickSecond {
                lastTickSecond = second
                SoundFX.tick()
            }
            if remaining <= 0 {
                endRound(outOfQuestions: false)
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func askCurrentQuestion() {
        transcript = ""
        guard let question = round.currentQuestion else {
            endRound(outOfQuestions: true)
            return
        }
        bubble = question.prompt
        app.voice.speak(question.prompt)
        if isListening { listener.nextQuestion() }
    }

    // MARK: - Antworten

    func markCorrect() { answer(.correct) }
    func pass() { answer(.passed) }

    private func answer(_ outcome: AnswerOutcome) {
        guard phase == .playing, let question = round.currentQuestion else { return }
        guard round.answer(outcome, at: .now) else {
            endRound(outOfQuestions: false)
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            lastFeedback = Feedback(correct: outcome == .correct, answer: question.answer)
        }
        if outcome == .correct {
            SoundFX.correct()
        } else {
            SoundFX.pass()
        }
        if round.isFinished {
            endRound(outOfQuestions: true)
        } else {
            askCurrentQuestion()
        }
    }

    private func handleTranscript(_ text: String) {
        guard phase == .playing, let question = round.currentQuestion else { return }
        transcript = text
        if AnswerMatcher.matches(text, accepted: question.acceptedAnswers) {
            markCorrect()
        } else if AnswerMatcher.isPass(text) {
            pass()
        }
    }

    // MARK: - Schluss

    private func endRound(outOfQuestions: Bool) {
        guard phase == .playing else { return }
        round.finish(at: .now)
        remaining = round.remaining(at: .now)
        tickerTask?.cancel()
        stopListening()
        app.voice.stop()
        SoundFX.buzzer()
        withAnimation(.spring(duration: 0.5)) { phase = .finished }

        let score = round.score
        flowTask?.cancel()
        flowTask = Task {
            let end = outOfQuestions ? ModeratorScript.outOfQuestions : ModeratorScript.pick(ModeratorScript.timeUp)
            bubble = end.display
            await app.voice.say(end.spoken)
            if Task.isCancelled { return }
            let verdict = ModeratorScript.verdict(score: score, target: target)
            bubble = verdict.display
            await app.voice.say(verdict.spoken)
        }
    }

    /// Korrektur im Resultat.
    func toggle(_ questionID: String) {
        round.toggleOutcome(of: questionID)
    }

    /// Speichert das Resultat (einmal) in der Statistik.
    func commitResult() {
        guard round.isFinished, !recorded else { return }
        recorded = true
        app.record(letter: card.letter, score: round.score)
    }

    /// Räumt alles auf (Schliessen-Knopf oder Ende).
    func tearDown() {
        flowTask?.cancel()
        tickerTask?.cancel()
        stopListening()
        app.voice.stop()
        AudioSession.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func stopListening() {
        listener.stop()
        listener.onTranscript = nil
        isListening = false
    }
}
