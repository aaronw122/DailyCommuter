//
//  Arrival.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/8/25.
//

import Foundation

/// Domain model used by app + widget (simple: destination + absolute time).
public struct Arrival: Codable, Hashable, Sendable {
  public var favoriteID: String
  public let stops: [StopArrival]
}

public struct StopArrival: Codable, Hashable, Sendable {
    public var id: String { "\(routeId)|\(stopId)|\(time)" }
    public let stopId: String
    public let routeId: String
    public let direction: String
    public let time: [TimeInfo]
}

public struct TimeInfo: Codable, Hashable, Sendable {
    public var time: String
    public var destination: String?
}
