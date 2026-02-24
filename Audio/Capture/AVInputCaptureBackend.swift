import AVFoundation
import Foundation

public final class AVInputCaptureBackend: AudioCaptureBackend, @unchecked Sendable {
    public var onFrame: (([Float], Date) -> Void)?

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "earfuse.avinput.capture")
    private var isRunning = false

    public init() {}

    public func start() -> Bool {
        guard !isRunning else { return true }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self, granted else { return }
            self.queue.async {
                self.installTapAndStartEngine()
            }
        }
        return true
    }

    public func stop() {
        queue.async {
            guard self.isRunning else { return }
            self.engine.inputNode.removeTap(onBus: 0)
            self.engine.stop()
            self.isRunning = false
        }
    }

    private func installTapAndStartEngine() {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 1024

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            guard let data = Self.extractSamples(from: buffer) else { return }
            self.onFrame?(data, Date())
        }

        do {
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            inputNode.removeTap(onBus: 0)
            isRunning = false
        }
    }

    private static func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }

        if let channels = buffer.floatChannelData {
            let channelCount = Int(buffer.format.channelCount)
            guard channelCount > 0 else { return nil }

            if channelCount == 1 {
                let channel = channels[0]
                return Array(UnsafeBufferPointer(start: channel, count: frameLength))
            }

            var mixed = [Float](repeating: 0, count: frameLength)
            for ch in 0..<channelCount {
                let channel = channels[ch]
                for i in 0..<frameLength {
                    mixed[i] += channel[i]
                }
            }

            let norm = 1.0 / Float(channelCount)
            for i in 0..<frameLength {
                mixed[i] *= norm
            }
            return mixed
        }

        if let channels = buffer.int16ChannelData {
            let channelCount = Int(buffer.format.channelCount)
            guard channelCount > 0 else { return nil }

            var mixed = [Float](repeating: 0, count: frameLength)
            for ch in 0..<channelCount {
                let channel = channels[ch]
                for i in 0..<frameLength {
                    mixed[i] += Float(channel[i]) / Float(Int16.max)
                }
            }

            let norm = 1.0 / Float(channelCount)
            for i in 0..<frameLength {
                mixed[i] *= norm
            }
            return mixed
        }

        return nil
    }
}
