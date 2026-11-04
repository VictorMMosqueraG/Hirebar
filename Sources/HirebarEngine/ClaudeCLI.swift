import Foundation
import HirebarCore

enum ClaudeCLI {
    static let tools = ["Read", "Write", "Edit", "Glob", "Grep", "WebFetch", "WebSearch"]
    static let authFailureHints = ["failed to authenticate", "oauth session expired", "please run /login", "invalid api key", "not logged in"]

    static func path() -> String? {
        let home = Paths.home.path
        let candidates = ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude",
                          "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return found }
        let out = Shell.run("/bin/zsh", ["-lc", "command -v claude"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (out?.hasPrefix("/") ?? false) ? out : nil
    }

    static func process(executable: String, prompt: String, playbook: URL, output: URL, errors: URL) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.currentDirectoryURL = Paths.workspace
        process.arguments = ["-p", prompt,
                             "--chrome",
                             "--permission-mode", "bypassPermissions",
                             "--tools", tools.joined(separator: ","),
                             "--append-system-prompt-file", playbook.path,
                             "--output-format", "text",
                             "--allowedTools", "mcp__claude-in-chrome"] + tools
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "\(Paths.home.path)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try? FileHandle(forWritingTo: output)
        process.standardError = try? FileHandle(forWritingTo: errors)
        return process
    }

    static func isAuthFailure(_ text: String) -> Bool {
        let lower = text.lowercased()
        return authFailureHints.contains { lower.contains($0) }
    }
}
