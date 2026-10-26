import Foundation

/// Applies a `CacheEvictionPolicy` to a folder, recursively. It only removes regular files, never folders or symbolic links.
public enum CacheEvictor {
    private struct Item {
        let url: URL
        let modified: Date
        let size: Int
    }

    /// Evicts files of `directory` according to `policy`; `now` is injectable for tests.
    /// A missing directory is an empty cache. Files that cannot be removed are reported, not retried.
    @discardableResult
    public static func evict(directory: URL, policy: CacheEvictionPolicy, now: Date = .now) -> CacheEvictionReport {
        var report = CacheEvictionReport()
        var items = list(directory, report: &report)

        if let maximumAge = policy.maximumAge {
            let expired = items.filter { now.timeIntervalSince($0.modified) > maximumAge }
            items.removeAll { item in expired.contains { $0.url == item.url } }
            for item in expired { remove(item, report: &report) }
        }

        if let maximumBytes = policy.maximumTotalBytes {
            var total = items.reduce(0) { $0 + $1.size }
            // Oldest first; the path breaks ties so the outcome is deterministic.
            let oldestFirst = items.sorted { ($0.modified, $0.url.path()) < ($1.modified, $1.url.path()) }
            for item in oldestFirst where total > maximumBytes {
                if remove(item, report: &report) { total -= item.size }
            }
        }

        report.remainingBytes = list(directory, report: &report).reduce(0) { $0 + $1.size }
        return report
    }

    /// Total size in bytes of the regular files under `directory`.
    public static func totalBytes(in directory: URL) -> Int {
        var ignored = CacheEvictionReport()
        return list(directory, report: &ignored).reduce(0) { $0 + $1.size }
    }

    @discardableResult
    private static func remove(_ item: Item, report: inout CacheEvictionReport) -> Bool {
        do {
            try FileManager.default.removeItem(at: item.url)
            report.removedFileCount += 1
            report.removedBytes += item.size
            return true
        } catch {
            report.failures.append("\(item.url.lastPathComponent): \(error)")
            return false
        }
    }

    private static func list(_ directory: URL, report: inout CacheEvictionReport) -> [Item] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey]
        var pending = [directory]
        var items: [Item] = []
        while let current = pending.popLast() {
            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(at: current, includingPropertiesForKeys: keys)
            } catch {
                if FileManager.default.fileExists(atPath: current.path(percentEncoded: false)) {
                    report.failures.append("\(current.lastPathComponent): \(error)")
                }
                continue
            }
            for child in children {
                guard let values = try? child.resourceValues(forKeys: Set(keys)) else {
                    report.failures.append("\(child.lastPathComponent): attributes unreadable")
                    continue
                }
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true {
                    pending.append(child)
                } else if values.isRegularFile == true {
                    items.append(Item(url: child, modified: values.contentModificationDate ?? .distantPast, size: values.fileSize ?? 0))
                }
            }
        }
        return items
    }
}
