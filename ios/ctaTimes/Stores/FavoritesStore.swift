//
//  FavoritesStore.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 7/29/25.
//

import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [Favorite] = []

    static let shared = FavoritesStore()
    private let suite   = UserDefaults(suiteName: "group.com.yourco.dailycommuter")!
    private let key     = "favorites"

    private init() { load() }

    // MARK: CRUD
    func replaceAll(with list: [Favorite]) {
        favorites = list
        save()
    }

    // MARK: Persistence
    private func load() {
        guard let data = suite.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data)
        else { return }
        favorites = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        suite.set(data, forKey: key)
    }
}
