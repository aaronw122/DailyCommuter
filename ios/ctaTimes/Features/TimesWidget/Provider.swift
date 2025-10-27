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

#if DEBUG
    private func log(_ items: Any...) {
        let msg = items.map { String(describing: $0) }.joined(separator: " ")
        print("[TimesProvider]", msg)
    }
    private static let df: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    private func ts(_ date: Date?) -> String {
        guard let d = date else { return "nil" }
        return Self.df.string(from: d)
    }
#endif

    func placeholder(in context: Context) -> Entry {
#if DEBUG
        log("placeholder(in:)")
#endif
        return Entry(date: Date(),
              configuration: FavoriteSelectionIntent(),
              arrivals: [],
              lastUpdated: nil,
              favorite: nil)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
#if DEBUG
        log("snapshot(for:) favorite=", configuration.favorite?.id ?? "nil")  
#endif
        return await loadEntry(configuration: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = await loadEntry(configuration: configuration)
        let next = entry.arrivals.suggestedRefresh(from: entry.date, lastUpdated: entry.lastUpdated)
#if DEBUG
        log("timeline(for:) favorite=", configuration.favorite?.id ?? "nil",
            "arrivals:", entry.arrivals.count,
            "now:", ts(Date()),
            "lastUpdated:", ts(entry.lastUpdated),
            "next:", ts(next))
#endif
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
        let entry = Entry(date: now,
                     configuration: configuration,
                     arrivals: filtered,
                     lastUpdated: modified,
                     favorite: favoriteMeta)
        #if DEBUG
        log("loadEntry:", "favoriteID=", favoriteID ?? "nil",
            "filtered=", filtered.count, "cachedModified=", ts(modified))
        #endif
        return entry
    }

    private func readCachedArrivals() -> ([Arrival], Date?) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("arrivals.json") else {
            return ([], nil)
        }

        // Prefer embedded fetchedAt timestamp from cache payload.
        // Fall back to arrivals-only decode if needed.
        let decodedWithTS = [Arrival].loadFromWithTimestamp(url: url)
        let arrivals = decodedWithTS?.arrivals ?? ([Arrival].loadFrom(url: url) ?? [])
        let modified = decodedWithTS?.fetchedAt
        #if DEBUG
        log("readCachedArrivals:", "count=", arrivals.count, "modified=", ts(modified))
        #endif
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
