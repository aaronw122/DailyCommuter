//
//  ctaTimes.swift
//  ctaTimes
//
//  Created by Aaron Williams on 7/28/25.
//

import WidgetKit
import SwiftUI
import Foundation

/// ⚠️ Make sure `FavoritesStore.swift` (and its dependencies) are added to the widget target membership.
/// This widget will trigger a background refresh of `arrivals.json` and show whether the cache file exists.
private let appGroupID = "group.com.yourco.dailycommuter"

struct Provider: AppIntentTimelineProvider {
    typealias Entry = SimpleEntry
    typealias Intent = FavoriteSelectionIntent
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: FavoriteSelectionIntent(),
            hasCache: false,
            arrivalsCount: 0,
            lastModified: nil
        )
    }

    func snapshot(for configuration: FavoriteSelectionIntent, in context: Context) async -> SimpleEntry {
        // Fire-and-forget: ask the app-side FavoritesStore to refresh arrivals.json
        await MainActor.run {
            FavoritesStore.shared.refreshArrivalsCache()
        }

        let status = await CacheStatus.read(selectedFavoriteID: configuration.favorite?.id)
        return SimpleEntry(
            date: Date(),
            configuration: configuration,
            hasCache: status.exists,
            arrivalsCount: status.count,
            lastModified: status.lastModified
        )
    }
    
    func timeline(for configuration: FavoriteSelectionIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let now = Date()

        // Kick off a refresh every time the widget asks for a timeline (for validation only).
        await MainActor.run {
            FavoritesStore.shared.refreshArrivalsCache()
        }

        // Entry 1: current status
        let statusNow = await CacheStatus.read(selectedFavoriteID: configuration.favorite?.id)
        entries.append(
            SimpleEntry(
                date: now,
                configuration: configuration,
                hasCache: statusNow.exists,
                arrivalsCount: statusNow.count,
                lastModified: statusNow.lastModified
            )
        )

        // Entry 2: check again shortly to pick up the newly written cache
        let later = now.addingTimeInterval(60)
        let statusLater = await CacheStatus.read(selectedFavoriteID: configuration.favorite?.id)
        entries.append(
            SimpleEntry(
                date: later,
                configuration: configuration,
                hasCache: statusLater.exists,
                arrivalsCount: statusLater.count,
                lastModified: statusLater.lastModified
            )
        )

        return Timeline(entries: entries, policy: .after(later))
    }
}

/// Lightweight helper to inspect the arrivals cache in the App Group.
private enum CacheStatus {
    static func url() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("arrivals.json")
    }

    static func read(selectedFavoriteID: String?) async -> (exists: Bool, count: Int, lastModified: Date?) {
        guard let url = url() else { return (false, 0, nil) }

        let exists = FileManager.default.fileExists(atPath: url.path)

        var modified: Date?
        if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) {
            modified = values.contentModificationDate
        }

        // Ask FavoritesStore to decode the cached arrivals and compute a count.
        // If a favorite is selected, count times for that favorite only; otherwise count all groups.
        let count = await MainActor.run { () -> Int in
            let arrivals = FavoritesStore.shared.loadCachedArrivals()
            if let favID = selectedFavoriteID,
               let match = arrivals.first(where: { $0.favoriteID == favID }) {
                // Sum up all time entries across stops for the selected favorite.
                return match.stops.reduce(0) { $0 + $1.time.count }
            } else {
                return arrivals.count
            }
        }

        return (exists, count, modified)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: FavoriteSelectionIntent

    // Debug/validation fields
    let hasCache: Bool
    let arrivalsCount: Int
    let lastModified: Date?
}

struct ctaTimesEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("arrivals.json")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: entry.hasCache ? "checkmark.circle.fill" : "xmark.circle")
                    .imageScale(.small)
                Text(entry.hasCache ? "Created" : "Missing")
                    .font(.headline)
                    .lineLimit(1)
            }

            Text("Arrivals: \(entry.arrivalsCount)")
                .font(.footnote)
                .lineLimit(1)

            if let favorite = entry.configuration.favorite {
                if favorite.id == FavoriteEntity.all.id {
                    Text("Favorite: All")
                        .font(.footnote)
                        .lineLimit(1)
                } else {
                    Text("Favorite: \(favorite.name)")
                        .font(.footnote)
                        .lineLimit(1)
                }
            } else {
                Text("Favorite: —")
                    .font(.footnote)
                    .lineLimit(1)
            }

            if let last = entry.lastModified {
                Text("Updated \(last, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Updated —")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ctaTimes: Widget {
    let kind: String = "ctaTimes"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FavoriteSelectionIntent.self, provider: Provider()) { entry in
            ctaTimesEntryView(entry: entry)
        }
    }
}

/// If you already have another `@main` in the widget target, remove this one to avoid duplicates.

#Preview(as: .systemMedium) {
    ctaTimes()
} timeline: {
    SimpleEntry(date: .now, configuration: .init(), hasCache: false, arrivalsCount: 0, lastModified: nil)
}
