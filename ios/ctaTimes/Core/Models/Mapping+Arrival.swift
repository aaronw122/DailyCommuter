//
//  Mapping+Arrival.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/9/25.
//

import Foundation

// MARK: - DTO → Domain (nested Arrival)

extension TimeInfo {
    /// Map backend `SimpleTimeDTO` to domain `Times`.
    /// - `time`: numeric minutes as a string, or "DUE" / "DLY". Stored verbatim.
    init?(dto: SimpleTimeDTO) {
        let normalized = dto.times.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return nil }
        self = TimeInfo(time: normalized, destination: dto.dest)
    }
}

extension Array where Element == TimeInfo {
    /// Map an array of DTOs to domain `Times[]`, dropping invalid rows.
    static func fromDTOs(_ list: [SimpleTimeDTO]) -> [TimeInfo] {
        list.compactMap(TimeInfo.init(dto:))
    }
}

extension StopArrival {
    /// Convenience initializer to build a `stopArrival` from DTOs for a given stop/route/direction.
    init(stopId: String, routeId: String, direction: String, timeDTOs: [SimpleTimeDTO]) {
        self.stopId = stopId
        self.routeId = routeId
        self.direction = direction
        self.time = [TimeInfo].fromDTOs(timeDTOs)
    }
}

extension SimpleTimeDTO {
    /// Convenience mapper to domain `Times` (leaf nodes in the nested model).
    /// - Returns: `Times` or `nil` if the DTO is not valid.
    func toTimeInfo() -> TimeInfo? { TimeInfo(dto: self) }
}

/// Cache payload format for arrivals shared between app and widget.
private struct CachedArrivals: Codable {
    let fetchedAt: Date
    let arrivals: [Arrival]
}

/// Time-to-live for cached arrivals (30 minutes).
public enum ArrivalCacheTTL {
    public static let maxAge: TimeInterval = 30 * 60
}

public extension Array where Element == Arrival {
    /// Serialize arrivals with a `fetchedAt` timestamp for disk caching.
    func toCachedPayload(now: Date = .now) -> Data? {
        let payload = CachedArrivals(fetchedAt: now, arrivals: self)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return try? enc.encode(payload)
    }

    /// Deserialize arrivals only if fresh (<= maxAge). Returns nil if stale or unreadable.
    static func fromCachedPayload(_ data: Data,
                                  maxAge: TimeInterval = ArrivalCacheTTL.maxAge,
                                  now: Date = .now) -> [Arrival]? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let payload = try? dec.decode(CachedArrivals.self, from: data) else { return nil }
        guard now.timeIntervalSince(payload.fetchedAt) <= maxAge else { return nil }
        return payload.arrivals
    }

    /// Convenience: Load cached arrivals from a file URL, returning only if fresh.
    static func loadFrom(url: URL,
                         maxAge: TimeInterval = ArrivalCacheTTL.maxAge,
                         now: Date = .now) -> [Arrival]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return fromCachedPayload(data, maxAge: maxAge, now: now)
    }

    /// Load cached arrivals and include the embedded fetchedAt timestamp.
    /// Returns nil if missing or stale.
    static func loadFromWithTimestamp(url: URL,
                                      maxAge: TimeInterval = ArrivalCacheTTL.maxAge,
                                      now: Date = .now) -> (arrivals: [Arrival], fetchedAt: Date)? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let payload = try? dec.decode(CachedArrivals.self, from: data) else { return nil }
        guard now.timeIntervalSince(payload.fetchedAt) <= maxAge else { return nil }
        return (payload.arrivals, payload.fetchedAt)
    }

    /// Convenience: Save arrivals atomically to a file URL with timestamp.
    func save(to url: URL, now: Date = .now) {
        guard let data = toCachedPayload(now: now) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Optional: Remove the cache file if it exists and is stale.
    static func purgeIfStale(at url: URL,
                             maxAge: TimeInterval = ArrivalCacheTTL.maxAge,
                             now: Date = .now) {
        guard let data = try? Data(contentsOf: url) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let payload = try? dec.decode(CachedArrivals.self, from: data),
           now.timeIntervalSince(payload.fetchedAt) > maxAge {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// Refresh policy moved to Core/Utilities/Arrivals+Refresh.swift
