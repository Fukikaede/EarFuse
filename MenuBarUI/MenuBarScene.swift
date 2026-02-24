import Audio
import Core
import SwiftUI

public struct MenuBarScene: Scene {
    @StateObject private var monitor = AudioMonitorService()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(monitor: monitor)
                .onAppear {
                    monitor.start()
                }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Label("EarFuse", systemImage: iconName)
                .foregroundStyle(iconColor)
        }
        .menuBarExtraStyle(.window)
    }

    private var iconName: String {
        switch monitor.status.level {
        case .safe: return "waveform"
        case .yellow: return "exclamationmark.triangle"
        case .red: return "exclamationmark.octagon"
        }
    }

    private var iconColor: Color {
        switch monitor.status.level {
        case .safe: return .green
        case .yellow: return .orange
        case .red: return .red
        }
    }
}
