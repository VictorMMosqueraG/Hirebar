import XCTest
@testable import HirebarCore

final class ConfigTests: XCTestCase {
    func testReadsLegacyRadarConfig() throws {
        let legacy = """
        {"autoCorreos": true, "autoFreelance": true, "autoJobs": false, "chatId": 42, "computrabajo": false,
         "freelanceMinutes": 20, "linkedin": true, "topic": "old-topic", "workana": true}
        """
        let config = try JSONDecoder().decode(Config.self, from: Data(legacy.utf8))
        XCTAssertTrue(config.autoEmails)
        XCTAssertTrue(config.autoFreelance)
        XCTAssertFalse(config.autoJobs)
        XCTAssertEqual(config.chatId, 42)
        XCTAssertEqual(config.ntfyTopic, "old-topic")
        XCTAssertFalse(config.isEnabled("computrabajo"))
        XCTAssertTrue(config.isEnabled("linkedin"))
        XCTAssertTrue(config.isEnabled("magneto"))
    }

    func testRoundTripKeepsSources() throws {
        var config = Config()
        config.setEnabled("magneto", false)
        config.ownerName = "Ana"
        let data = try JSONEncoder().encode(config)
        let back = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertFalse(back.isEnabled("magneto"))
        XCTAssertEqual(back.ownerName, "Ana")
        XCTAssertTrue(back.jobsOn)
    }

    func testMinimumIntervals() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"freelanceMinutes": 1, "jobMinutes": 5}"#.utf8))
        XCTAssertEqual(config.freelanceMinutes, 15)
        XCTAssertEqual(config.jobMinutes, 20)
    }
}
