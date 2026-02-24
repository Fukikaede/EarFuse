import Core
import Foundation
import Policy
import Profiles
import XCTest

final class PolicyEngineTests: XCTestCase {
    func testPolicyRequiresDurationBeforeDanger() {
        let engine = PolicyEngine()
        let profile = DefaultProfiles.listening
        let baseTime = Date()

        let first = engine.evaluate(
            snapshot: MeterSnapshot(timestamp: baseTime, peakDBFS: -3, rmsDBFS: -10),
            profile: profile
        )

        let second = engine.evaluate(
            snapshot: MeterSnapshot(
                timestamp: baseTime.addingTimeInterval(profile.threshold.redDuration + 0.2),
                peakDBFS: -3,
                rmsDBFS: -10
            ),
            profile: profile
        )

        XCTAssertEqual(first.level, .safe)
        XCTAssertEqual(second.level, .red)
    }
}
