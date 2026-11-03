import Foundation

/// Findet die Audiodatei zu einem Clip-Schlüssel.
/// Reihenfolge: eigene Aufnahme (Dokumente/Stimm) → mitgelieferter Clip (Resources/Clips) → keine.
@MainActor
final class ClipLibrary {
    static let audioExtensions = ["m4a", "wav", "caf", "mp3", "aiff"]

    /// Eigene Aufnahmen und mitgelieferte Clips verwenden.
    var isEnabled = true

    let recordingsDirectory: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingsDirectory = documents.appendingPathComponent("Stimm", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    /// Wo eine eigene Aufnahme gespeichert wird.
    func recordingURL(for key: String) -> URL {
        recordingsDirectory.appendingPathComponent("\(key).m4a")
    }

    func hasRecording(_ key: String) -> Bool {
        !key.isEmpty && FileManager.default.fileExists(atPath: recordingURL(for: key).path)
    }

    func bundledURL(for key: String) -> URL? {
        guard !key.isEmpty else { return nil }
        for ext in Self.audioExtensions {
            if let url = Bundle.main.url(forResource: key, withExtension: ext) { return url }
        }
        return nil
    }

    /// Die Datei, die im Spiel abgespielt wird – oder `nil` (dann spricht die iOS-Stimme).
    func url(for key: String) -> URL? {
        guard isEnabled, !key.isEmpty else { return nil }
        if hasRecording(key) { return recordingURL(for: key) }
        return bundledURL(for: key)
    }

    func deleteRecording(_ key: String) {
        try? FileManager.default.removeItem(at: recordingURL(for: key))
    }

    /// Alle eigenen Aufnahmen (zum Exportieren an den Mac).
    func allRecordings() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { Self.audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Anzahl mitgelieferter (generierter) Clips im App-Bundle.
    lazy var bundledCount: Int = {
        guard let resources = Bundle.main.resourceURL,
              let files = try? FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
        else { return 0 }
        return files.filter {
            Self.audioExtensions.contains($0.pathExtension.lowercased())
                && ($0.lastPathComponent.hasPrefix("q-") || $0.lastPathComponent.contains("-"))
        }.count
    }()
}
