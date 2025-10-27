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
        } else if entry.arrivals.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("You’re offline, connect to internet to see times.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            // Card with header + rows + footer
            // Order by the Favorite's stop order; then cap rows by widget family.
            let allStops = entry.arrivals.flatMap { $0.stops }
            let ordered = orderedStops(from: allStops)
            let limit = maxRowsForCurrentFamily()
            let displayStops = Array(ordered.prefix(limit))
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()
                .overlay(Color(red: 223/255, green: 224/255, blue: 228/255).opacity(1))
                ForEach(Array(displayStops.enumerated()), id: \.element.id) { index, stop in
                    row(for: stop)
                    if index < displayStops.count - 1 {
                        Divider().overlay(Color(red: 223/255, green: 224/255, blue: 228/255).opacity(1))
                    }
                }
                if let last = entry.lastUpdated {
                    Text("Last refreshed: \(timeString(from: last))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
        }
    }
}

// MARK: - Subviews

private extension CtaTimesView {
    var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin")
                .imageScale(.medium)
                .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 1.0))
            Text(entry.configuration.favorite?.name ?? entry.favorite?.name ?? "Favorite")
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

    func row(for stop: StopArrival) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // Icon per mode
            let kind = kindForStop(id: stop.stopId)
            Image(systemName: kind == .bus ? "bus.fill" : "tram.fill")
                .foregroundStyle(kind == .bus ? .green : .blue)
                .font(.system(size: 16, weight: .regular))      // lock size to a point value
                .scaleEffect(kind == .train ? 1.12 : 1.0)         // tram needs a little boost
                .frame(width: 18, height: 18, alignment: .center)

            // Route name + destination
          HStack(spacing: 10){
            Text(routeDisplayName(for: stop))
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
          Spacer(minLength:4)

            // Up to 3 arrival times; handle "No service" special message
            if hasNoServiceMessage(stop.time) {
                Text("No service")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                let times = stop.time.prefix(3).map { $0.time }.joined(separator: ", ")
                Text(times)
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundColor(Color(red: 0/255, green: 0/255, blue: 0/255, opacity: 0.7))
            }
        }
        .accessibilityElement(children: .combine)
    }

    func destination(for stop: StopArrival) -> String {
        if let dest = stop.time.first?.destination, !dest.isEmpty { return dest }
        // Fallback: show direction if no destination
        return stop.direction
    }

    func kindForStop(id: String) -> Stop.Kind {
        guard let fav = entry.favorite else { return .train }
        return fav.stops.first(where: { $0.stopId == id })?.kind ?? .train
    }

    func routeDisplayName(for stop: StopArrival) -> String {
        // Prefer the human-friendly routeName from the user's Favorite stops.
        if let fav = entry.favorite,
           let matched = fav.stops.first(where: { $0.stopId == stop.stopId }),
           !matched.routeName.isEmpty {
            return firstWord(of: matched.routeName)
        }
        // Fallback: routeId is already a single token.
        return stop.routeId
    }

    func firstWord(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Find the first whitespace to cut at the first token.
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

    // MARK: - Times helpers
    func hasNoServiceMessage(_ times: [TimeInfo]) -> Bool {
        times.contains { t in
            t.time.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare("No service is scheduled at this time") == .orderedSame
        }
    }

    // MARK: - Ordering and limits
    func orderedStops(from incoming: [StopArrival]) -> [StopArrival] {
        guard let fav = entry.favorite else { return incoming }
        let order = fav.stops.map { $0.stopId }
        let indexById = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return incoming
            .filter { indexById[$0.stopId] != nil }
            .sorted { (lhs, rhs) in
                (indexById[lhs.stopId] ?? Int.max) < (indexById[rhs.stopId] ?? Int.max)
            }
    }

    func maxRowsForCurrentFamily() -> Int {
        switch family {
        case .systemLarge: return 4
        default: return 2 // systemMedium and others supported for this widget
        }
    }
}
