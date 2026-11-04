import Foundation
import HirebarCore

enum ClaudeCLI {
    static let tools = ["Read", "Write", "Edit", "Glob", "Grep", "WebFetch", "WebSearch"]
    static let authFailureHints = ["failed to authenticate", "oauth session expired", "please run /login", "invalid api key",
                                   "not logged in", "please log in", "codex login", "login required", "unauthenticated"]

    static func path() -> String? {
        let home = Paths.home.path
        let candidates = ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude",
                          "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return found }
        let out = Shell.run("/bin/zsh", ["-lc", "command -v claude"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (out?.hasPrefix("/") ?? false) ? out : nil
    }

    static func process(executable: String, prompt: String, playbook: URL, output: URL, errors: URL, browser: Bool = true) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.currentDirectoryURL = Paths.workspace
        // Sin navegador la sesión arranca más rápido (por ejemplo, para escribir una publicación).
        var arguments: [String] = ["-p", prompt]
        if browser { arguments.append("--chrome") }
        arguments += ["--permission-mode", "bypassPermissions",
                      "--tools", tools.joined(separator: ","),
                      "--append-system-prompt-file", playbook.path,
                      "--output-format", "text",
                      "--allowedTools"]
        if browser { arguments.append("mcp__claude-in-chrome") }
        arguments += tools
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPath
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try? FileHandle(forWritingTo: output)
        process.standardError = try? FileHandle(forWritingTo: errors)
        return process
    }

    static var searchPath: String {
        "\(Paths.home.path)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    static func shellProcess(command: String, environment extra: [String: String], output: URL, errors: URL) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = Paths.workspace
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPath + ":" + (env["PATH"] ?? "")
        for (key, value) in extra { env[key] = value }
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try? FileHandle(forWritingTo: output)
        process.standardError = try? FileHandle(forWritingTo: errors)
        return process
    }

    struct LaunchProblem: Error {
        let message: String
        let status: String
    }

    static func makeProcess(engine: AIEngineSettings, prompt: String, playbook: URL, output: URL, errors: URL,
                            browser: Bool = true) -> Result<Process, LaunchProblem> {
        if engine.kind == .claude {
            guard let claude = path() else {
                return .failure(LaunchProblem(
                    message: "No encontré Claude Code en el Mac. Instálalo con: curl -fsSL https://claude.ai/install.sh | bash, inicia sesión con 'claude' y vuelve a responder si. O elige otra IA en Ajustes → Motor de IA.",
                    status: "falta instalar Claude Code"))
            }
            return .success(process(executable: claude, prompt: prompt, playbook: playbook, output: output, errors: errors,
                                    browser: browser))
        }
        let command = engine.command
        guard !command.isEmpty else {
            return .failure(LaunchProblem(message: "Falta el comando de tu IA. Escríbelo en Ajustes → Motor de IA.",
                                          status: "falta configurar la IA"))
        }
        let environment = AIEngineSettings.environment(prompt: prompt, instructions: playbook)
        return .success(shellProcess(command: command, environment: environment, output: output, errors: errors))
    }

    static func loginHint(_ kind: AIEngineKind) -> String {
        switch kind {
        case .claude: return "Abre Terminal, escribe claude y luego /login."
        case .codex: return "Abre Terminal y escribe codex login."
        case .gemini: return "Abre Terminal, escribe gemini y vuelve a iniciar sesión."
        case .custom: return "Vuelve a iniciar sesión en tu IA desde la Terminal."
        }
    }

    static func isAuthFailure(_ text: String) -> Bool {
        let lower = text.lowercased()
        return authFailureHints.contains { lower.contains($0) }
    }
}
