//
//  ArrivalDTO.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/9/25.
//

import Foundation

public struct SimpleTimeDTO: Codable, Equatable, Sendable {
    public let times: String        // "11" | "DUE" | "DLY"
    public let dest: String?        // trains only; null for bus
  
    enum CodingKeys: String, CodingKey {
            case times
            case dest
    }
}
