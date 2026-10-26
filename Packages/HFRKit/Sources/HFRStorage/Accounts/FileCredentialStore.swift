import Foundation
import HFRModels
import Synchronization
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// A store that keeps the envelope in one file, for Linux and tests. On a device use `KeychainCredentialStore`:
/// a file is only as private as its directory and its backups. The file is written atomically with owner-only
/// permissions (and, on Apple platforms, complete-until-first-authentication protection).
public final class FileCredentialStore: CredentialStore {
    /// The envelope file.
    public let fileURL: URL
    private let lock = Mutex(())

    /// Creates a store for `fileURL`; the directory is created on first write.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The stored accounts; empty when the file does not exist.
    public func load() throws -> AccountBook {
        try lock.withLock { _ in try read() }
    }

    /// Read-modify-write under this instance's lock; two instances on the same file are not serialized.
    public func update<Value>(_ body: (inout AccountBook) throws -> Value) throws -> Value {
        try lock.withLock { _ in
            var book = try read()
            let original = book
            let value = try body(&book)
            if book != original { try write(CredentialEnvelope.encode(book)) }
            return value
        }
    }

    /// Deletes the file; no error when it does not exist.
    public func removeAll() throws {
        try lock.withLock { _ in
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
                return
            }
        }
    }

    private func read() throws -> AccountBook {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            // Apple platforms report the first code, swift-corelibs-foundation the second.
            return AccountBook()
        }
        return try CredentialEnvelope.decode(data)
    }

    /// Writes a sibling temporary file created owner-only, then renames it over the envelope.
    private func write(_ data: Data) throws {
        let manager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appending(path: ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp")
        var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        attributes[.protectionKey] = FileProtectionType.completeUntilFirstUserAuthentication
        #endif
        guard manager.createFile(atPath: temporary.path(percentEncoded: false), contents: data, attributes: attributes) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: temporary.path(percentEncoded: false)])
        }
        // rename(2) replaces atomically; swift-corelibs-foundation's replaceItemAt fails with ENOENT on Linux.
        guard rename(temporary.path(percentEncoded: false), fileURL.path(percentEncoded: false)) == 0 else {
            let code = POSIXErrorCode(rawValue: errno) ?? .EIO
            // Best-effort cleanup of the temporary copy: the rename failure is the error to report.
            try? manager.removeItem(at: temporary)
            throw POSIXError(code)
        }
    }
}
