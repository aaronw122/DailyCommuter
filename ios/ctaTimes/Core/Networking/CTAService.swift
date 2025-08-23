//
//  CTAService.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 7/29/25.
//

import Foundation

// MARK: - Service protocol
public protocol CTAService {
    func arrivals(for favorites: [Favorite]) async throws -> [Arrival]
}

// MARK: - Errors
public enum CTAServiceError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decodingFailed
    case cancelled
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid service URL."
        case .badStatus(let code): return "Unexpected response (\(code))."
        case .decodingFailed: return "Failed to decode server response."
        case .cancelled: return "Request was cancelled."
        case .unknown(let error): return error.localizedDescription
        }
    }
}

