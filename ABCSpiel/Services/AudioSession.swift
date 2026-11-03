import AVFoundation

/// Konfiguriert die geteilte Audio-Session für Sprachausgabe bzw. Sprachausgabe + Mikrofon.
enum AudioSession {
    static func configure(listening: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if listening {
                try session.setCategory(.playAndRecord, mode: .default,
                                        options: [.defaultToSpeaker, .duckOthers, .allowBluetoothA2DP])
            } else {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            }
            try session.setActive(true)
        } catch {
            print("AudioSession: \(error)")
        }
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
