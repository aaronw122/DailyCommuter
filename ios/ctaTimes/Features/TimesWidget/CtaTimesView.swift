//
//  CtaTimesView.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 7/29/25.
//

import SwiftUI
import WidgetKit

struct CtaTimesView: View {
    let entry: TimesEntry

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()

            // Last updated timestamp (bottom-right)
            if let last = entry.lastUpdated {
                Text(last, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding([.trailing, .bottom], 8)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
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
            // Skeleton rows – show route and first time per stop
            let stops = entry.arrivals.flatMap { $0.stops }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(stops.prefix(4), id: \.id) { stop in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(stop.routeId)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(stop.direction)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        if let first = stop.time.first?.time {
                            Text(first)
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
