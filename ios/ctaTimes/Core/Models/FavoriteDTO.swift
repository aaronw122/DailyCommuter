// Core/Models/FavoriteDTO.swift
// Mirrors the React Native Favorite/FavoriteStop interfaces (no extra fields)

import Foundation

public struct FavoriteStopDTO: Codable, Equatable, Sendable {
    public let routeId: String
    public let routeName: String
    public let stopId: String
    public let stopName: String
    public let direction: String
    /// RN sends `"type"` (e.g., "train" | "bus"). The domain/widget expects `"kind"`.
    /// We store the RN value in `type`, but when encoding we write it out under the key `"kind"`.
    public let type: String

    private enum CodingKeys: String, CodingKey {
        case routeId, routeName, stopId, stopName, direction
        case type     // RN payload key
        case kind     // Domain/model key
    }

    public init(routeId: String,
                routeName: String,
                stopId: String,
                stopName: String,
                direction: String,
                type: String) {
        self.routeId = routeId
        self.routeName = routeName
        self.stopId = stopId
        self.stopName = stopName
        self.direction = direction
        self.type = type
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.routeId = try c.decode(String.self, forKey: .routeId)
        self.routeName = try c.decode(String.self, forKey: .routeName)
        self.stopId = try c.decode(String.self, forKey: .stopId)
        self.stopName = try c.decode(String.self, forKey: .stopName)
        self.direction = try c.decode(String.self, forKey: .direction)
        // Accept either "type" (RN) or "kind" (domain). Prefer "type" if present.
        if let t = try? c.decode(String.self, forKey: .type) {
            self.type = t
        } else {
            self.type = try c.decode(String.self, forKey: .kind)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(routeId, forKey: .routeId)
        try c.encode(routeName, forKey: .routeName)
        try c.encode(stopId, forKey: .stopId)
        try c.encode(stopName, forKey: .stopName)
        try c.encode(direction, forKey: .direction)
        // Normalize: always emit "kind" so the domain model decodes successfully.
        try c.encode(type, forKey: .kind)
        // (Intentionally do NOT encode the "type" key.)
    }
}

public struct FavoriteDTO: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let stops: [FavoriteStopDTO] // max 2; enforced by RN
}
