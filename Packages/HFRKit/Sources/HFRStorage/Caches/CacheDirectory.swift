import Foundation

/// The app's cache folder and its areas. Everything here can be deleted by the system or by the user at any time.
///
/// The default root is `Library/Caches/cache`, the same folder the legacy app used, so avatars cached by the old
/// version are simply pruned by age. The offline-reading feature is not part of it (LOT-068).
public struct CacheDirectory: Sendable {
    /// The folder holding all areas.
    public let root: URL

    /// Creates a cache over `root` (tests pass a temporary directory).
    public init(root: URL) {
        self.root = root
    }

    /// `Library/Caches/cache` of the app.
    public static var standard: CacheDirectory {
        // `URL.cachesDirectory` is Apple-only; the FileManager lookup also works on Linux.
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL.temporaryDirectory
        return CacheDirectory(root: caches.appending(path: "cache", directoryHint: .isDirectory))
    }

    /// The folder of an area, without creating it.
    public func url(for area: CacheArea) -> URL {
        root.appending(path: area.rawValue, directoryHint: .isDirectory)
    }

    /// The folder of an area, created when missing.
    public func prepare(_ area: CacheArea) throws -> URL {
        let url = url(for: area)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Applies each area's policy; run at launch. Returns one report per area.
    @discardableResult
    public func evictAll(now: Date = .now) -> [CacheArea: CacheEvictionReport] {
        var reports: [CacheArea: CacheEvictionReport] = [:]
        for area in CacheArea.allCases {
            reports[area] = CacheEvictor.evict(directory: url(for: area), policy: area.evictionPolicy, now: now)
        }
        return reports
    }

    /// Size in bytes of an area.
    public func size(of area: CacheArea) -> Int {
        CacheEvictor.totalBytes(in: url(for: area))
    }

    /// Empties an area (the "clear caches" action), keeping its folder and removing files whatever their date. Returns what was removed.
    @discardableResult
    public func clear(_ area: CacheArea) -> CacheEvictionReport {
        CacheEvictor.evict(directory: url(for: area), policy: .everything)
    }
}
