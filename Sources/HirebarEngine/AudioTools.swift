import Foundation
import HirebarCore

/// Prepara la nota de voz de Telegram para el video. Telegram manda las notas de voz en Ogg/Opus, que macOS no
/// abre, así que Hirebar instala solo (una vez) una copia de ffmpeg en un entorno de Python propio
/// (paquete imageio-ffmpeg) y con ella convierte el audio, le quita ruido y le nivela el volumen.
enum AudioTools {
    static var folder: URL { Paths.root.appendingPathComponent("herramientas/python", isDirectory: true) }
    static var python: URL { folder.appendingPathComponent("bin/python3") }
    static var ffmpegPathFile: URL { folder.appendingPathComponent("ffmpeg-ruta.txt") }

    struct Problem: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Ruta de ffmpeg; lo instala si falta.
    static func ffmpeg() throws -> String {
        if let saved = try? String(contentsOf: ffmpegPathFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           FileManager.default.isExecutableFile(atPath: saved) {
            return saved
        }
        Log.write("Contenido: preparando la herramienta de audio (solo la primera vez)")
        if !FileManager.default.isExecutableFile(atPath: python.path) {
            let system = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
                .first { FileManager.default.isExecutableFile(atPath: $0) }
            guard let system else { throw Problem(message: "no encontré Python 3 en el Mac para preparar el audio") }
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard run(system, ["-m", "venv", folder.path], timeout: 120).ok else {
                throw Problem(message: "no pude preparar Python para el audio")
            }
        }
        let pip = folder.appendingPathComponent("bin/pip").path
        let install = run(pip, ["install", "--quiet", "--disable-pip-version-check", "imageio-ffmpeg"], timeout: 300)
        guard install.ok else { throw Problem(message: "no pude instalar la herramienta de audio: \(install.output.suffix(200))") }
        let found = run(python.path, ["-c", "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"], timeout: 60)
        let path = found.output.split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        guard found.ok, FileManager.default.isExecutableFile(atPath: path) else {
            throw Problem(message: "no encontré ffmpeg después de instalarlo")
        }
        try? path.write(to: ffmpegPathFile, atomically: true, encoding: .utf8)
        Log.write("Contenido: herramienta de audio lista")
        return path
    }

    /// Convierte la nota de voz a M4A y la deja lista para un Short: quita el silencio del inicio y del final,
    /// acorta las pausas largas entre frases (deja 0,3 s), le quita ruido de fondo y la deja con volumen de redes.
    static func prepareVoice(_ input: URL, to output: URL) throws {
        let tool = try ffmpeg()
        try? FileManager.default.removeItem(at: output)
        let trim = "silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.08,"
            + "areverse,silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.15,areverse,"
            + "silenceremove=stop_periods=-1:stop_duration=0.45:stop_threshold=-40dB:stop_silence=0.3"
        let filters = "highpass=f=80,\(trim),afftdn=nf=-25,acompressor=threshold=-18dB:ratio=3:attack=5:release=60,loudnorm=I=-14:TP=-1.5:LRA=11"
        var result = run(tool, ["-y", "-i", input.path, "-vn", "-af", filters, "-ar", "48000", "-ac", "1",
                                "-c:a", "aac", "-b:a", "192k", output.path], timeout: 180)
        if !result.ok {
            // Si algún filtro no está disponible, al menos se convierte.
            result = run(tool, ["-y", "-i", input.path, "-vn", "-ar", "48000", "-ac", "1", "-c:a", "aac", "-b:a", "192k", output.path],
                         timeout: 180)
        }
        guard result.ok, FileManager.default.fileExists(atPath: output.path) else {
            throw Problem(message: "no pude convertir el audio (\(result.output.suffix(200)))")
        }
    }

    /// Pausas de la voz (inicio y fin de cada silencio de al menos 0,18 s), para cortar las escenas donde termina cada frase.
    static func pauses(in audio: URL) -> [(start: Double, end: Double)] {
        guard let tool = try? ffmpeg() else { return [] }
        let result = run(tool, ["-hide_banner", "-i", audio.path, "-af", "silencedetect=noise=-35dB:d=0.18", "-f", "null", "-"], timeout: 60)
        var found: [(Double, Double)] = []
        var open: Double?
        for line in result.output.split(separator: "\n") {
            if let range = line.range(of: "silence_start: ") {
                open = Double(line[range.upperBound...].split(separator: " ").first ?? "")
            } else if let range = line.range(of: "silence_end: "), let start = open,
                      let end = Double(line[range.upperBound...].split(separator: " ").first ?? "") {
                found.append((start, end))
                open = nil
            }
        }
        return found.map { (start: $0.0, end: $0.1) }
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
        let reader = DispatchQueue(label: "hirebar.audio-tools.output")
        reader.async { box.data = pipe.fileHandleForReading.readDataToEndOfFile() }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        reader.sync {}
        return (process.terminationStatus == 0, String(decoding: box.data, as: UTF8.self))
    }
}
