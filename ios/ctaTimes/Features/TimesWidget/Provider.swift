//
//  Provider.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/23/25.
//

import WidgetKit
import AppIntents
import Foundation

private let appGroupID = "group.com.yourco.dailycommuter"

struct TimesEntry: TimelineEntry {
    let date: Date
    let configuration: FavoriteSelectionIntent
    let arrivals: [Arrival]
    let lastUpdated: Date?
    let favorite: Favorite?
}

struct TimesProvider: AppIntentTimelineProvider {
    typealias Entry = TimesEntry
    typealias Intent = FavoriteSelectionIntent

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(),
              configuration: FavoriteSelectionIntent(),
              arrivals: [],
              lastUpdated: nil,
              favorite: nil)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        await loadEntry(configuration: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = await loadEntry(configuration: configuration)
        // Skeleton refresh policy: use helper; currently 5 minutes.
        let next = entry.arrivals.suggestedRefresh(from: entry.date)
        return Timeline(entries: [entry], policy: .after(next))
    }

    // MARK: - Helpers
    private func loadEntry(configuration: Intent) async -> Entry {
        let now = Date()
        let favoriteID = configuration.favorite?.id
        let (allArrivals, modified) = readCachedArrivals()
        let favoriteMeta = readFavorite(id: favoriteID)
        let filtered: [Arrival]
        // Require explicit selection: if no favorite selected, show nothing and prompt in the view.
        if let id = favoriteID, !id.isEmpty {
            filtered = allArrivals.filter { $0.favoriteID == id }
        } else {
            filtered = []
        }
        return Entry(date: now,
                     configuration: configuration,
                     arrivals: filtered,
                     lastUpdated: modified,
                     favorite: favoriteMeta)
    }

    private func readCachedArrivals() -> ([Arrival], Date?) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("arrivals.json") else {
            return ([], nil)
        }

        // Decode only if fresh (Mapping+Arrival handles TTL + payload shape)
        let arrivals = [Arrival].loadFrom(url: url) ?? []

        var modified: Date?
        if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) {
            modified = values.contentModificationDate
        }
        return (arrivals, modified)
    }

    private func readFavorite(id: String?) -> Favorite? {
        guard let id, !id.isEmpty else { return nil }
        let store = SharedStore(groupID: appGroupID)
        let dtos = store.loadFavoritesDTO()
        let favs = [Favorite].fromDTOs(dtos)
        return favs.first { $0.id == id }
    }
}
