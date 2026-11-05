import Foundation
import HirebarCore

public enum FreelanceClassifier {
    public static func looksEnglish(_ text: String) -> Bool {
        let t = TextTools.normalize(text)
        let en = TextTools.countWords(t, ["the", "and", "with", "for", "you", "we", "our", "need", "looking", "will", "to", "of", "is"])
        let es = TextTools.countWords(t, ["el", "la", "los", "las", "de", "del", "con", "para", "que", "y", "un", "una", "en", "se"])
        return en >= 3 && en > es
    }

    static let aiWords = ["ia", "inteligencia artificial", "gpt", "chatgpt", "openai", "llm", "agente de ia", "agentes de ia", "agente ia"]

    public static func classify(head: String, body: String, title: String = "", profile: FreelanceProfile) -> Fit? {
        verdict(head: head, body: body, title: title, profile: profile).fit
    }

    /// Igual que classify, pero dice por qué se descartó (para el registro).
    public static func verdict(head: String, body: String, title: String = "", profile: FreelanceProfile) -> (fit: Fit?, reason: String) {
        if looksEnglish("\(title.isEmpty ? head : title) \(body)") { return (nil, "en inglés") }
        let h = TextTools.normalize(head)
        let tt = TextTools.normalize(title.isEmpty ? head : title)
        let all = TextTools.normalize(head + " " + body)
        func first(_ words: [String], in text: String) -> String? { words.first { TextTools.containsWord(text, $0) } }
        func count(_ words: [String], in text: String) -> Int { words.filter { TextTools.containsWord(text, $0) }.count }

        if let word = first(profile.hardBlocked, in: all) { return (nil, "palabra bloqueada \"\(word)\"") }
        if let word = first(profile.titleBlocked, in: tt) { return (nil, "título con \"\(word)\"") }
        if let word = first(profile.titleNever, in: tt) { return (nil, "título con \"\(word)\"") }
        if tt.contains(" whatsapp ") && profile.whatsappBotWords.contains(where: { tt.contains($0) }) { return (nil, "bot de WhatsApp") }
        if let word = first(profile.offProfile, in: h) { return (nil, "fuera de perfil \"\(word)\"") }
        let headStrong = count(profile.strong, in: h)
        // Proyectos con IA: solo si el núcleo es backend (APIs, integraciones, bases de datos…).
        if headStrong == 0 && count(profile.strong, in: all) < 2, let word = first(aiWords, in: tt) {
            return (nil, "IA sin backend (\(word))")
        }
        if headStrong < 3, let word = first(profile.stackBlocked, in: all) { return (nil, "pide \(word)") }
        let headStretch = count(profile.stretch, in: h)
        let allStrong = count(profile.strong, in: all)
        let allStretch = count(profile.stretch, in: all)
        if headStrong == 0, let word = first(profile.frontendOnly, in: h) { return (nil, "solo frontend (\(word))") }
        if headStrong >= 1 && allStrong >= 2 && headStretch == 0 { return (.strong, "") }
        if headStrong >= 2 { return (.strong, "") }
        if headStrong + headStretch >= 1 && allStrong + allStretch >= 2 { return (.stretch, "") }
        let offAnywhere = first(profile.offProfile, in: all)
        if allStrong >= 4 && headStretch == 0 && offAnywhere == nil { return (.strong, "") }
        if allStrong >= 2 && offAnywhere == nil { return (.stretch, "") }
        if let offAnywhere { return (nil, "fuera de perfil \"\(offAnywhere)\"") }
        return (nil, "sin palabras de tu stack")
    }

    /// Resumen corto de los motivos de descarte: "en inglés 18, título con "ia" 3 (ej: …)".
    public static func summary(_ reasons: [(reason: String, title: String)]) -> String {
        let grouped = Dictionary(grouping: reasons, by: \.reason)
        return grouped.sorted { $0.value.count > $1.value.count }.prefix(6).map { reason, items in
            "\(reason) \(items.count) (ej: \(String(items[0].title.prefix(50))))"
        }.joined(separator: "; ")
    }
}
