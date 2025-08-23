//
//  Mapping+Arrival.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/9/25.
//

import Foundation

extension Arrival {
    /// Map backend `SimpleTimeDTO` to a domain `Arrival`.
    /// - `times`: numeric minutes as a string, or "DUE" (arriving now) or "DLY" (delayed/unknown).
    /// - We store the raw string directly.
    init?(dto: SimpleTimeDTO, stopId: String, routeId: String) {
        // Normalize
        let t = dto.times.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !t.isEmpty else { return nil }
        self = Arrival(
            stopId: stopId,
            routeId: routeId,
            destination: dto.dest,
            time: t
        )
    }
}

extension SimpleTimeDTO {
    /// Convenience mapper to domain `Arrival`.
    /// - Returns: `Arrival` or `nil` if the DTO is not valid.
    func toArrival(stopId: String, routeId: String) -> Arrival? {
        Arrival(dto: self, stopId: stopId, routeId: routeId)
    }
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

public extension Array where Element == Arrival {
    /// Suggested next widget reload:
    /// Always refresh 5 minutes from now.
    func suggestedRefresh(from now: Date) -> Date {
        return now.addingTimeInterval(5 * 60)
    }
}
