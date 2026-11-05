import Foundation

/// Cambios de configuración que se aplican una sola vez sobre los archivos que la persona ya tiene,
/// para que una mejora llegue sin que tenga que editar nada.
public enum Migrations {
    /// Palabras que dejan de bloquear proyectos freelance (5 nov 2026: más fuerza al freelance).
    static let unblockTitle = ["pagina web", "sitio web", "landing", "landing page", "diseno web", "firebase",
                               "ia", "inteligencia artificial", "gpt", "chatgpt", "openai", "llm",
                               "agente de ia", "agentes de ia", "agente ia"]
    static let unblockOffProfile = ["excel", "catalogo", "catalog", "investigacion", "research"]
    static let addStretch = ["pagina web", "sitio web", "landing", "landing page", "html", "css", "firebase", "excel"]

    public static func run() {
        let defaults = UserDefaults.standard
        let key = "migracion.freelance-mas-fuerza"
        guard !defaults.bool(forKey: key) else { return }
        if FileManager.default.fileExists(atPath: Paths.searchProfile.path) {
            var profile = SearchProfile.load()
            profile.freelance = loosened(profile.freelance)
            if let data = profile.encoded() { try? data.write(to: Paths.searchProfile, options: .atomic) }
        }
        AgentStore.update(.freelance) { agent in
            if (agent.dailyLimit ?? 0) < 12 { agent.dailyLimit = 12 }
        }
        defaults.set(true, forKey: key)
        Log.write("Freelance: filtro abierto (web, Excel a sistema, IA con backend) y cupo diario de 12")
    }

    public static func loosened(_ profile: FreelanceProfile) -> FreelanceProfile {
        var result = profile
        result.titleNever.removeAll { unblockTitle.contains($0) }
        result.offProfile.removeAll { unblockOffProfile.contains($0) }
        for word in addStretch where !result.stretch.contains(word) { result.stretch.append(word) }
        return result
    }
}
