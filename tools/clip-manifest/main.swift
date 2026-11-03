// Gibt alle Sprech-Clips als JSON aus (für tools/voice/generate_clips.py).
// Aufruf: swift run abc-clips ABCSpiel/Resources/fragen.txt
import ABCCore
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Aufruf: abc-clips <fragen.txt>\n".utf8))
    exit(2)
}
do {
    let text = try String(contentsOfFile: arguments[1], encoding: .utf8)
    FileHandle.standardOutput.write(try ClipCatalog.manifestJSON(questionsText: text))
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("Fehler: \(error)\n".utf8))
    exit(1)
}
