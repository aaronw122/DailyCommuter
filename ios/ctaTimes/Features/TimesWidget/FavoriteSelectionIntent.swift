//
//  FavoriteSelectionIntent.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/23/25.
//

import AppIntents
import Foundation

// MARK: - AppEntity representing a Favorite from the shared store
struct FavoriteEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favorite")

    static var defaultQuery = FavoritesQuery()

    typealias ID = String
    var id: ID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: name))
    }
}

// MARK: - Query provider backed by FavoritesStore (App Group)
struct FavoritesQuery: EntityQuery {
    func entities(for identifiers: [FavoriteEntity.ID]) async throws -> [FavoriteEntity] {
        let favs: [Favorite] = await MainActor.run { FavoritesStore.shared.favorites }
        return favs
            .filter { identifiers.contains($0.id) }
            .map { FavoriteEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [FavoriteEntity] {
        let favs: [Favorite] = await MainActor.run { FavoritesStore.shared.favorites }
        return favs.map { FavoriteEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Widget configuration intent
struct FavoriteSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Favorite" }
    static var description: IntentDescription { "Choose which favorite this widget displays." }

    @Parameter(title: "Favorite")
    var favorite: FavoriteEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Favorite: \(\.$favorite)")
    }
}
