import Accelerate
import Core
import Foundation

public final class MeterCalculator: Sendable {
    public init() {}

    public func calculate(samples: [Float], timestamp: Date) -> MeterSnapshot {
        guard !samples.isEmpty else {
            return MeterSnapshot(timestamp: timestamp, peakDBFS: -120, rmsDBFS: -120)
        }

        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))

        var meanSquare: Float = 0
        vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(samples.count))
        let rms = sqrtf(meanSquare)

        return MeterSnapshot(
            timestamp: timestamp,
            peakDBFS: toDBFS(peak),
            rmsDBFS: toDBFS(rms)
        )
    }

    private func toDBFS(_ value: Float) -> Float {
        let clamped = max(value, 0.000_001)
        return 20 * log10f(clamped)
    }
}
