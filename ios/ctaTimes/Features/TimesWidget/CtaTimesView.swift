//
//  CtaTimesView.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 7/29/25.
//

import SwiftUI
import WidgetKit
import AppIntents

struct CtaTimesView: View {
    let entry: TimesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(.white, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if entry.configuration.favorite == nil {
            // Not configured yet – prompt to select a favorite via the widget's config sheet.
            VStack(alignment: .leading, spacing: 6) {
                Text("Select your favorite")
                    .font(.headline)
                Text("Long-press and choose Edit Widget to pick from your favorites.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if showsAllFavorites {
            allFavoritesContent
        } else if entry.arrivals.isEmpty {
            if entry.isOffline {
                offlineNotice
            } else {
                fetchingNotice
            }
        } else {
            singleFavoriteContent
        }
    }
}

// MARK: - Subviews

private extension CtaTimesView {
    var showsAllFavorites: Bool {
        entry.configuration.favorite?.id == FavoriteEntity.all.id
    }

    var primaryFavorite: Favorite? {
        entry.favorite ?? entry.favorites.first
    }

    @ViewBuilder
    var singleFavoriteContent: some View {
        if let favorite = primaryFavorite {
            let arrivalStops = entry.arrivals.first(where: { $0.favoriteID == favorite.id })?.stops
                ?? entry.arrivals.first?.stops
                ?? []
            let ordered = orderedStops(for: favorite, incoming: arrivalStops)
            let limit = maxRowsForCurrentFamily()
            let displayStops = Array(ordered.prefix(limit))

            VStack(alignment: .leading, spacing: 12) {
                header(for: favorite)
                Divider()
                    .overlay(Color(red: 223/255, green: 224/255, blue: 228/255).opacity(1))
                ForEach(Array(displayStops.enumerated()), id: \.element.id) { index, stop in
                    row(for: stop, favorite: favorite)
                    if index < displayStops.count - 1 {
                        Divider()
                            .overlay(Color(red: 223/255, green: 224/255, blue: 228/255).opacity(1))
                    }
                }
                lastUpdatedView
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save a favorite in the Daily Commuter app to show arrivals here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var allFavoritesContent: some View {
        let limit = family == .systemLarge ? 4 : 2
        let favorites = entry.favorites.prefix(limit)
        if favorites.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save favorites in the Daily Commuter app to show them here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .imageScale(.medium)
                        .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 1.0))
                    Text("All Favorites")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(intent: RefreshTimesIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .tint(.secondary)
                }

                ForEach(favorites, id: \.id) { favorite in
                    let arrival = entry.arrivals.first(where: { $0.favoriteID == favorite.id })
                    favoriteCard(for: favorite, arrival: arrival)
                }
                lastUpdatedView
            }
            .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
        }
    }

    func header(for favorite: Favorite?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin")
                .imageScale(.medium)
                .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 1.0))
            Text(entry.configuration.favorite?.name ?? favorite?.name ?? "Favorite")
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 1.0))
            Spacer()
            Button(intent: RefreshTimesIntent()) {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .tint(.secondary)
        }
    }

    func favoriteCard(for favorite: Favorite, arrival: Arrival?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mappin")
                    .imageScale(.medium)
                    .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 1.0))
                Text(favorite.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer()
            }

            if let arrival = arrival, !arrival.stops.isEmpty {
                let ordered = orderedStops(for: favorite, incoming: arrival.stops)
                let displayStops = Array(ordered.prefix(1))
                ForEach(displayStops, id: \.id) { stop in
                    row(for: stop, favorite: favorite)
                }
            } else {
                Text("Fetching arrivals…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
    }

    private var offlineNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let last = entry.lastUpdated {
                Text("You’re currently offline. Last refreshed: \(timeString(from: last))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("You’re currently offline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fetchingNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fetching arrivals…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var lastUpdatedView: some View {
        if let last = entry.lastUpdated {
            let prefix = entry.isOffline ? "You’re currently offline. " : ""
            Text("\(prefix)Last refreshed: \(timeString(from: last))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if entry.isOffline {
            Text("You’re currently offline. Last refreshed: unavailable")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    func row(for stop: StopArrival, favorite: Favorite?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            let kind = kindForStop(stop, favorite: favorite)
            Image(systemName: kind == .bus ? "bus.fill" : "tram.fill")
                .foregroundStyle(kind == .bus ? .green : .blue)
                .font(.system(size: 16, weight: .regular))
                .scaleEffect(kind == .train ? 1.12 : 1.0)
                .frame(width: 18, height: 18, alignment: .center)

            HStack(spacing: 10) {
                Text(routeDisplayName(for: stop, favorite: favorite))
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 0.7))
                Text(destination(for: stop))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .foregroundColor(Color(red: 113/255, green: 113/255, blue: 113/255, opacity: 1.0))
            }
            Spacer(minLength: 4)

            if hasNoServiceMessage(stop.time) {
                Text("No service")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                let ageMins = minutesSinceLastUpdate()
                let times = stop.time
                    .compactMap { displayTime($0, ageMinutes: ageMins) }
                    .prefix(3)
                if times.isEmpty {
                    Text("No arrivals")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(times.joined(separator: ", "))
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 0.7))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    func destination(for stop: StopArrival) -> String {
        if let dest = stop.time.first?.destination, !dest.isEmpty { return dest }
        return stop.direction
    }

    func kindForStop(_ stop: StopArrival, favorite: Favorite?) -> Stop.Kind {
        guard let fav = favorite else { return .train }
        return fav.stops.first(where: { $0.stopId == stop.stopId })?.kind ?? .train
    }

    func routeDisplayName(for stop: StopArrival, favorite: Favorite?) -> String {
        if let fav = favorite,
           let matched = fav.stops.first(where: { $0.stopId == stop.stopId }),
           !matched.routeName.isEmpty {
            return firstWord(of: matched.routeName)
        }
        return stop.routeId
    }

    func firstWord(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) {
            return String(trimmed[..<r.lowerBound])
        }
        return trimmed
    }
  
    func timeString(from date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "h:mma"
        let str = df.string(from: date)
        return str.lowercased()
    }

    func hasNoServiceMessage(_ times: [TimeInfo]) -> Bool {
        let variants = [
            "No service is scheduled at this time",
            "No service available at this time"
        ]
        return times.contains { t in
            let value = t.time.trimmingCharacters(in: .whitespacesAndNewlines)
            return variants.contains { value.localizedCaseInsensitiveCompare($0) == .orderedSame }
        }
    }

    func minutesSinceLastUpdate() -> Int {
        guard let last = entry.lastUpdated else { return 0 }
        let delta = entry.date.timeIntervalSince(last)
        return max(0, Int(delta / 60.0))
    }

    func displayTime(_ info: TimeInfo, ageMinutes: Int) -> String? {
        let raw = info.time.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = raw.uppercased()
        if upper == "DUE" {
            return ageMinutes >= 2 ? nil : "DUE"
        }
        if let n = Int(upper) {
            let adjusted = max(0, n - ageMinutes)
            if adjusted <= -2 { return nil }
            return adjusted <= 0 ? "DUE" : String(adjusted)
        }
        return raw
    }

    func orderedStops(for favorite: Favorite?, incoming: [StopArrival]) -> [StopArrival] {
        guard let fav = favorite else { return incoming }
        let order = fav.stops.map { $0.stopId }
        let indexById = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return incoming
            .filter { indexById[$0.stopId] != nil }
            .sorted { lhs, rhs in
                (indexById[lhs.stopId] ?? Int.max) < (indexById[rhs.stopId] ?? Int.max)
            }
    }

    func maxRowsForCurrentFamily() -> Int {
        switch family {
        case .systemLarge: return 4
        default: return 2
        }
    }
}
