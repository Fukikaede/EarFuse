import Core
import Foundation
import Profiles

public struct PolicyDecision: Sendable {
    public let level: SafetyLevel
    public let didStartEvent: Bool

    public init(level: SafetyLevel, didStartEvent: Bool) {
        self.level = level
        self.didStartEvent = didStartEvent
    }
}

public final class PolicyEngine: @unchecked Sendable {
    private var dangerStartedAt: Date?
    private var recoveryStartedAt: Date?
    private var currentLevel: SafetyLevel = .safe

    public init() {}

    public func evaluate(snapshot: MeterSnapshot, profile: AppProfile) -> PolicyDecision {
        let now = snapshot.timestamp
        let threshold = profile.threshold
        let instantaneousLevel: SafetyLevel

        if snapshot.rmsDBFS >= threshold.redRMS {
            instantaneousLevel = .red
        } else if snapshot.rmsDBFS >= threshold.yellowRMS {
            instantaneousLevel = .yellow
        } else {
            instantaneousLevel = .safe
        }

        if instantaneousLevel == .safe {
            dangerStartedAt = nil
            if recoveryStartedAt == nil {
                recoveryStartedAt = now
            }

            if currentLevel != .safe,
               let recoveryStartedAt,
               now.timeIntervalSince(recoveryStartedAt) >= threshold.recoveryDuration {
                currentLevel = .safe
                return .init(level: .safe, didStartEvent: false)
            }
            return .init(level: currentLevel, didStartEvent: false)
        }

        recoveryStartedAt = nil
        if dangerStartedAt == nil {
            dangerStartedAt = now
        }

        guard let dangerStartedAt else {
            return .init(level: currentLevel, didStartEvent: false)
        }

        let minDuration = instantaneousLevel == .red ? threshold.redDuration : threshold.yellowDuration
        if now.timeIntervalSince(dangerStartedAt) >= minDuration {
            let isNewEvent = currentLevel == .safe
            currentLevel = instantaneousLevel
            return .init(level: currentLevel, didStartEvent: isNewEvent)
        }

        return .init(level: currentLevel, didStartEvent: false)
    }
}
