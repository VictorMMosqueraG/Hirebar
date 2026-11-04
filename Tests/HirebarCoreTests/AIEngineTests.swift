import XCTest
@testable import HirebarCore

final class AIEngineTests: XCTestCase {
    func testOldConfigDefaultsToClaude() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"chatId": 1}"#.utf8))
        XCTAssertEqual(config.aiEngine.kind, .claude)
    }

    func testCustomCommandRoundTrip() throws {
        var config = Config()
        config.aiEngine = AIEngineSettings(kind: .custom, customCommand: "  mi-ia \"$HIREBAR_PROMPT\"  ")
        let back = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(back.aiEngine.command, "mi-ia \"$HIREBAR_PROMPT\"")
        XCTAssertEqual(back.aiEngine.displayName, "la IA")
    }

    func testPresetsHaveCommands() {
        XCTAssertTrue(AIEngineSettings(kind: .codex).command.hasPrefix("codex exec"))
        XCTAssertTrue(AIEngineSettings(kind: .gemini).command.contains("gemini"))
        XCTAssertEqual(AIEngineSettings(kind: .claude).displayName, "Claude")
    }

    func testEnvironmentJoinsRulesAndPrompt() throws {
        let rules = FileManager.default.temporaryDirectory.appendingPathComponent("reglas-\(UUID().uuidString).md")
        try "Regla 1".write(to: rules, atomically: true, encoding: .utf8)
        let env = AIEngineSettings.environment(prompt: "Haz X", instructions: rules)
        XCTAssertEqual(env["HIREBAR_PROMPT"], "Haz X")
        XCTAssertEqual(env["HIREBAR_INSTRUCTIONS"], rules.path)
        XCTAssertEqual(env["HIREBAR_FULL_PROMPT"], "Regla 1\n\n---\n\nHaz X")
    }
}
