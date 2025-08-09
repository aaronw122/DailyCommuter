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
    /// - We convert to an absolute `Date` at mapping time so the widget can schedule timelines.
    init?(dto: SimpleTimeDTO, stopId: String, routeId: String, now: Date = .now) {
        // Normalize
        let t = dto.times.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // minutes: "11"
        if let mins = Int(t) {
            let clamped = max(mins, 0) // avoid negative due to clock skew
            self = Arrival(
                stopId: stopId,
                routeId: routeId,
                destination: dto.dest,
                arrivalAt: now.addingTimeInterval(TimeInterval(clamped * 60))
            )
            return
        }

        // "DUE" ≈ 30s from now so it shows first and triggers quick refresh
        if t == "DUE" {
            self = Arrival(
                stopId: stopId,
                routeId: routeId,
                destination: dto.dest,
                arrivalAt: now.addingTimeInterval(30)
            )
            return
        }

        // "DLY" -> time is unknown; drop it from the timeline (or choose a fallback if you prefer)
        if t == "DLY" {
            return nil
        }

        // Unknown token -> drop
        return nil
    }
}

public extension Array where Element == Arrival {
    /// Suggested next widget reload:
    /// earliest arrival - 45s, clamped to [60s, 15m]. Falls back to 5m if no future arrivals.
    func suggestedRefresh(from now: Date) -> Date {
        let soonest = self.map(\.arrivalAt).filter { $0 > now }.min()
        let target = soonest?.addingTimeInterval(-45) ?? now.addingTimeInterval(5 * 60)
      return Swift.min(Swift.max(target, now.addingTimeInterval(60)), now.addingTimeInterval(15 * 60))
    }
}
