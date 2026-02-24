import Foundation

public enum CaptureBackendFactory {
    public static func make(for source: CaptureSource) -> AudioCaptureBackend {
        switch source {
        case .systemOutput:
            return CoreAudioOutputCaptureBackendA()
        case .inputDevice:
            return AVInputCaptureBackend()
        case .mock:
            return MockCaptureBackend()
        }
    }
}
