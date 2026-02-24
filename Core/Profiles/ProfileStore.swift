import Foundation

public final class ProfileStore: @unchecked Sendable {
    public private(set) var current: AppProfile

    public init(initial: AppProfile = DefaultProfiles.listening) {
        current = initial
    }

    public func switchTo(_ kind: AppProfileKind) {
        current = kind == .production ? DefaultProfiles.production : DefaultProfiles.listening
    }
}
