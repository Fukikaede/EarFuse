import Alerts
import Capture
import Combine
import Core
import Foundation
import Fuse
import Logging
import Meter
import Policy
import Profiles

public struct MeterHistoryPoint: Sendable, Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let peakDBFS: Float
    public let rmsDBFS: Float
    public let displayRMSDBFS: Float
}

public final class AudioMonitorService: ObservableObject, @unchecked Sendable {
    @Published public private(set) var status = MeterStatus(
        snapshot: .init(peakDBFS: -120, rmsDBFS: -120),
        level: .safe
    )
    @Published public private(set) var activeProfileKind: AppProfileKind
    @Published public private(set) var activeCaptureSource: CaptureSource
    @Published public private(set) var lastFuseMessage: String?
    @Published public private(set) var captureStatusMessage: String?
    @Published public private(set) var history: [MeterHistoryPoint] = []
    @Published public private(set) var todaySummary: DailySummary
    @Published public private(set) var weekYellowSeconds: TimeInterval = 0
    @Published public private(set) var weekRedSeconds: TimeInterval = 0
    @Published public private(set) var recentEvents: [SafetyEvent] = []

    private var backend: AudioCaptureBackend
    private let meterCalculator: MeterCalculator
    private let policyEngine: PolicyEngine
    private let profileStore: ProfileStore
    private let alertService: Alerting
    private let fuseController: FuseController
    private let logStore: LogStore

    private var eventStart: Date?
    private var eventMaxPeak: Float = -120
    private var eventMaxRMS: Float = -120
    private var eventLevel: SafetyLevel = .safe
    private var smoothedRMSDBFS: Float?
    private var lastHistoryAppendAt: Date?
    private let historyUpdateInterval: TimeInterval = 0.20
    private var lastDisplayStatusAt: Date?
    private let displayStatusUpdateInterval: TimeInterval = 0.20
    private var lastAlertLevel: SafetyLevel = .safe

    public init(
        captureSource: CaptureSource = .systemOutput,
        meterCalculator: MeterCalculator = .init(),
        policyEngine: PolicyEngine = .init(),
        profileStore: ProfileStore = .init(),
        alertService: Alerting = NoopAlertService(),
        fuseController: FuseController = .init(volumeController: StubVolumeController()),
        logStore: LogStore = .init()
    ) {
        self.meterCalculator = meterCalculator
        self.policyEngine = policyEngine
        self.profileStore = profileStore
        self.alertService = alertService
        self.fuseController = fuseController
        self.logStore = logStore
        self.activeProfileKind = profileStore.current.kind
        self.activeCaptureSource = captureSource
        self.backend = CaptureBackendFactory.make(for: captureSource)
        self.todaySummary = logStore.todaySummary()

        bindBackend()
        refreshSummaries()
    }

    public func start() {
        let started = backend.start()
        if started {
            captureStatusMessage = "Capture: \(activeCaptureSource.displayName)"
            return
        }

        if activeCaptureSource == .systemOutput {
            switchCaptureSource(.inputDevice)
            captureStatusMessage = "System Output unavailable, fallback to Input Device"
        } else {
            captureStatusMessage = "Capture unavailable: \(activeCaptureSource.displayName)"
        }
    }

    public func stop() {
        backend.stop()
    }

    public func switchProfile(_ kind: AppProfileKind) {
        profileStore.switchTo(kind)
        DispatchQueue.main.async {
            self.activeProfileKind = kind
        }
    }

    public func switchCaptureSource(_ source: CaptureSource) {
        backend.stop()
        activeCaptureSource = source
        backend = CaptureBackendFactory.make(for: source)
        bindBackend()
        _ = backend.start()
        captureStatusMessage = "Capture: \(source.displayName)"
    }

    private func bindBackend() {
        backend.onFrame = { [weak self] samples, timestamp in
            self?.handle(samples: samples, timestamp: timestamp)
        }
    }

    private func handle(samples: [Float], timestamp: Date) {
        let profile = profileStore.current
        let snapshot = meterCalculator.calculate(samples: samples, timestamp: timestamp)
        let decision = policyEngine.evaluate(snapshot: snapshot, profile: profile)
        let fuseAction = fuseController.evaluate(snapshot: snapshot, profile: profile)

        let finalizedEvent = updateEventTracking(snapshot: snapshot, level: decision.level, fuseTriggered: fuseAction.triggered)

        DispatchQueue.main.async {
            let levelChanged = (self.lastAlertLevel != decision.level)

            if levelChanged {
                self.alertService.onSafetyLevelChanged(decision.level)
                self.lastAlertLevel = decision.level
            }

            if fuseAction.triggered {
                let oldValue = Int((fuseAction.previousVolume ?? 0) * 100)
                let newValue = Int((fuseAction.newVolume ?? 0) * 100)
                self.lastFuseMessage = "Fuse triggered: volume \(oldValue)% -> \(newValue)%"
            }

            self.updateDisplayStatusIfNeeded(
                snapshot: snapshot,
                level: decision.level,
                force: levelChanged || fuseAction.triggered
            )
            self.appendHistoryIfNeeded(snapshot: snapshot)

            if finalizedEvent != nil {
                self.refreshSummaries()
            }
        }
    }

    @discardableResult
    private func updateEventTracking(snapshot: MeterSnapshot, level: SafetyLevel, fuseTriggered: Bool) -> SafetyEvent? {
        if level == .safe {
            guard let eventStart else { return nil }
            let event = SafetyEvent(
                startTime: eventStart,
                endTime: snapshot.timestamp,
                maxPeakDBFS: eventMaxPeak,
                maxRMSDBFS: eventMaxRMS,
                classification: eventLevel,
                triggeredFuse: fuseTriggered
            )
            logStore.append(event)
            self.eventStart = nil
            self.eventMaxPeak = -120
            self.eventMaxRMS = -120
            self.eventLevel = .safe
            return event
        }

        if eventStart == nil {
            eventStart = snapshot.timestamp
            eventLevel = level
        } else if level == .red {
            eventLevel = .red
        }

        eventMaxPeak = max(eventMaxPeak, snapshot.peakDBFS)
        eventMaxRMS = max(eventMaxRMS, snapshot.rmsDBFS)
        return nil
    }

    private func trimHistory(windowSeconds: TimeInterval) {
        guard let latest = history.last?.timestamp else { return }
        let cutoff = latest.addingTimeInterval(-windowSeconds)
        history.removeAll { $0.timestamp < cutoff }
    }

    private func appendHistoryIfNeeded(snapshot: MeterSnapshot) {
        if let last = lastHistoryAppendAt,
           snapshot.timestamp.timeIntervalSince(last) < historyUpdateInterval {
            return
        }

        history.append(
            MeterHistoryPoint(
                timestamp: snapshot.timestamp,
                peakDBFS: snapshot.peakDBFS,
                rmsDBFS: snapshot.rmsDBFS,
                displayRMSDBFS: nextSmoothedRMS(snapshot.rmsDBFS)
            )
        )
        lastHistoryAppendAt = snapshot.timestamp
        trimHistory(windowSeconds: 60)
    }

    private func updateDisplayStatusIfNeeded(snapshot: MeterSnapshot, level: SafetyLevel, force: Bool) {
        if !force,
           let last = lastDisplayStatusAt,
           snapshot.timestamp.timeIntervalSince(last) < displayStatusUpdateInterval {
            return
        }

        status = MeterStatus(snapshot: snapshot, level: level)
        lastDisplayStatusAt = snapshot.timestamp
    }

    private func nextSmoothedRMS(_ rawRMS: Float) -> Float {
        let alpha: Float = 0.10
        guard let previous = smoothedRMSDBFS else {
            smoothedRMSDBFS = rawRMS
            return rawRMS
        }

        let next = (alpha * rawRMS) + ((1 - alpha) * previous)
        smoothedRMSDBFS = next
        return next
    }

    private func refreshSummaries() {
        todaySummary = logStore.todaySummary()
        let week = logStore.weekTotals()
        weekYellowSeconds = week.yellow
        weekRedSeconds = week.red
        recentEvents = logStore.recentEvents(limit: 10)
    }
}
