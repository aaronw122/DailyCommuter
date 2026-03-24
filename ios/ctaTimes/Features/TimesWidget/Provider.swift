//
//  Provider.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/23/25.
//

import WidgetKit
import AppIntents
import Foundation
import Network

private let appGroupID = "group.com.yourco.dailycommuter"
private let widgetKindID = "CtaTimesWidget"
private let offlineFlagKey = "ctaTimes.offline"
private let manualRefreshKey = "ctaTimes.manualRefreshAt"

struct TimesEntry: TimelineEntry {
    let date: Date
    let configuration: FavoriteSelectionIntent
    let arrivals: [Arrival]
    let lastUpdated: Date?
    let favorite: Favorite?
    let favorites: [Favorite]
    let isOffline: Bool
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
              favorites: [],
              isOffline: false)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
#if DEBUG
        log("snapshot(for:) favorite=", configuration.favorite?.id ?? "nil")  
#endif
        return await loadEntry(configuration: configuration, family: context.family)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let now = Date()
        let entry = await loadEntry(configuration: configuration, family: context.family)

        maybeRefreshArrivalsInBackground()

        let nextRefresh = nextScheduledRefreshDate(now: now)
#if DEBUG
        log("timeline(for:) favorite=", configuration.favorite?.id ?? "nil",
            "arrivals:", entry.arrivals.count,
            "now:", ts(now),
            "lastUpdated:", ts(entry.lastUpdated),
            "next:", ts(nextRefresh))
#endif

        let policy: TimelineReloadPolicy = {
            if let next = nextRefresh {
                return .after(next)
            } else {
                return .atEnd
            }
        }()

        return Timeline(entries: [entry], policy: policy)
    }

    // MARK: - Helpers
    private func loadEntry(configuration: Intent, family: WidgetFamily) async -> Entry {
        let now = Date()
        let favoriteID = configuration.favorite?.id
        let (allArrivals, modified) = readCachedArrivals(now: now)
        let allFavorites = loadFavorites()
        let selectedFavorites: [Favorite]
        let isOffline = await resolveOfflineStatus()

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
                     favorites: selectedFavorites,
                     isOffline: isOffline)
#if DEBUG
        log("loadEntry:", "favoriteID=", favoriteID ?? "nil",
            "selectedFavorites=", selectedFavorites.count,
            "filtered=", filtered.count, "cachedModified=", ts(modified))
#endif
        return entry
    }

    private func readCachedArrivals(now: Date = .now) -> ([Arrival], Date?) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("arrivals.json") else {
            return ([], nil)
        }

        // Prefer embedded fetchedAt timestamp from cache payload.
        // Fall back to arrivals-only decode if needed.
        let decodedWithTS = [Arrival].loadFromWithTimestamp(url: url, now: now, allowStale: true)
        let arrivals = decodedWithTS?.arrivals ?? ([Arrival].loadFrom(url: url, now: now) ?? [])
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
                await MainActor.run {
                    WidgetCenter.shared.reloadTimelines(ofKind: widgetKindID)
                }
#if DEBUG
                log("background fetch complete → reload timelines")
#endif
            } catch {
#if DEBUG
                log("background fetch error:", String(describing: error))
#endif
                await MainActor.run {
                    WidgetCenter.shared.reloadTimelines(ofKind: widgetKindID)
                }
            }
        }
    }

    private func resolveOfflineStatus() async -> Bool {
        let defaultsFlag = UserDefaults(suiteName: appGroupID)?.bool(forKey: offlineFlagKey) ?? false
        if defaultsFlag { return true }
        if let reachable = await isNetworkReachable(timeout: 0.5) {
            return !reachable
        }
        return false
    }

    private func isNetworkReachable(timeout: TimeInterval = 0.5) async -> Bool? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "TimesProvider.pathMonitor")
            var resumed = false
            monitor.pathUpdateHandler = { path in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: path.status == .satisfied)
                monitor.cancel()
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: nil)
                monitor.cancel()
            }
        }
    }

    private func manualRefreshStart() -> Date? {
        let defaults = UserDefaults(suiteName: appGroupID)
        let stored = defaults?.double(forKey: manualRefreshKey) ?? 0
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }

    private func nextScheduledRefreshDate(now: Date) -> Date? {
        guard let start = manualRefreshStart() else { return nil }
        let stage1Offsets = stride(from: 2.0, through: 20.0, by: 2.0).map { $0 * 60 }
        let stage2Offsets = stride(from: 25.0, through: 40.0, by: 5.0).map { $0 * 60 }
        let allOffsets = stage1Offsets + stage2Offsets

        for offset in allOffsets {
            let target = start.addingTimeInterval(offset)
            if target > now {
                return target
            }
        }

        // Window expired; clear the stored timestamp.
        UserDefaults(suiteName: appGroupID)?.removeObject(forKey: manualRefreshKey)
        return nil
    }
}
