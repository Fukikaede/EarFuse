import Core
import Foundation

public protocol Alerting: Sendable {
    func onSafetyLevelChanged(_ level: SafetyLevel)
}

public final class NoopAlertService: Alerting {
    public init() {}
    public func onSafetyLevelChanged(_ level: SafetyLevel) {
        _ = level
    }
}
