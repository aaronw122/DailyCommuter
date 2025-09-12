//
//  CtaTimesWidget.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 9/10/25.
//

import WidgetKit
import SwiftUI

struct CtaTimesWidget: Widget {
    let kind: String = "CtaTimesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: FavoriteSelectionIntent.self,
                               provider: TimesProvider()) { entry in
            CtaTimesView(entry: entry)
        }
        .configurationDisplayName("CTA Times")
        .description("Shows upcoming arrivals for your selected favorite.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
