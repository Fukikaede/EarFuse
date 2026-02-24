import Foundation

public struct MeterSnapshot: Sendable {
    public let timestamp: Date
    public let peakDBFS: Float
    public let rmsDBFS: Float

    public init(timestamp: Date = Date(), peakDBFS: Float, rmsDBFS: Float) {
        self.timestamp = timestamp
        self.peakDBFS = peakDBFS
        self.rmsDBFS = rmsDBFS
    }

    public var crestFactorDB: Float {
        peakDBFS - rmsDBFS
    }
}

public enum SafetyLevel: String, Codable, Sendable {
    case safe
    case yellow
    case red
}

public struct MeterStatus: Sendable {
    public let snapshot: MeterSnapshot
    public let level: SafetyLevel

    public init(snapshot: MeterSnapshot, level: SafetyLevel) {
        self.snapshot = snapshot
        self.level = level
    }
}
