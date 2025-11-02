#if DEBUG
import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Preview Fixtures (no I/O)
private extension Favorite {
    static var previewFavorite: Favorite {
        Favorite(
            id: "fav-work",
            name: "Work",
            stops: [
                Stop(routeId: "56", routeName: "56", stopId: "s1", stopName: "Jeff Park", direction: "Northbound", kind: .bus),
                Stop(routeId: "Blue", routeName: "Blue Line", stopId: "s2", stopName: "Forest Park", direction: "W", kind: .train)
            ]
        )
    }
}

private extension TimesEntry {
    static func config(for fav: Favorite) -> FavoriteSelectionIntent {
        var cfg = FavoriteSelectionIntent()
        cfg.favorite = FavoriteEntity(id: fav.id, name: fav.name)
        return cfg
    }

    static var previewPopulated: TimesEntry {
        let fav = Favorite.previewFavorite
        let arrivals: [Arrival] = [
            Arrival(
                favoriteID: fav.id,
                stops: [
                    StopArrival(
                        stopId: "s1",
                        routeId: "56",
                        direction: "N",
                        time: [
                            TimeInfo(time: "DUE", destination: "Jeff Park"),
                            TimeInfo(time: "29", destination: "Jeff Park"),
                            TimeInfo(time: "41", destination: "Jeff Park")
                        ]
                    ),
                    StopArrival(
                        stopId: "s2",
                        routeId: "Blue",
                        direction: "W",
                        time: [
                            TimeInfo(time: "12", destination: "Forest Park"),
                            TimeInfo(time: "19", destination: "Forest Park"),
                            TimeInfo(time: "27", destination: "Forest Park")
                        ]
                    )
                ]
            )
        ]
        return TimesEntry(
            date: .now,
            configuration: config(for: fav),
            arrivals: arrivals,
            lastUpdated: Date(),
            favorite: fav,
            favorites: [fav],
            isOffline: false
        )
    }

    static var previewNoArrivals: TimesEntry {
        let fav = Favorite.previewFavorite
        return TimesEntry(
            date: .now,
            configuration: config(for: fav),
            arrivals: [],
            lastUpdated: Date(),
            favorite: fav,
            favorites: [fav],
            isOffline: false
        )
    }

    static var previewOffline: TimesEntry {
        let fav = Favorite.previewFavorite
        return TimesEntry(
            date: .now,
            configuration: config(for: fav),
            arrivals: [],
            lastUpdated: nil, // no timestamp to imply stale/offline
            favorite: fav,
            favorites: [fav],
            isOffline: true
        )
    }
}

// MARK: - Classic PreviewProvider (required for WidgetPreviewContext sizing)
struct CtaTimesView_ClassicPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            CtaTimesView(entry: .previewPopulated)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium – Populated")

            CtaTimesView(entry: .previewNoArrivals)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium – No Arrivals")

            CtaTimesView(entry: .previewOffline)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .environment(\.colorScheme, .dark)
                .environment(\.sizeCategory, .accessibilityExtraLarge)
                .previewDisplayName("Large – Offline (Dark, XL)")
        }
    }
}

// MARK: - Minimal #Preview to ensure the view is built by the target
#Preview("Build – Populated") {
    CtaTimesView(entry: .previewPopulated)
}

#endif
