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
private let widgetKindID = "CtaTimesWidget"

struct TimesEntry: TimelineEntry {
    let date: Date
    let configuration: FavoriteSelectionIntent
    let arrivals: [Arrival]
    let lastUpdated: Date?
    let favorite: Favorite?
    let favorites: [Favorite]
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
              favorite: nil,
              favorites: [])
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
#if DEBUG
        log("snapshot(for:) favorite=", configuration.favorite?.id ?? "nil")  
#endif
        return await loadEntry(configuration: configuration, family: context.family)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = await loadEntry(configuration: configuration, family: context.family)
        let next = entry.arrivals.suggestedRefresh(from: entry.date, lastUpdated: entry.lastUpdated)
#if DEBUG
        log("timeline(for:) favorite=", configuration.favorite?.id ?? "nil",
            "arrivals:", entry.arrivals.count,
            "now:", ts(Date()),
            "lastUpdated:", ts(entry.lastUpdated),
            "next:", ts(next))
#endif

        // Kick a best‑effort background refresh if the cache is getting old.
        maybeRefreshArrivalsInBackground()
        // Strategy: provide a second "tick" entry at `next` and use .atEnd.
        // This tends to be honored more reliably by WidgetKit than a single
        // entry with `.after(next)`, and it also ensures the widget view
        // re-renders at `next` even if no network occurs.
        let tick = TimesEntry(date: next,
                              configuration: configuration,
                              arrivals: entry.arrivals,
                              lastUpdated: entry.lastUpdated,
                              favorite: entry.favorite,
                              favorites: entry.favorites)
        return Timeline(entries: [entry, tick], policy: .atEnd)
    }

    // MARK: - Helpers
    private func loadEntry(configuration: Intent, family: WidgetFamily) async -> Entry {
        let now = Date()
        let favoriteID = configuration.favorite?.id
        let (allArrivals, modified) = readCachedArrivals()
        let allFavorites = loadFavorites()
        let selectedFavorites: [Favorite]

        if let id = favoriteID, id == FavoriteEntity.all.id {
            let limit = (family == .systemLarge) ? 4 : 2
            selectedFavorites = Array(allFavorites.prefix(limit))
        } else if let id = favoriteID, !id.isEmpty,
                  let match = allFavorites.first(where: { $0.id == id }) {
            selectedFavorites = [match]
        } else {
            selectedFavorites = []
        }

        let allowedIDs = Set(selectedFavorites.map(\.id))
        let filtered = allArrivals.filter { allowedIDs.contains($0.favoriteID) }

        let entry = Entry(date: now,
                     configuration: configuration,
                     arrivals: filtered,
                     lastUpdated: modified,
                     favorite: selectedFavorites.first,
                     favorites: selectedFavorites)
#if DEBUG
        log("loadEntry:", "favoriteID=", favoriteID ?? "nil",
            "selectedFavorites=", selectedFavorites.count,
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

    private func loadFavorites() -> [Favorite] {
        let store = SharedStore(groupID: appGroupID)
        let dtos = store.loadFavoritesDTO()
        return [Favorite].fromDTOs(dtos)
    }

    // MARK: - Opportunistic background fetch
    private func maybeRefreshArrivalsInBackground(now: Date = .now) {
        // Throttle: only when cache is older than 2 minutes.
        let store = SharedStore(groupID: appGroupID)
        let dtos = store.loadFavoritesDTO()
        let favorites = [Favorite].fromDTOs(dtos)
        guard !favorites.isEmpty else { return }

        // Inspect the cache timestamp
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let url = base.appendingPathComponent("arrivals.json")
        let cached = [Arrival].loadFromWithTimestamp(url: url, now: now)
        let age = cached == nil ? TimeInterval.greatestFiniteMagnitude : now.timeIntervalSince(cached!.fetchedAt)
        guard age > 120 else { return } // >2 minutes old

#if DEBUG
        log("maybeRefreshArrivalsInBackground: triggering fetch; age=", age, "sec")
#endif
        Task.detached(priority: .background) {
            do {
                let service: CTAService = CTAServiceLive()
                let arrivals = try await service.arrivals(for: favorites)
                arrivals.save(to: url, now: now)
                WidgetCenter.shared.reloadTimelines(ofKind: widgetKindID)
#if DEBUG
                log("background fetch complete → reload timelines")
#endif
            } catch {
#if DEBUG
                log("background fetch error:", String(describing: error))
#endif
            }
        }
    }
}
