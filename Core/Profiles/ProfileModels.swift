import Foundation

public enum AppProfileKind: String, CaseIterable, Codable, Sendable {
    case production
    case listening

    public var displayName: String {
        switch self {
        case .production: return "Production"
        case .listening: return "Listening"
        }
    }
}

public struct ThresholdConfig: Codable, Sendable {
    public var yellowRMS: Float
    public var yellowDuration: TimeInterval
    public var redRMS: Float
    public var redDuration: TimeInterval
    public var recoveryDuration: TimeInterval

    public init(
        yellowRMS: Float,
        yellowDuration: TimeInterval,
        redRMS: Float,
        redDuration: TimeInterval,
        recoveryDuration: TimeInterval
    ) {
        self.yellowRMS = yellowRMS
        self.yellowDuration = yellowDuration
        self.redRMS = redRMS
        self.redDuration = redDuration
        self.recoveryDuration = recoveryDuration
    }
}

public struct FuseConfig: Codable, Sendable {
    public var enabled: Bool
    public var absolutePeakThreshold: Float
    public var crestThreshold: Float
    public var minimumTriggerDuration: TimeInterval
    public var safeOutputVolume: Float

    public init(
        enabled: Bool,
        absolutePeakThreshold: Float,
        crestThreshold: Float,
        minimumTriggerDuration: TimeInterval,
        safeOutputVolume: Float
    ) {
        self.enabled = enabled
        self.absolutePeakThreshold = absolutePeakThreshold
        self.crestThreshold = crestThreshold
        self.minimumTriggerDuration = minimumTriggerDuration
        self.safeOutputVolume = safeOutputVolume
    }
}

public struct AppProfile: Codable, Sendable {
    public var kind: AppProfileKind
    public var threshold: ThresholdConfig
    public var fuse: FuseConfig

    public init(kind: AppProfileKind, threshold: ThresholdConfig, fuse: FuseConfig) {
        self.kind = kind
        self.threshold = threshold
        self.fuse = fuse
    }
}

public enum DefaultProfiles {
    public static let production = AppProfile(
        kind: .production,
        threshold: .init(
            yellowRMS: -18,
            yellowDuration: 10,
            redRMS: -12,
            redDuration: 5,
            recoveryDuration: 2
        ),
        fuse: .init(
            enabled: false,
            absolutePeakThreshold: -1,
            crestThreshold: 12,
            minimumTriggerDuration: 0.03,
            safeOutputVolume: 0.1
        )
    )

    public static let listening = AppProfile(
        kind: .listening,
        threshold: .init(
            yellowRMS: -20,
            yellowDuration: 15,
            redRMS: -14,
            redDuration: 6,
            recoveryDuration: 2
        ),
        fuse: .init(
            enabled: true,
            absolutePeakThreshold: -1,
            crestThreshold: 12,
            minimumTriggerDuration: 0.03,
            safeOutputVolume: 0.1
        )
    )
}
