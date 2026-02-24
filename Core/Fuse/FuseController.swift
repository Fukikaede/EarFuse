import Core
import Foundation
import Profiles

public struct FuseActionResult: Sendable {
    public let triggered: Bool
    public let previousVolume: Float?
    public let newVolume: Float?

    public init(triggered: Bool, previousVolume: Float?, newVolume: Float?) {
        self.triggered = triggered
        self.previousVolume = previousVolume
        self.newVolume = newVolume
    }
}

public protocol SystemVolumeControlling: Sendable {
    func currentVolume() -> Float?
    func setVolume(_ value: Float)
}

public final class StubVolumeController: SystemVolumeControlling, @unchecked Sendable {
    private var volume: Float = 0.5

    public init() {}

    public func currentVolume() -> Float? {
        volume
    }

    public func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
    }
}

public final class FuseController: @unchecked Sendable {
    private let volumeController: SystemVolumeControlling
    private var candidateStartedAt: Date?
    private var didTriggerDuringCurrentSpike = false

    public init(volumeController: SystemVolumeControlling) {
        self.volumeController = volumeController
    }

    public func evaluate(snapshot: MeterSnapshot, profile: AppProfile) -> FuseActionResult {
        guard profile.fuse.enabled else {
            resetState()
            return .init(triggered: false, previousVolume: nil, newVolume: nil)
        }

        let isCandidate = snapshot.peakDBFS >= profile.fuse.absolutePeakThreshold
            && snapshot.crestFactorDB >= profile.fuse.crestThreshold

        if !isCandidate {
            resetState()
            return .init(triggered: false, previousVolume: nil, newVolume: nil)
        }

        if candidateStartedAt == nil {
            candidateStartedAt = snapshot.timestamp
            didTriggerDuringCurrentSpike = false
            return .init(triggered: false, previousVolume: nil, newVolume: nil)
        }

        guard let candidateStartedAt,
              snapshot.timestamp.timeIntervalSince(candidateStartedAt) >= profile.fuse.minimumTriggerDuration,
              !didTriggerDuringCurrentSpike else {
            return .init(triggered: false, previousVolume: nil, newVolume: nil)
        }

        didTriggerDuringCurrentSpike = true
        let previous = volumeController.currentVolume()
        volumeController.setVolume(profile.fuse.safeOutputVolume)
        return .init(triggered: true, previousVolume: previous, newVolume: profile.fuse.safeOutputVolume)
    }

    private func resetState() {
        candidateStartedAt = nil
        didTriggerDuringCurrentSpike = false
    }
}
