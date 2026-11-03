import AVFoundation
import Speech

/// Hört über das Mikrofon zu und liefert pro Frage ein frisches Transkript.
final class AnswerListener {
    /// Wird auf dem Main-Thread mit dem Transkript der aktuellen Frage aufgerufen.
    var onTranscript: ((String) -> Void)?

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = 0
    private var contextualStrings: [String] = []
    private(set) var isRunning = false

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-CH"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Fragt Spracherkennung und Mikrofon an.
    static func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    static var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    /// Startet das Mikrofon. `hints` sind Wörter, die der Erkenner bevorzugen soll (die Antworten der Karte).
    func start(hints: [String]) throws {
        guard !isRunning, let recognizer, recognizer.isAvailable else { return }
        contextualStrings = Array(hints.prefix(100))
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.lock.lock()
            let request = self.request
            self.lock.unlock()
            request?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
        nextQuestion()
    }

    /// Beginnt ein neues Transkript (bei jeder neuen Frage).
    func nextQuestion() {
        guard isRunning, let recognizer else { return }
        lock.lock()
        request?.endAudio()
        task?.cancel()
        generation += 1
        let myGeneration = generation
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.contextualStrings = contextualStrings
        if recognizer.supportsOnDeviceRecognition {
            newRequest.requiresOnDeviceRecognition = true
        }
        request = newRequest
        lock.unlock()

        let newTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            DispatchQueue.main.async {
                self.lock.lock()
                let current = self.generation
                self.lock.unlock()
                guard current == myGeneration else { return }
                self.onTranscript?(text)
            }
        }
        lock.lock()
        task = newTask
        lock.unlock()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        lock.lock()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        generation += 1
        lock.unlock()
    }
}
