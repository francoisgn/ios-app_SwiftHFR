/// Failures of the cache helpers.
public enum CacheError: Error, Sendable, Equatable {
    /// The key is empty once normalised.
    case emptyKey
    /// The key is longer than `AvatarCache.maximumKeyBytes`.
    case keyTooLong
    /// Empty data is never cached (it would replace a valid file with nothing).
    case emptyData
}
