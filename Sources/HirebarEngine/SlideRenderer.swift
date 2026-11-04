import Foundation
import HirebarCore

/// Convierte las láminas HTML de la publicación (1080×1350) en PNG con Chrome sin ventana.
public enum SlideRenderer {
    static let width = 1080
    static let height = 1350
    static let timeout: TimeInterval = 60

    static var folder: URL { Paths.slides }

    /// Deja la carpeta vacía antes de un borrador nuevo; lo anterior queda en linkedin/laminas-anteriores/.
    public static func prepare() {
        let fm = FileManager.default
        let previous = Paths.linkedIn.appendingPathComponent("laminas-anteriores", isDirectory: true)
        if fm.fileExists(atPath: folder.path) {
            try? fm.removeItem(at: previous)
            try? fm.moveItem(at: folder, to: previous)
        }
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    static func pages() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "html" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public static func renderAll(completion: @escaping (_ made: [URL], _ failed: Int) -> Void) {
        let sources = pages()
        DispatchQueue.global(qos: .utility).async {
            guard !sources.isEmpty else {
                Log.write("Contenido: no hay láminas en \(folder.path)")
                DispatchQueue.main.async { completion([], 0) }
                return
            }
            guard let chrome = CVRenderer.chromePath() else {
                Log.write("Contenido: no encontré Google Chrome para crear las imágenes")
                DispatchQueue.main.async { completion([], sources.count) }
                return
            }
            let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-chrome", isDirectory: true)
            var made: [URL] = []
            for source in sources {
                let target = source.deletingPathExtension().appendingPathExtension("png")
                if shoot(source, to: target, chrome: chrome, scratch: scratch) { made.append(target) }
            }
            Log.write("Contenido: \(made.count) de \(sources.count) láminas convertidas en PNG")
            DispatchQueue.main.async { completion(made, sources.count - made.count) }
        }
    }

    static func shoot(_ source: URL, to target: URL, chrome: String, scratch: URL) -> Bool {
        try? FileManager.default.removeItem(at: target)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: chrome)
        process.arguments = ["--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
                             "--user-data-dir=\(scratch.path)", "--hide-scrollbars", "--force-device-scale-factor=1",
                             "--window-size=\(width),\(height)", "--virtual-time-budget=4000",
                             "--screenshot=\(target.path)", source.absoluteString]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
        if process.isRunning { process.terminate() }
        let size = (try? FileManager.default.attributesOfItem(atPath: target.path)[.size] as? NSNumber)?.intValue ?? 0
        return size > 1000
    }
}
