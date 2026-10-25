/// The `display_images` setting: when images of messages are loaded.
public enum ImageDisplayMode: String, Sendable, Codable, CaseIterable {
    /// Always.
    case yes
    /// Never.
    case no
    /// Only on Wi-Fi.
    case wifi
}
