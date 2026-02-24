import Foundation

public protocol AudioCaptureBackend: AnyObject {
    var onFrame: (([Float], Date) -> Void)? { get set }
    func start() -> Bool
    func stop()
}
