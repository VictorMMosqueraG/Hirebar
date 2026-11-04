import AVFoundation
import Foundation
import HirebarCore

/// Voces en español que trae macOS (las del comando `say`). Las "Mejorada" o "Premium" suenan más naturales;
/// se descargan en Ajustes del Sistema → Accesibilidad → Contenido leído → Voz del sistema → Gestionar voces.
public enum SpeechVoices {
    static let rate = 195
    static let preferred = [
        "Paulina (Premium)", "Paulina (Enhanced)", "Paulina (Mejorada)",
        "Mónica (Premium)", "Mónica (Enhanced)", "Mónica (Mejorada)",
        "Paulina", "Mónica", "Juan", "Jorge", "Diego",
    ]

    /// Nombres de las voces en español instaladas en este Mac.
    public static func spanishNames() -> [String] {
        guard let list = Shell.run("/usr/bin/say", ["-v", "?"]) else { return [] }
        return list.split(separator: "\n").compactMap { line -> String? in
            let text = String(line)
            guard let range = text.range(of: #"^(.+?)\s+(es_[A-Z0-9]{2,3})\s+#"#, options: .regularExpression) else { return nil }
            let head = String(text[range])
            guard let localeRange = head.range(of: #"\s+es_[A-Z0-9]{2,3}\s+#$"#, options: .regularExpression) else { return nil }
            return String(head[..<localeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
    }

    /// La voz elegida si está instalada; si no, la mejor voz en español disponible.
    static func pick(_ chosen: String) -> String? {
        let installed = spanishNames()
        if !chosen.isEmpty, installed.contains(chosen) { return chosen }
        return preferred.first(where: { installed.contains($0) }) ?? installed.first
    }

    static func speak(_ text: String, voice: String, to file: URL) -> Bool {
        try? FileManager.default.removeItem(at: file)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", voice, "-r", String(rate), "-o", file.path, text]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let deadline = Date().addingTimeInterval(60)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if process.isRunning { process.terminate() }
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
        return size > 1000
    }

    static func duration(_ file: URL) -> Double? {
        guard let audio = try? AVAudioFile(forReading: file), audio.fileFormat.sampleRate > 0 else { return nil }
        let seconds = Double(audio.length) / audio.fileFormat.sampleRate
        return seconds > 0.2 ? seconds : nil
    }
}
