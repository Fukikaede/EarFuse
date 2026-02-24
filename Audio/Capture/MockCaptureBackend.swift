import Foundation

public final class MockCaptureBackend: AudioCaptureBackend, @unchecked Sendable {
    public var onFrame: (([Float], Date) -> Void)?

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "earfuse.mock.capture")
    private var phase: Float = 0
    private let sampleRate: Float = 48_000
    private let frameSize = 1024

    public init() {}

    public func start() -> Bool {
        guard timer == nil else { return true }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(30))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            var frame = [Float](repeating: 0, count: self.frameSize)
            let frequency: Float = 440
            let amplitude: Float = 0.15

            for index in 0..<self.frameSize {
                frame[index] = sinf(2 * .pi * self.phase) * amplitude
                self.phase += frequency / self.sampleRate
                if self.phase >= 1 { self.phase -= 1 }
            }

            if Int(Date().timeIntervalSince1970) % 9 == 0 {
                frame[0] = 0.95
            }

            self.onFrame?(frame, Date())
        }
        self.timer = timer
        timer.resume()
        return true
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }
}
