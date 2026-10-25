/// The `embedded_videos` setting: how video links are shown.
public enum EmbeddedVideosMode: String, Sendable, Codable, CaseIterable {
    /// Links only.
    case no
    /// Inline player only.
    case yes
    /// Inline player and the link.
    case both
}
