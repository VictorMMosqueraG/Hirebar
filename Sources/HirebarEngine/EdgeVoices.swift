import Foundation
import HirebarCore

/// Voces neuronales de Microsoft por medio de edge-tts (https://github.com/rany2/edge-tts), sin cuenta ni clave.
/// Hirebar lo instala solo, una vez, en un entorno de Python propio dentro de su carpeta de datos.
public enum EdgeVoices {
    static var folder: URL { Paths.root.appendingPathComponent("herramientas/edge-tts", isDirectory: true) }
    static var command: URL { folder.appendingPathComponent("bin/edge-tts") }
    static let rate = "+8%"

    struct Problem: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Ruta de edge-tts; lo instala si falta.
    static func ensureInstalled() throws -> URL {
        if FileManager.default.isExecutableFile(atPath: command.path) { return command }
        Log.write("Contenido: instalando edge-tts (solo la primera vez)")
        let python = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let python else { throw Problem(message: "no encontré Python 3 en el Mac para instalar la voz") }
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard run(python, ["-m", "venv", folder.path], timeout: 120).ok else {
            throw Problem(message: "no pude preparar Python para la voz")
        }
        let pip = folder.appendingPathComponent("bin/pip").path
        let install = run(pip, ["install", "--quiet", "--disable-pip-version-check", "edge-tts"], timeout: 300)
        guard install.ok, FileManager.default.isExecutableFile(atPath: command.path) else {
            throw Problem(message: "no pude instalar edge-tts: \(install.output.suffix(200))")
        }
        Log.write("Contenido: edge-tts instalado")
        return command
    }

    static func speak(_ text: String, voice: String, to file: URL) throws -> Narration {
        let tool = try ensureInstalled()
        try? FileManager.default.removeItem(at: file)
        let result = run(tool.path, ["--voice", voice, "--rate=\(rate)", "--text", text, "--write-media", file.path], timeout: 90)
        guard result.ok, let length = SpeechVoices.duration(file) else {
            throw Problem(message: "la voz de Microsoft no respondió (\(result.output.suffix(160)))")
        }
        return Narration(file: file, duration: length, words: nil)
    }

    /// Voces en español disponibles (para escoger en Ajustes). Colombia primero.
    public static func spanishVoices() -> [(id: String, name: String)] {
        guard let tool = try? ensureInstalled() else { return [] }
        let result = run(tool.path, ["--list-voices"], timeout: 60)
        guard result.ok else { return [] }
        let voices = result.output.split(separator: "\n").compactMap { line -> (id: String, name: String)? in
            let columns = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let id = columns.first, id.hasPrefix("es-") else { return nil }
            let gender = columns.count > 1 ? (columns[1] == "Male" ? "hombre" : "mujer") : ""
            let parts = id.split(separator: "-")
            let name = parts.count >= 3 ? parts[2].replacingOccurrences(of: "Neural", with: "") : id
            let country = parts.count >= 2 ? String(parts[1]) : ""
            return (id, "\(name) · \(country) · \(gender)")
        }
        func rank(_ id: String) -> Int { id.hasPrefix("es-CO") ? 0 : (id.hasPrefix("es-ES") ? 2 : 1) }
        return voices.sorted { (rank($0.id), $0.name) < (rank($1.id), $1.name) }
    }

    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval) -> (ok: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return (false, "no se pudo ejecutar \(path)") }
        final class Box: @unchecked Sendable { var data = Data() }
        let box = Box()
        let reader = DispatchQueue(label: "hirebar.edge-tts.output")
        reader.async { box.data = pipe.fileHandleForReading.readDataToEndOfFile() }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        reader.sync {}
        return (process.terminationStatus == 0, String(decoding: box.data, as: UTF8.self))
    }
}
