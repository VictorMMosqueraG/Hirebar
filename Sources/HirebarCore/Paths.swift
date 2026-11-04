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
        workspace.appendingPathComponent("instrucciones-\(mode.rawValue).md")
    }

    public static func ensure() {
        for dir in [root, workspace, runs, reports, prospecting, linkedIn, logs] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
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
                if !fm.fileExists(atPath: destination.path) {
                    try? fm.copyItem(at: source.appendingPathComponent(name), to: destination)
                }
            }
        }
    }
}
