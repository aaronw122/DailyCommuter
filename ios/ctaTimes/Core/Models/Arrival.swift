//
//  Arrival.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/8/25.
//

import Foundation

/// Domain model used by app + widget (simple: destination + absolute time).
public struct Arrival: Codable, Hashable, Sendable {
    public var id: String { "\(routeId)|\(stopId)|\(time)" }
    public let stopId: String
    public let routeId: String
    public let destination: String?
    public let time: String
}


