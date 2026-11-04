import Foundation

public struct Config: Codable, Sendable {
    public static let freelanceSources = ["workana", "freelancer"]
    public static let jobSources = ["linkedin", "getonboard", "computrabajo", "elempleo", "magneto"]

    public var ownerName = "el usuario"
    public var sources: [String: Bool] = [:]
    public var chatId: Int64 = 0
    public var ntfyTopic = ""
    public var autoFreelance = false
    public var autoJobs = false
    public var autoEmails = false
    public var freelanceMinutes = 20
    public var jobMinutes = 30
    public var aiEngine = AIEngineSettings()
    public var updated = ""

    public init() {}

    enum CodingKeys: String, CodingKey {
        case ownerName, sources, chatId, ntfyTopic, autoFreelance, autoJobs, autoEmails, freelanceMinutes, jobMinutes, aiEngine, updated
    }

    struct LegacyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ownerName = try c.decodeIfPresent(String.self, forKey: .ownerName) ?? "el usuario"
        sources = try c.decodeIfPresent([String: Bool].self, forKey: .sources) ?? [:]
        chatId = try c.decodeIfPresent(Int64.self, forKey: .chatId) ?? 0
        ntfyTopic = try c.decodeIfPresent(String.self, forKey: .ntfyTopic) ?? ""
        autoFreelance = try c.decodeIfPresent(Bool.self, forKey: .autoFreelance) ?? false
        autoJobs = try c.decodeIfPresent(Bool.self, forKey: .autoJobs) ?? false
        autoEmails = try c.decodeIfPresent(Bool.self, forKey: .autoEmails) ?? false
        freelanceMinutes = max(15, try c.decodeIfPresent(Int.self, forKey: .freelanceMinutes) ?? 20)
        jobMinutes = max(20, try c.decodeIfPresent(Int.self, forKey: .jobMinutes) ?? 30)
        aiEngine = try c.decodeIfPresent(AIEngineSettings.self, forKey: .aiEngine) ?? AIEngineSettings()
        updated = try c.decodeIfPresent(String.self, forKey: .updated) ?? ""

        let legacy = try decoder.container(keyedBy: LegacyKey.self)
        for id in Self.freelanceSources + Self.jobSources where sources[id] == nil {
            if let value = try legacy.decodeIfPresent(Bool.self, forKey: LegacyKey(stringValue: id)) {
                sources[id] = value
            }
        }
        if ntfyTopic.isEmpty {
            ntfyTopic = try legacy.decodeIfPresent(String.self, forKey: LegacyKey(stringValue: "topic")) ?? ""
        }
        if let value = try legacy.decodeIfPresent(Bool.self, forKey: LegacyKey(stringValue: "autoCorreos")) {
            autoEmails = value
        }
    }

    public func isEnabled(_ source: String) -> Bool { sources[source] ?? true }

    public mutating func setEnabled(_ source: String, _ value: Bool) { sources[source] = value }

    public var freelanceOn: Bool { Self.freelanceSources.contains { isEnabled($0) } }
    public var jobsOn: Bool { Self.jobSources.contains { isEnabled($0) } }

    public static func load() -> Config {
        guard let data = try? Data(contentsOf: Paths.config),
              let config = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return config
    }

    public func save() {
        Paths.ensure()
        var copy = self
        copy.updated = ISO8601DateFormatter().string(from: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(copy) { try? data.write(to: Paths.config, options: .atomic) }
    }
}
