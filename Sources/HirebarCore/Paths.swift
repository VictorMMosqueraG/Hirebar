import CryptoKit
import Foundation

public enum Paths {
    public static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    public static var root: URL {
        if let custom = ProcessInfo.processInfo.environment["HIREBAR_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return home.appendingPathComponent("Library/Application Support/Hirebar", isDirectory: true)
    }

    public static var config: URL { root.appendingPathComponent("config.json") }
    public static var searchProfile: URL { workspace.appendingPathComponent("search-profile.json") }
    public static var workspace: URL { root.appendingPathComponent("workspace", isDirectory: true) }
    public static var runs: URL { workspace.appendingPathComponent("ejecuciones", isDirectory: true) }
    public static var reports: URL { workspace.appendingPathComponent("informes", isDirectory: true) }
    public static var prospecting: URL { workspace.appendingPathComponent("prospeccion", isDirectory: true) }
    public static var linkedIn: URL { workspace.appendingPathComponent("linkedin", isDirectory: true) }
    public static var logs: URL { home.appendingPathComponent("Library/Logs/Hirebar", isDirectory: true) }
    public static var log: URL { logs.appendingPathComponent("hirebar.log") }

    public static func workspaceFile(_ name: String) -> URL {
        workspace.appendingPathComponent(name)
    }

    public static func playbook(for mode: Mode) -> URL {
        switch mode {
        case .linkedInDraft: return workspace.appendingPathComponent("instrucciones-contenido.md")
        case .linkedInPublish: return workspace.appendingPathComponent("instrucciones-contenido-publicar.md")
        default: return workspace.appendingPathComponent("instrucciones-\(mode.rawValue).md")
        }
    }

    /// Una carpeta por cuenta de contenido (borrador, láminas y temas usados).
    public static var content: URL { workspace.appendingPathComponent("contenido", isDirectory: true) }

    public static func ensure() {
        for dir in [root, workspace, runs, reports, prospecting, linkedIn, content, logs] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Huellas de versiones anteriores de las plantillas. Si el archivo instalado es una de ellas (no lo editaste),
    /// se reemplaza por la versión nueva; si lo editaste, se deja como está.
    static let previousVersions: [String: Set<String>] = [
        "instrucciones-contenido.md": ["7d0570183da32781761a75b9ababc55aeaa9984431225a254c776db5ee110bc5"],
        "instrucciones-contenido-publicar.md": ["c84254fb1ade7117e9289e504c73a1851d07b9912eaf9c6aca9eb170c6b8ae5d"],
    ]

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func installTemplates(from bundled: URL?) {
        guard let bundled else { return }
        ensure()
        let fm = FileManager.default
        let pairs: [(String, URL)] = [
            ("inicial", workspace),
        ]
        for (folder, target) in pairs {
            let source = bundled.appendingPathComponent(folder)
            guard let files = try? fm.contentsOfDirectory(atPath: source.path) else { continue }
            for name in files where !name.hasPrefix(".") {
                let destination = target.appendingPathComponent(name)
                let original = source.appendingPathComponent(name)
                if !fm.fileExists(atPath: destination.path) {
                    try? fm.copyItem(at: original, to: destination)
                } else if let installed = try? Data(contentsOf: destination),
                          let fresh = try? Data(contentsOf: original), installed != fresh,
                          previousVersions[name]?.contains(sha256(installed)) == true {
                    // Una versión anterior de Hirebar que nadie editó: se cambia por la nueva.
                    try? fresh.write(to: destination, options: .atomic)
                }
            }
        }
    }
}
