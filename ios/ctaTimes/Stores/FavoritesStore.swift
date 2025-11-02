//
//  FavoritesStore.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 7/29/25.
//

import Foundation
import Combine
import WidgetKit
import Network

@MainActor
final class FavoritesStore: ObservableObject {
    nonisolated(unsafe) private func dcLog(_ message: String) {
#if DEBUG
        print("📦 FavoritesStore:", message)
#endif
    }
    @Published private(set) var favorites: [Favorite] = []

    static let shared = FavoritesStore()
    static let offlineStatusKey = "ctaTimes.offline"

    private let suite   = UserDefaults(suiteName: "group.com.yourco.dailycommuter")!
    private let key     = "favorites"
    private let groupID = "group.com.yourco.dailycommuter"
    private let widgetKind = "CtaTimesWidget"
    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes (matches ArrivalCacheTTL)
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "FavoritesStore.pathMonitor")
    private var lastRefreshFailed = false

    private init() {
        dcLog("init()")
        load()
        pruneStaleArrivalsCache()
        // Warm the arrivals cache on launch so the widget has data ready
        refreshArrivalsCache()
        suite.set(false, forKey: Self.offlineStatusKey)
        startNetworkMonitoring()
    }
  
// MARK: - Favorites file (App Group)
    private func favoritesFileURL() -> URL? {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("favorites.json")
        dcLog("favoritesFileURL = \(url?.path ?? "nil")")
        return url
    }
  

    // MARK: CRUD
    func replaceAll(with list: [Favorite]) {
        favorites = list
        save()
        // When favorites change, refresh the arrivals cache in the background
        refreshArrivalsCache()
    }

    // MARK: Persistence
    private func load() {
      if let data = suite.data(forKey: key),
         let decoded = try? JSONDecoder().decode([Favorite].self, from: data) {
        favorites = decoded
        dcLog("load(): loaded from UserDefaults count=\(decoded.count)")
      } else if let url = favoritesFileURL(),
                let data = try? Data(contentsOf: url),
                let decoded = try? JSONDecoder().decode([Favorite].self, from: data) {
        favorites = decoded
        dcLog("load(): loaded from favorites.json count=\(decoded.count)")
        // Sync back to UserDefaults so subsequent loads are fast
        suite.set(data, forKey: key)
      } else {
        dcLog("load(): none found")
      }
    }

  private func save() {
    guard let data = try? JSONEncoder().encode(favorites) else {
      dcLog("save(): encode failed")
      return
    }
    // Persist to shared UserDefaults (source of truth for the app)
    suite.set(data, forKey: key)
    dcLog("save(): wrote favorites to UserDefaults count=\(favorites.count) bytes=\(data.count)")
    
    // Also mirror to favorites.json in the App Group so the widget (and debugging) can read it
    if let url = favoritesFileURL() {
      do {
        try data.write(to: url, options: .atomic)
        dcLog("save(): wrote favorites.json at \(url.path)")
      } catch {
        dcLog("save(): failed writing favorites.json: \(error)")
      }
    } else {
      dcLog("save(): favoritesFileURL() == nil")
      
    }
  }
  
    // MARK: - Arrivals cache (App Group)

    private func arrivalsCacheURL() -> URL? {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("arrivals.json")
        dcLog("arrivalsCacheURL = \(url?.path ?? "nil")")
        return url
    }

    /// Whether the cache file is fresh relative to cacheTTL.
    private func isCacheFresh(url: URL, now: Date) -> Bool {
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey]
        let values = try? url.resourceValues(forKeys: resourceKeys)
        guard let modified = values?.contentModificationDate else { return false }
        return now.timeIntervalSince(modified) < cacheTTL
    }

    /// Delete the arrivals cache file if it's older than the TTL.
    private func pruneStaleArrivalsCache(now: Date = .now) {
        guard let url = arrivalsCacheURL() else { return }
        dcLog("pruneStaleArrivalsCache check at \(url.path)")
        if FileManager.default.fileExists(atPath: url.path),
           !isCacheFresh(url: url, now: now) {
            dcLog("Arrivals cache is stale (TTL exceeded); keeping last payload for fallback UI.")
        }
    }

    /// Fire-and-forget network fetch → write arrivals.json in the App Group.
    /// - Uses CTAServiceLive to fetch arrivals for the current favorites.
    /// - Serializes the new nested `Arrival` model: one per favorite, containing grouped `StopArrival` arrays with their `Times`.
    func refreshArrivalsCache(using service: CTAService = CTAServiceLive(),
                              now: Date = .now) {
        let favs = favorites // snapshot on main actor
        guard !favs.isEmpty else {
            dcLog("refreshArrivalsCache aborted: favorites is empty")
            return
        }
        guard let url = arrivalsCacheURL() else {
            dcLog("refreshArrivalsCache aborted: arrivalsCacheURL() == nil")
            return
        }

        Task.detached(priority: .background) {
            self.dcLog("Starting network fetch for \(favs.count) favorites → \(url.path)")
            do {
                let arrivals = try await service.arrivals(for: favs)
                self.dcLog("Network fetch succeeded: wrote arrivals payload")
                arrivals.save(to: url, now: now)
                self.dcLog("Wrote arrivals.json at \(url.path)")
                await MainActor.run {
                    self.lastRefreshFailed = false
                    WidgetCenter.shared.reloadTimelines(ofKind: self.widgetKind)
                    self.suite.set(false, forKey: Self.offlineStatusKey)
                }
            } catch {
                self.dcLog("refreshArrivalsCache error: \(error)")
                await MainActor.run {
                    self.lastRefreshFailed = true
                    WidgetCenter.shared.reloadTimelines(ofKind: self.widgetKind)
                }
            }
        }
    }

    /// Read cached arrivals if fresh (≤ 30 minutes old); returns [] if missing/stale.
    func loadCachedArrivals(now: Date = .now) -> [Arrival] {
        guard let url = arrivalsCacheURL() else {
            dcLog("loadCachedArrivals: no URL")
            return []
        }
        dcLog("loadCachedArrivals at \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            dcLog("loadCachedArrivals: file missing")
            return []
        }

        guard isCacheFresh(url: url, now: now) else {
            dcLog("Cache is stale; deleting")
            try? FileManager.default.removeItem(at: url)
            return []
        }

        guard let arrivals = [Arrival].loadFrom(url: url, now: now) else {
            dcLog("loadCachedArrivals: decode failed")
            return []
        }
        dcLog("Decoded cached arrivals payload")
        return arrivals
    }

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let isOffline = path.status != .satisfied
            Task { @MainActor in
                self.suite.set(isOffline, forKey: Self.offlineStatusKey)
                if isOffline {
                    self.lastRefreshFailed = true
                } else if self.lastRefreshFailed {
                    self.dcLog("Network restored; triggering arrivals refresh.")
                    self.refreshArrivalsCache()
                }
            }
        }
        monitor.start(queue: monitorQueue)
        pathMonitor = monitor
    }

    deinit {
        pathMonitor?.cancel()
    }
}
