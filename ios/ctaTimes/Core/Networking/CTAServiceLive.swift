//
//  CTAServiceLive.swift
//  DailyCommuter
//
//  Created by Aaron Williams on 8/17/25.
//

import Foundation

public struct CTAServiceLive: CTAService {
    private func log(_ msg: String) {
#if DEBUG
        print("🌐 CTAServiceLive:", msg)
#endif
    }
    // Prefer Info.plist or Build Settings for host
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: Bundle.main.object(forInfoDictionaryKey: "CTA_API_BASE_URL") as? String ?? "") ?? URL(fileURLWithPath: "/"),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        log("Init baseURL = \(self.baseURL.absoluteString)")
    }

    // Public entry: fetch across all favorite stops
    public func arrivals(for favorites: [Favorite]) async throws -> [Arrival] {
        log("arrivals(for:) favorites=\(favorites.count)")
        return try await withThrowingTaskGroup(of: [Arrival].self) { group in            for fav in favorites {
                for stop in fav.stops {
                    group.addTask {
                        switch stop.kind {
                        case .bus:
                            return try await fetchBusArrivals(
                              routeId: stop.routeId,
                              direction: stop.direction,
                              stopId: stop.stopId)
                        case .train:
                            return try await fetchTrainArrivals(
                              stopId: stop.stopId,
                              routeId: stop.routeId)
                        }
                    }
                }
            }

            var merged: [Arrival] = []
            for try await chunk in group {
                merged.append(contentsOf: chunk)
            }

            log("arrivals(for:) merged \(merged.count) arrivals")
            // Return merged array as is (optionally sorted by time string)
            return merged
        }
    }

    // MARK: - Per-endpoint calls (match RN)
    private func fetchBusArrivals(routeId: String, direction: String, stopId: String) async throws -> [Arrival] {
        let url = try makeURL(path: "/api/bus/times", query: [
            URLQueryItem(name: "routeId", value: routeId),
            URLQueryItem(name: "direction", value: direction),
            URLQueryItem(name: "stopId", value: stopId)
        ])
        let dto: [SimpleTimeDTO] = try await request(url: url)
        return dto
            .compactMap { $0.toArrival(stopId: stopId, routeId: routeId) }
    }

    private func fetchTrainArrivals(stopId: String, routeId: String) async throws -> [Arrival] {
        let url = try makeURL(path: "/api/train/times", query: [
            URLQueryItem(name: "stopId", value: stopId),
            URLQueryItem(name: "routeId", value: routeId)
        ])
        let dto: [SimpleTimeDTO] = try await request(url: url)
        return dto
            .compactMap { $0.toArrival(stopId: stopId, routeId: routeId) }
    }

    // Always fetch fresh over the network; no conditional requests.
    private func request<T: Decodable>(url: URL) async throws -> T {
        log("Request → \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, resp) = try await session.data(for: req)
            log("Response status = \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            guard let http = resp as? HTTPURLResponse else { throw CTAServiceError.badStatus(-1) }

            guard (200..<300).contains(http.statusCode) else {
                throw CTAServiceError.badStatus(http.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                log("Decoding failed for \(T.self): \(error)")
                throw CTAServiceError.decodingFailed
            }
        } catch is CancellationError {
            throw CTAServiceError.cancelled
        } catch let err as CTAServiceError {
            throw err
        } catch {
            log("Unknown error: \(error)")
            throw CTAServiceError.unknown(error)
        }
    }

    private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
        log("makeURL base=\(baseURL.absoluteString) path=\(path)")
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw CTAServiceError.invalidURL }
        comps.path = path
        comps.queryItems = query
        guard let url = comps.url else { throw CTAServiceError.invalidURL }
        return url
    }
}
