import Foundation

public enum CaptureSource: String, CaseIterable, Codable, Sendable {
    case systemOutput
    case inputDevice
    case mock

    public var displayName: String {
        switch self {
        case .systemOutput: return "System Output"
        case .inputDevice: return "Input Device"
        case .mock: return "Mock"
        }
    }
}
