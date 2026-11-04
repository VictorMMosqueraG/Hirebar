import Foundation

public enum SkillLevel: String, Codable, CaseIterable, Sendable {
    case expert = "domino"
    case familiar = "conozco"
    case avoid = "evito"

    public static func parse(_ text: String) -> SkillLevel? {
        let value = TextTools.normalize(text).trimmingCharacters(in: .whitespaces)
        switch value {
        case "domino", "dominio", "fuerte", "experto": return .expert
        case "conozco", "intermedio", "basico", "reto", "aprendiendo": return .familiar
        case "evito", "no", "nunca", "bloquear", "fuera": return .avoid
        default: return nil
        }
    }
}

public struct Skill: Codable, Sendable, Equatable {
    public var name: String
    public var level: SkillLevel
    public var years: Double?
    public var aliases: [String]

    public init(name: String, level: SkillLevel, years: Double? = nil, aliases: [String] = []) {
        self.name = name
        self.level = level
        self.years = years
        self.aliases = aliases
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        level = try c.decodeIfPresent(SkillLevel.self, forKey: .level) ?? .familiar
        years = try c.decodeIfPresent(Double.self, forKey: .years)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    public var searchTerms: [String] {
        var seen = Set<String>()
        return ([name] + aliases)
            .map { TextTools.normalize($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

public struct CVVariant: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var file: String
    public var focus: [String]
}

public struct Profile: Codable, Sendable {
    public var skills: [Skill]
    public var cvVariants: [CVVariant]

    public static var url: URL { Paths.workspaceFile("perfil.json") }

    public init(skills: [Skill] = [], cvVariants: [CVVariant] = []) {
        self.skills = skills
        self.cvVariants = cvVariants
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skills = try c.decodeIfPresent([Skill].self, forKey: .skills) ?? []
        cvVariants = try c.decodeIfPresent([CVVariant].self, forKey: .cvVariants) ?? []
    }

    public static func load() -> Profile {
        guard let data = try? Data(contentsOf: url) else { return Profile() }
        do {
            return try JSONDecoder().decode(Profile.self, from: data)
        } catch {
            Log.write("perfil.json tiene un error (\(error.localizedDescription)); se ignoran las habilidades")
            return Profile()
        }
    }

    public func terms(_ level: SkillLevel) -> [String] {
        skills.filter { $0.level == level }.flatMap(\.searchTerms)
    }

    public func skill(named name: String) -> Skill? {
        let wanted = TextTools.normalize(name)
        return skills.first { TextTools.normalize($0.name) == wanted || $0.searchTerms.contains(wanted.trimmingCharacters(in: .whitespaces)) }
    }

    public var summary: String {
        let groups: [(SkillLevel, String)] = [(.expert, "Domino"), (.familiar, "Conozco"), (.avoid, "Evito")]
        return groups.map { level, title in
            let names = skills.filter { $0.level == level }.map(\.name)
            return "\(title): " + (names.isEmpty ? "—" : names.joined(separator: ", "))
        }.joined(separator: "\n")
    }
}

public enum ProfileEditor {
    public enum Outcome: Equatable, Sendable {
        case added
        case updated(from: SkillLevel)
        case unchanged
        case failed(String)
    }

    @discardableResult
    public static func setSkill(_ name: String, level: SkillLevel, at url: URL = Profile.url) -> Outcome {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url) {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failed("perfil.json no es JSON válido")
            }
            root = object
        }
        var skills = root["skills"] as? [[String: Any]] ?? []
        let wanted = TextTools.normalize(name)
        let outcome: Outcome
        if let index = skills.firstIndex(where: { TextTools.normalize($0["name"] as? String ?? "") == wanted }) {
            let previous = SkillLevel(rawValue: skills[index]["level"] as? String ?? "") ?? .familiar
            if previous == level { return .unchanged }
            skills[index]["level"] = level.rawValue
            outcome = .updated(from: previous)
        } else {
            skills.append(["name": name.trimmingCharacters(in: .whitespaces), "level": level.rawValue, "aliases": [String]()])
            outcome = .added
        }
        root["skills"] = skills
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            return .failed("no pude guardar perfil.json")
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return .failed(error.localizedDescription)
        }
        return outcome
    }
}

extension SearchProfile {
    public static func loadEffective() -> SearchProfile {
        load().applying(Profile.load())
    }

    public func applying(_ profile: Profile) -> SearchProfile {
        let expert = profile.terms(.expert)
        let familiar = profile.terms(.familiar)
        let avoid = profile.terms(.avoid)
        var result = self
        func merge(_ base: [String], _ extra: [String], removing: [String] = []) -> [String] {
            var seen = Set<String>()
            let blocked = Set(removing)
            return (base + extra).filter { !blocked.contains($0) && seen.insert($0).inserted }
        }
        result.freelance.strong = merge(freelance.strong, expert, removing: avoid)
        result.freelance.stretch = merge(freelance.stretch, familiar.filter { !result.freelance.strong.contains($0) }, removing: avoid)
        result.freelance.titleBlocked = merge(freelance.titleBlocked, avoid)
        result.jobs.strong = merge(jobs.strong, expert, removing: avoid)
        result.jobs.ownStack = merge(jobs.ownStack, expert, removing: avoid)
        result.jobs.weak = merge(jobs.weak, familiar.filter { !result.jobs.strong.contains($0) }, removing: avoid)
        result.jobs.blocked = merge(jobs.blocked, avoid)
        return result
    }
}
