//
//  RefreshTimesIntent.swift
//  DailyCommuter
//
//  Manual refresh for the widget via AppIntent (iOS 17+).
//  Best-effort: on failure, we silently keep showing cached data/age.
//

import AppIntents
import WidgetKit
import Foundation

// Keep this in sync with Provider.swift
private let appGroupID = "group.com.yourco.dailycommuter"
private let widgetKind = "CtaTimesWidget"

struct RefreshTimesIntent: AppIntent {
    static var title: LocalizedStringResource { "Refresh Arrivals" }
    static var description: IntentDescription { "Fetch latest arrivals and update the widget." }

    func perform() async throws -> some IntentResult {
        // 1) Load favorites from App Group (DTOs) → map to domain
        let store = SharedStore(groupID: appGroupID)
        let dtos = store.loadFavoritesDTO()
        let favorites = [Favorite].fromDTOs(dtos)
        guard !favorites.isEmpty else {
            // Nothing to fetch; still ask WidgetCenter to reload so timestamps update
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            return .result()
        }

        // 2) Best-effort network fetch using the shared CTAService
        do {
            let service: CTAService = CTAServiceLive()
            let arrivals = try await service.arrivals(for: favorites)

            // 3) Save arrivals to App Group cache with timestamp wrapper
            if let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let url = base.appendingPathComponent("arrivals.json")
                arrivals.save(to: url, now: .now)
            }

            // 4) Nudge the widget to reload and reflect new cache + "Updated X min ago"
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } catch {
            // Fail silently by design – keep existing cache/timestamp
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }

        return .result()
    }
}
