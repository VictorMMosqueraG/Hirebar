import Foundation

public enum AIEngineKind: String, Codable, CaseIterable, Sendable {
    case claude
    case codex
    case gemini
    case custom

    public var title: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex (OpenAI)"
        case .gemini: return "Gemini CLI (Google)"
        case .custom: return "Otra IA (comando propio)"
        }
    }

    public var shortName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .custom: return "la IA"
        }
    }

    public var summary: String {
        switch self {
        case .claude:
            return "Recomendado. Usa tu Chrome con la extensión Claude in Chrome. Instálalo con: curl -fsSL https://claude.ai/install.sh | bash y entra con claude."
        case .codex:
            return "Instálalo con: npm i -g @openai/codex y entra con codex login. Para usar el navegador necesita un servidor MCP de Chrome configurado en ~/.codex/config.toml."
        case .gemini:
            return "Instálalo con: npm i -g @google/gemini-cli y entra con gemini. Para usar el navegador necesita un servidor MCP de Chrome configurado en ~/.gemini/settings.json."
        case .custom:
            return "Escribe el comando de tu IA. Hirebar le pasa el trabajo en variables de entorno (ver abajo) y lee lo que imprima como respuesta."
        }
    }

    public var commandTemplate: String {
        switch self {
        case .claude:
            return ""
        case .codex:
            return #"codex exec --sandbox workspace-write --skip-git-repo-check -C "$HIREBAR_WORKSPACE" "$HIREBAR_FULL_PROMPT""#
        case .gemini:
            return #"GEMINI_CLI_TRUST_WORKSPACE=true gemini --approval-mode yolo -p "$HIREBAR_FULL_PROMPT""#
        case .custom:
            return ""
        }
    }

    public var browserHint: String {
        switch self {
        case .claude: return "Usa su navegador con las herramientas de Claude in Chrome."
        default: return "Usa su navegador Chrome con las herramientas de navegador que tengas disponibles."
        }
    }
}

public struct AIEngineSettings: Codable, Sendable, Equatable {
    public var kind: AIEngineKind = .claude
    public var customCommand: String = ""

    public init(kind: AIEngineKind = .claude, customCommand: String = "") {
        self.kind = kind
        self.customCommand = customCommand
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(AIEngineKind.self, forKey: .kind) ?? .claude
        customCommand = try c.decodeIfPresent(String.self, forKey: .customCommand) ?? ""
    }

    public var command: String {
        kind == .custom ? customCommand.trimmingCharacters(in: .whitespacesAndNewlines) : kind.commandTemplate
    }

    public var displayName: String {
        kind == .custom ? "la IA" : kind.shortName
    }

    public static let variablesHelp = """
    $HIREBAR_PROMPT: el pedido de esta corrida.
    $HIREBAR_INSTRUCTIONS: ruta del archivo con las reglas de la tarea (instrucciones-*.md).
    $HIREBAR_FULL_PROMPT: reglas + pedido en un solo texto (para IA sin opción de reglas aparte).
    $HIREBAR_WORKSPACE: carpeta de trabajo (también es la carpeta actual).
    """

    public static func environment(prompt: String, instructions: URL) -> [String: String] {
        let rules = (try? String(contentsOf: instructions, encoding: .utf8)) ?? ""
        let full = rules.isEmpty ? prompt : "\(rules)\n\n---\n\n\(prompt)"
        return [
            "HIREBAR_PROMPT": prompt,
            "HIREBAR_INSTRUCTIONS": instructions.path,
            "HIREBAR_FULL_PROMPT": full,
            "HIREBAR_WORKSPACE": Paths.workspace.path,
        ]
    }
}
