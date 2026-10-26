import Foundation

/// Who writes and when: stamped into `sourceName` / `lastUpdate` at every level a change touches,
/// and used as the date of tombstones and new items.
public struct MPStorageStamp: Sendable, Hashable {
    /// The `sourceName` the legacy iOS app writes (`MPStorage.m:26`).
    public static let legacySourceName = "iOS"

    /// Writer name, e.g. `iOS`.
    public var sourceName: String
    /// Instant of the change.
    public var date: Date

    /// Creates a stamp.
    public init(sourceName: String = MPStorageStamp.legacySourceName, date: Date) {
        self.sourceName = sourceName
        self.date = date
    }
}
