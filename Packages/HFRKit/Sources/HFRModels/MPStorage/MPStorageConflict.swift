/// A point where the two copies of the document disagreed in a way the merge had to decide. Reported so the
/// app can tell the user (or log it); the merge result is already consistent.
public struct MPStorageConflict: Sendable, Hashable {
    /// What happened.
    public enum Kind: Sendable, Hashable {
        /// Both copies changed the same item or value differently.
        case bothChanged
        /// Both copies added the same item with different content.
        case bothAdded
        /// One copy changed an item the other deleted; the change is kept.
        case changedAndDeleted
        /// No base was given and the copies differ.
        case divergentWithoutBase
    }

    /// Which copy the merge kept.
    public enum Resolution: Sendable, Hashable {
        /// This app's copy.
        case keptOurs
        /// The copy just read from the forum.
        case keptTheirs
    }

    /// Where: `blacklist`, `mpFlags`, `bookmarks` for items, `entry` or `root` for other values.
    public var location: String
    /// Item key or value key.
    public var key: String
    /// What happened.
    public var kind: Kind
    /// How it was resolved.
    public var resolution: Resolution

    /// Creates a conflict record.
    public init(location: String, key: String, kind: Kind, resolution: Resolution) {
        self.location = location
        self.key = key
        self.kind = kind
        self.resolution = resolution
    }
}
