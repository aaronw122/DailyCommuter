//
//  FavoriteSelectionIntent.swift
//  DailyCommuter
//
//  Created by Codex on 9/10/25.
//

import AppIntents
import Foundation

private let appGroupID = "group.com.yourco.dailycommuter"

// MARK: - AppEntity representing a Favorite from the shared store
struct FavoriteEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Select Favorite")

    static var defaultQuery = FavoritesQuery()

    typealias ID = String
    var id: ID
    var name: String

    // Optional synthetic entity to allow an "All Favorites" choice
    static let all = FavoriteEntity(id: "all", name: "All Favorites")

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: name))
    }
}

// MARK: - Query provider backed by FavoritesStore (App Group)
struct FavoritesQuery: EntityQuery {
    private func loadFavorites() -> [Favorite] {
        let store = SharedStore(groupID: appGroupID)
        let dtos = store.loadFavoritesDTO()
        return [Favorite].fromDTOs(dtos)
    }

    func entities(for identifiers: [FavoriteEntity.ID]) async throws -> [FavoriteEntity] {
        let favorites = loadFavorites()
        return favorites
            .filter { identifiers.contains($0.id) }
            .map { FavoriteEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [FavoriteEntity] {
        let favorites = loadFavorites()
        let mapped = favorites.map { FavoriteEntity(id: $0.id, name: $0.name) }

        guard !mapped.isEmpty else { return [] }
        // Put a fast, concise set in the gallery picker. Include a synthetic "All" option first.
        return [FavoriteEntity.all] + Array(mapped.prefix(8))
    }

    func entities(matching query: String) async throws -> [FavoriteEntity] {
        let favorites = loadFavorites()
        let filtered = favorites.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return filtered.map { FavoriteEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() -> FavoriteEntity? { nil }
}

// MARK: - Widget configuration intent using an entity picker
struct FavoriteSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Favorite" }
    static var description: IntentDescription { "Choose which favorite this widget displays." }

    @Parameter(title: "Select Favorite", requestValueDialog: "Choose a favorite to show in the widget")
    var favorite: FavoriteEntity?

    init() {}

    static var parameterSummary: some ParameterSummary {
        // Use closure-based initializer to avoid inference issues with string interpolation.
        Summary { \.$favorite }
    }
}
