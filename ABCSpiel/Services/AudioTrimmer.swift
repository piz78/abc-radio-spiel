import AVFoundation

/// Schneidet Stille am Anfang und Ende einer Aufnahme weg.
/// Wichtig für Bausteine («Du hesch» + «föifevierzg» + «Sekunde.»): ohne Zuschnitt entstünden
/// zwischen den Teilen Löcher, weil man beim Antippen nie ganz genau zu reden beginnt.
enum AudioTrimmer {
    /// Liest `source`, schneidet zu und schreibt das Resultat als m4a nach `destination`.
    /// Gibt `false` zurück, wenn nichts geschrieben wurde – dann das Original verwenden.
    static func trimSilence(source: URL, destination: URL, padding: Double = 0.06) -> Bool {
        do {
            let input = try AVAudioFile(forReading: source)
            let format = input.processingFormat
            let length = AVAudioFrameCount(input.length)
            guard length > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length) else { return false }
            try input.read(into: buffer)
            guard let range = speechRange(buffer, padding: padding),
                  let trimmed = copy(buffer, range: range)
            else { return false }
            fade(trimmed, seconds: 0.005)
            try? FileManager.default.removeItem(at: destination)
            try write(trimmed, to: destination)
            return true
        } catch {
            try? FileManager.default.removeItem(at: destination)
            return false
        }
    }

    /// Bereich mit Sprache (in Frames), inklusive etwas Rand.
    static func speechRange(_ buffer: AVAudioPCMBuffer, padding: Double) -> Range<Int>? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let frames = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        let window = max(1, Int(sampleRate * 0.01))
        let windows = frames / window
        guard windows > 2 else { return nil }

        var levels = [Float](repeating: 0, count: windows)
        var peak: Float = 0
        for w in 0..<windows {
            var sum: Float = 0
            let base = w * window
            for i in 0..<window {
                let v = channel[base + i]
                sum += v * v
            }
            levels[w] = (sum / Float(window)).squareRoot()
            peak = max(peak, levels[w])
        }
        // Rund 28 dB unter dem lautesten Teil gilt als Stille (aber nie unter dem Grundrauschen).
        let threshold = max(peak * 0.04, 0.002)
        guard let first = levels.firstIndex(where: { $0 > threshold }),
              let last = levels.lastIndex(where: { $0 > threshold })
        else { return nil }

        let pad = Int(sampleRate * padding)
        let start = max(0, first * window - pad)
        let end = min(frames, (last + 1) * window + pad)
        guard end - start > Int(sampleRate * 0.1) else { return nil }
        return start..<end
    }

    private static func copy(_ buffer: AVAudioPCMBuffer, range: Range<Int>) -> AVAudioPCMBuffer? {
        let count = range.count
        guard let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(count)),
              let src = buffer.floatChannelData, let dst = out.floatChannelData
        else { return nil }
        out.frameLength = AVAudioFrameCount(count)
        for ch in 0..<Int(buffer.format.channelCount) {
            dst[ch].update(from: src[ch] + range.lowerBound, count: count)
        }
        return out
    }

    /// Kurzes Ein- und Ausblenden gegen Knackser an den Schnittstellen.
    private static func fade(_ buffer: AVAudioPCMBuffer, seconds: Double) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let n = min(frames / 2, Int(buffer.format.sampleRate * seconds))
        guard n > 0 else { return }
        for ch in 0..<Int(buffer.format.channelCount) {
            for i in 0..<n {
                let gain = Float(i) / Float(n)
                data[ch][i] *= gain
                data[ch][frames - 1 - i] *= gain
            }
        }
    }

    private static func write(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: buffer.format.sampleRate,
            AVNumberOfChannelsKey: Int(buffer.format.channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        // Die Datei wird geschlossen, sobald `file` den Gültigkeitsbereich verlässt.
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }
}
