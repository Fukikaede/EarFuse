import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

public final class CoreAudioOutputCaptureBackendA: NSObject, AudioCaptureBackend, @unchecked Sendable {
    public var onFrame: (([Float], Date) -> Void)?

    private let sampleQueue = DispatchQueue(label: "earfuse.screencapture.audio")
    private var stream: SCStream?
    private var isRunning = false

    public override init() {
        super.init()
    }

    deinit {
        stop()
    }

    public func start() -> Bool {
        guard !isRunning else { return true }

        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            return false
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let shareableContent = try await SCShareableContent.current
                guard let display = shareableContent.displays.first else {
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 2
                config.height = 2
                config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                config.capturesAudio = true
                config.sampleRate = 48_000
                config.channelCount = 2
                config.excludesCurrentProcessAudio = false
                config.showsCursor = false

                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                self.stream = stream

                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.sampleQueue)
                try await stream.startCapture()
                self.isRunning = true
            } catch {
                self.stream = nil
            }
        }
        return true
    }

    public func stop() {
        guard let stream else { return }
        self.stream = nil
        isRunning = false
        Task {
            try? await stream.stopCapture()
        }
    }

    private func consumeAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else { return }

        var requiredSize: Int = 0
        let sizeStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: nil
        )
        guard sizeStatus == noErr, requiredSize > 0 else { return }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: requiredSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        let audioBufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        var retainedBlockBuffer: CMBlockBuffer?
        let flags = UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment)

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: requiredSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: flags,
            blockBufferOut: &retainedBlockBuffer
        )
        guard status == noErr else { return }

        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let isFloat = (asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat) != 0 && asbd.pointee.mBitsPerChannel == 32
        let isSignedInt16 = asbd.pointee.mBitsPerChannel == 16

        var samples: [Float] = []
        for buffer in bufferList {
            guard let mData = buffer.mData, buffer.mDataByteSize > 0 else { continue }

            if isFloat {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                let ptr = mData.assumingMemoryBound(to: Float.self)
                samples.append(contentsOf: UnsafeBufferPointer(start: ptr, count: count))
            } else if isSignedInt16 {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size
                let ptr = mData.assumingMemoryBound(to: Int16.self)
                for i in 0..<count {
                    samples.append(Float(ptr[i]) / Float(Int16.max))
                }
            }
        }

        guard !samples.isEmpty else { return }
        onFrame?(samples, Date())
    }
}

extension CoreAudioOutputCaptureBackendA: SCStreamOutput, SCStreamDelegate {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        consumeAudioSampleBuffer(sampleBuffer)
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        isRunning = false
    }
}
