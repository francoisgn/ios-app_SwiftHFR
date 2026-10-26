import Foundation
import HFRModels

/// The stored accounts and the rules legacy `MultisManager.m:49-153` applied to them: identity by pseudo,
/// exactly one main account whenever there is any, promotion of the first remaining account when the main one
/// is deleted. Pure value; stores persist it as a `CredentialEnvelope`.
public struct AccountBook: Sendable, Hashable {
    /// Accounts in insertion order.
    public private(set) var accounts: [Account]

    /// The main account (whose cookies the shared jar carries); nil only when there is no account.
    public var main: Account? { accounts.first { $0.isMain } }

    /// Creates a book, repairing the main flag: the first account flagged main wins, else the first account.
    /// Two accounts with the same pseudo (ignoring case) keep the first one.
    public init(accounts: [Account] = []) {
        var unique: [Account] = []
        for account in accounts where !unique.contains(where: { Self.samePseudo($0.pseudo, account.pseudo) }) {
            unique.append(account)
        }
        self.accounts = unique
        normalizeMain(preferring: unique.firstIndex { $0.isMain })
    }

    /// The account whose pseudo matches, ignoring case and surrounding spaces; then by display name.
    public func account(matching pseudo: String) -> Account? {
        index(matching: pseudo).map { accounts[$0] }
    }

    /// Adds an account, or refreshes the stored one with the same pseudo (ignoring case; the stored spelling
    /// stays): new cookies replace
    /// the old ones, a nil `hashCheck` or `avatarData` keeps the stored value. With `makeMain` (legacy
    /// `AccountSessionService.swift:68-75`) it becomes the main account; the first account always does.
    /// Returns the stored account.
    @discardableResult
    public mutating func add(_ account: Account, makeMain: Bool = true) throws -> Account {
        let pseudo = account.pseudo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pseudo.isEmpty, pseudo.lowercased() != "deleted" else { throw CredentialStoreError.invalidPseudo }
        var incoming = account
        incoming.pseudo = pseudo
        let display = account.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        incoming.displayName = display.isEmpty ? pseudo : display

        let position: Int
        if let existing = accounts.firstIndex(where: { Self.samePseudo($0.pseudo, pseudo) }) {
            let stored = accounts[existing]
            incoming.pseudo = stored.pseudo
            incoming.hashCheck = incoming.hashCheck ?? stored.hashCheck
            incoming.avatarData = incoming.avatarData ?? stored.avatarData
            incoming.isMain = stored.isMain
            accounts[existing] = incoming
            position = existing
        } else {
            incoming.isMain = false
            accounts.append(incoming)
            position = accounts.count - 1
        }
        normalizeMain(preferring: makeMain ? position : accounts.firstIndex { $0.isMain })
        return accounts[position]
    }

    /// Makes the matching account the main one; false when no account matches.
    @discardableResult
    public mutating func setMain(pseudo: String) -> Bool {
        guard let position = index(matching: pseudo) else { return false }
        normalizeMain(preferring: position)
        return true
    }

    /// Deletes the matching account and returns it; when it was the main one, the first remaining account
    /// becomes main (legacy `MultisManager.m:125-153`). Nil when no account matches.
    @discardableResult
    public mutating func remove(pseudo: String) -> Account? {
        guard let position = index(matching: pseudo) else { return nil }
        let removed = accounts.remove(at: position)
        normalizeMain(preferring: accounts.firstIndex { $0.isMain })
        return removed
    }

    /// Replaces the stored account that has the same pseudo, keeping the main flag; false when absent.
    @discardableResult
    public mutating func replace(_ account: Account) -> Bool {
        guard let position = accounts.firstIndex(where: { Self.samePseudo($0.pseudo, account.pseudo) }) else { return false }
        var updated = account
        updated.pseudo = accounts[position].pseudo
        updated.isMain = accounts[position].isMain
        accounts[position] = updated
        return true
    }

    /// Exactly one main account when there is any: `preferred`, else the first one.
    private mutating func normalizeMain(preferring preferred: Int?) {
        guard !accounts.isEmpty else { return }
        let mainIndex = preferred ?? 0
        for position in accounts.indices {
            accounts[position].isMain = position == mainIndex
        }
    }

    private func index(matching identifier: String) -> Int? {
        let wanted = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return nil }
        return accounts.firstIndex { $0.pseudo == wanted }
            ?? accounts.firstIndex { Self.samePseudo($0.pseudo, wanted) }
            ?? accounts.firstIndex { Self.samePseudo($0.displayName, wanted) }
    }

    /// Case-insensitive comparison. Diacritics are significant: `Élodie` and `Elodie` can be two accounts.
    private static func samePseudo(_ lhs: String, _ rhs: String) -> Bool {
        lhs.lowercased() == rhs.lowercased()
    }
}
