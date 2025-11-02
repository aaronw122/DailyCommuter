//
//  Arrivals+Refresh.swift
//  DailyCommuter
//
//  Helpers to compute widget refresh policy from arrivals.
//  iOS 17+: used by Provider.timeline(for:in:).
//

import Foundation

private enum RefreshPolicy {
    static let minInterval: TimeInterval = 60          // 1 minute
    static let maxInterval: TimeInterval = 15 * 60     // 15 minutes
    static let earlySkew: TimeInterval = 45            // refresh a bit before the soonest arrival
}

private extension String {
    /// Convert CTA time strings to minutes-from-now where possible.
    /// Accepts numeric minutes and special keywords like "DUE".
    func ctaMinutes() -> Int? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed == "DUE" { return 0 }
        // Ignore non-numeric labels like "DLY" or textual messages.
        if let m = Int(trimmed) {   return m }
        return nil
    }
}

public extension Array where Element == Arrival {
    /// Returns the earliest minutes offset among all arrivals, if any.
    func earliestMinutes() -> Int? {
        var best: Int?
        for arrival in self {
            for stop in arrival.stops {
                for t in stop.time {
                    if let m = t.time.ctaMinutes() {
                        best = Swift.min(best ?? m, m)
                    }
                }
            }
        }
        return best
    }

    /// Compute suggested refresh date from now based on the soonest arrival.
    /// - Parameters:
    ///   - now: Base date to schedule from.
    ///   - lastUpdated: When the arrivals were fetched. If provided, we adjust
    ///     the earliest minutes by the cache age to better match real time.
    /// Policy: clamp(earliest - ageMinutes)*60 - 45s, min 60s, max 15m. If no times, use 5m.
    func suggestedRefresh(from now: Date, lastUpdated: Date? = nil) -> Date {
        guard var minutes = earliestMinutes() else {
            // When we have no arrivals (e.g. offline), retry quickly so we recover as soon as the
            // network returns instead of forcing the user to wait several minutes.
            return now.addingTimeInterval(60)
        }

        if let last = lastUpdated {
            let ageMinutes = Int(now.timeIntervalSince(last) / 60.0)
            minutes = Swift.max(0, minutes - ageMinutes)
        }

        let target = Swift.max(TimeInterval(minutes) * 60 - RefreshPolicy.earlySkew,
                               RefreshPolicy.minInterval)
        let clamped = Swift.min(target, RefreshPolicy.maxInterval)
        return now.addingTimeInterval(clamped)
    }
}
  
