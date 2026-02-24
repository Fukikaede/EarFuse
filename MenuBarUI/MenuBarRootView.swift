import Audio
import Core
import Logging
import Profiles
import SettingsUI
import SwiftUI

public struct MenuBarRootView: View {
    @ObservedObject private var monitor: AudioMonitorService

    public init(monitor: AudioMonitorService) {
        self.monitor = monitor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EarFuse")
                    .font(.headline)
                Spacer()
                Text(levelText)
                    .font(.subheadline)
                    .foregroundStyle(levelColor)
            }

            HStack(spacing: 16) {
                metric(label: "Peak", value: monitor.status.snapshot.peakDBFS)
                metric(label: "RMS", value: monitor.status.snapshot.rmsDBFS)
            }

            MeterHistoryChart(points: monitor.history)

            HStack {
                Text("Threshold")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Y: -20 dBFS  R: -14 dBFS")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            ProfilePickerView(
                selectedProfile: Binding(
                    get: { monitor.activeProfileKind },
                    set: { monitor.switchProfile($0) }
                )
            )

            CaptureSourcePickerView(
                source: Binding(
                    get: { monitor.activeCaptureSource },
                    set: { monitor.switchCaptureSource($0) }
                )
            )

            if let message = monitor.captureStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            summaryBlock

            if let message = monitor.lastFuseMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !monitor.recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(monitor.recentEvents.prefix(3).enumerated()), id: \.offset) { _, event in
                        Text(eventLine(event))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Today  Yellow: \(secondsLabel(monitor.todaySummary.yellowSeconds))  Red: \(secondsLabel(monitor.todaySummary.redSeconds))")
                .font(.caption.monospaced())
            Text("Week   Yellow: \(secondsLabel(monitor.weekYellowSeconds))  Red: \(secondsLabel(monitor.weekRedSeconds))")
                .font(.caption.monospaced())
        }
        .foregroundStyle(.secondary)
    }

    private func metric(label: String, value: Float) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f dBFS", value))
                .font(.title3.monospacedDigit())
                .foregroundStyle(levelColor)
        }
    }

    private func secondsLabel(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func eventLine(_ event: SafetyEvent) -> String {
        let peak = String(format: "%.1f", event.maxPeakDBFS)
        let rms = String(format: "%.1f", event.maxRMSDBFS)
        return "\(event.classification.rawValue.uppercased())  P:\(peak)  R:\(rms)  \(secondsLabel(event.duration))"
    }

    private var levelText: String {
        switch monitor.status.level {
        case .safe: return "SAFE"
        case .yellow: return "YELLOW"
        case .red: return "RED"
        }
    }

    private var levelColor: Color {
        switch monitor.status.level {
        case .safe: return .green
        case .yellow: return .orange
        case .red: return .red
        }
    }
}
