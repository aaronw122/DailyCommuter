// Core/Persistence/SharedStore.swift
// DailyCommuter
// Shared App Group JSON cache for favorites + arrivals
// Atomic writes; safe, fast reads; no file protection so widgets can read while locked.

import Foundation

public struct SharedStore {
    // Filenames inside the App Group container
    public enum File: String, CaseIterable {
        case favorites = "favorites.json"
        case arrivals = "arrivals.json"
    }

    public enum SharedStoreError: Error, LocalizedError {
        case containerUnavailable(String)
        case urlCreationFailed

        public var errorDescription: String? {
            switch self {
            case .containerUnavailable(let group):
                return "App Group container not found for \(group). Make sure the capability is enabled on both targets."
            case .urlCreationFailed:
                return "Could not build file URL in App Group container."
            }
        }
    }

    // MARK: - Properties

    public let groupID: String
    private let fileManager: FileManager
    private let containerOverride: URL? // used by tests

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(
        groupID: String,
        fileManager: FileManager = .default,
        containerOverride: URL? = nil
    ) {
        self.groupID = groupID
        self.fileManager = fileManager
        self.containerOverride = containerOverride

        let enc = JSONEncoder()
        // Stable output, but keep it compact for widget budget
        enc.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = enc

        let dec = JSONDecoder()
        self.decoder = dec
    }

    // MARK: - Public API (Favorites)

    /// Loads favorites as DTOs (what RN writes). Returns empty array if file is missing or invalid.
    public func loadFavoritesDTO() -> [FavoriteDTO] {
        (try? read([FavoriteDTO].self, from: .favorites)) ?? []
    }

    /// Atomically saves favorites DTOs.
    public func saveFavoritesDTO(_ list: [FavoriteDTO]) throws {
        try write(list, to: .favorites)
    }

    // MARK: - Public API (Arrivals)

    /// Loads last known arrivals (domain model). Returns empty array if missing/invalid.
    public func loadArrivals() -> [Arrival] {
        (try? read([Arrival].self, from: .arrivals)) ?? []
    }

    /// Atomically saves arrivals (domain model).
    public func saveArrivals(_ list: [Arrival]) throws {
        try write(list, to: .arrivals)
    }

    /// Last modification date for a cached file (helps show "Updated X min ago").
    public func lastModifiedDate(for file: File) -> Date? {
        guard let url = try? url(for: file),
              let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return nil }
        return date
    }

    /// Removes a specific cached file. Returns whether it succeeded.
    @discardableResult
    public func clear(_ file: File) -> Bool {
        guard let url = try? url(for: file) else { return false }
        return (try? fileManager.removeItem(at: url)) != nil
    }

    // MARK: - Private helpers

    private func containerURL() throws -> URL {
        if let override = containerOverride { return override }
        guard let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw SharedStoreError.containerUnavailable(groupID)
        }
        return url
    }

    private func url(for file: File) throws -> URL {
        let base = try containerURL()
        return base.appendingPathComponent(file.rawValue, isDirectory: false)
    }

    private func read<T: Decodable>(_ type: T.Type, from file: File) throws -> T {
        let url = try url(for: file)
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to file: File) throws {
        var url = try url(for: file)
        let data = try encoder.encode(value)

        // Atomic write ensures readers either see the old or the new file, never a partial.
        try data.write(to: url, options: .atomic)

        // Widgets may need to read while device is locked (Lock Screen/Home Screen). Avoid file protection.
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: url.path)

        // Do not back up cached network data to iCloud.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
