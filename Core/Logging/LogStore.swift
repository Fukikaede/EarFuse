import Core
import Foundation

public struct SafetyEvent: Codable, Sendable {
    public let startTime: Date
    public let endTime: Date
    public let maxPeakDBFS: Float
    public let maxRMSDBFS: Float
    public let classification: SafetyLevel
    public let triggeredFuse: Bool

    public init(
        startTime: Date,
        endTime: Date,
        maxPeakDBFS: Float,
        maxRMSDBFS: Float,
        classification: SafetyLevel,
        triggeredFuse: Bool
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.maxPeakDBFS = maxPeakDBFS
        self.maxRMSDBFS = maxRMSDBFS
        self.classification = classification
        self.triggeredFuse = triggeredFuse
    }

    public var duration: TimeInterval {
        max(0, endTime.timeIntervalSince(startTime))
    }
}

public struct DailySummary: Sendable {
    public let date: Date
    public let yellowSeconds: TimeInterval
    public let redSeconds: TimeInterval
    public let maxPeakDBFS: Float
    public let maxRMSDBFS: Float
    public let fuseCount: Int
}

public final class LogStore: @unchecked Sendable {
    public private(set) var events: [SafetyEvent] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = appSupport.appendingPathComponent("EarFuse", isDirectory: true)
        self.fileURL = fileURL ?? folder.appendingPathComponent("events.json")

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    public func append(_ event: SafetyEvent) {
        events.append(event)
        persist()
    }

    public func recentEvents(limit: Int) -> [SafetyEvent] {
        Array(events.suffix(limit).reversed())
    }

    public func todaySummary(calendar: Calendar = .current) -> DailySummary {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        return buildSummary(for: start, end: end, calendar: calendar)
    }

    public func weekTotals(calendar: Calendar = .current) -> (yellow: TimeInterval, red: TimeInterval) {
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
            ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now

        var yellow: TimeInterval = 0
        var red: TimeInterval = 0

        for event in events where event.startTime >= start && event.startTime < end {
            if event.classification == .yellow {
                yellow += event.duration
            } else if event.classification == .red {
                red += event.duration
            }
        }

        return (yellow, red)
    }

    private func buildSummary(for start: Date, end: Date, calendar: Calendar) -> DailySummary {
        var yellow: TimeInterval = 0
        var red: TimeInterval = 0
        var maxPeak: Float = -120
        var maxRMS: Float = -120
        var fuseCount = 0

        for event in events where event.startTime >= start && event.startTime < end {
            if event.classification == .yellow {
                yellow += event.duration
            } else if event.classification == .red {
                red += event.duration
            }

            maxPeak = max(maxPeak, event.maxPeakDBFS)
            maxRMS = max(maxRMS, event.maxRMSDBFS)
            if event.triggeredFuse { fuseCount += 1 }
        }

        return DailySummary(
            date: calendar.startOfDay(for: start),
            yellowSeconds: yellow,
            redSeconds: red,
            maxPeakDBFS: maxPeak,
            maxRMSDBFS: maxRMS,
            fuseCount: fuseCount
        )
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            events = try decoder.decode([SafetyEvent].self, from: data)
        } catch {
            events = []
        }
    }

    private func persist() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try encoder.encode(events)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Keep logging best-effort for MVP.
        }
    }
}
