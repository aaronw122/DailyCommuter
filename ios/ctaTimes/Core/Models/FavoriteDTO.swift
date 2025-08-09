// Core/Models/FavoriteDTO.swift
// Mirrors the React Native Favorite/FavoriteStop interfaces (no extra fields)

import Foundation

public struct FavoriteStopDTO: Codable, Equatable, Sendable {
    public let routeId: String
    public let routeName: String
    public let stopId: String
    public let stopName: String
    public let direction: String
    public let type: String // "train" | "bus" (stringly typed from RN)
}

public struct FavoriteDTO: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let stops: [FavoriteStopDTO] // max 2; enforced by RN
}
