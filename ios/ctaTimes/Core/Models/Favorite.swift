//
//  Favorite.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 7/29/25.
//

import Foundation

public struct Stop: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case train, bus }

    public let routeId: String
    public let routeName: String
    public let stopId: String
    public let stopName: String
    public let direction: String
    public let kind: Kind
}

public struct Favorite: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// Up to 2 stops; order preserved from source after normalization/dedup.
    public let stops: [Stop]
}
