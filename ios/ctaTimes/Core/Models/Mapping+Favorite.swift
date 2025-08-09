// Core/Models/Mapping+Favorite.swift
// Translates RN DTOs -> Domain models. Keep all coupling here.

import Foundation

// MARK: - FavoriteStopDTO -> Stop

extension Stop {
    init?(dto: FavoriteStopDTO) {
        // Accept only well-formed rows; drop invalid to avoid crashing widgets
        guard
            !dto.routeId.isEmpty,
            !dto.stopId.isEmpty,
            !dto.stopName.isEmpty
        else { return nil }

        let kind = Stop.Kind(rawValue: dto.type.lowercased()) ?? .train

        self = Stop(
            routeId: dto.routeId,
            routeName: dto.routeName,
            stopId: dto.stopId,
            stopName: dto.stopName,
            direction: dto.direction,
            kind: kind
        )
    }
}

// MARK: - FavoriteDTO -> Favorite

extension Favorite {
    init?(dto: FavoriteDTO) {
        guard !dto.id.isEmpty, !dto.name.isEmpty else { return nil }

        // Map stops, drop invalid, de-dupe by stopId, cap at 2
        var seen = Set<String>()
        let normalized: [Stop] = dto.stops.compactMap { Stop(dto: $0) }.filter { stop in
            if seen.contains(stop.stopId) { return false }
            seen.insert(stop.stopId)
            return true
        }

        let trimmed = Array(normalized.prefix(2))
        guard !trimmed.isEmpty else { return nil }

        self = Favorite(id: dto.id, name: dto.name, stops: trimmed)
    }
}

// MARK: - Batch helper

public extension Array where Element == Favorite {
    static func fromDTOs(_ dtos: [FavoriteDTO]) -> [Favorite] {
        dtos.compactMap(Favorite.init(dto:))
    }
}
