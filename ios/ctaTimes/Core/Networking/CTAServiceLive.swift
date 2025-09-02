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
        typealias BucketItem = (favoriteID: String, stop: StopArrival)
        return try await withThrowingTaskGroup(of: BucketItem.self) { group in
            for fav in favorites {
                for stop in fav.stops {
                    group.addTask {
                        switch stop.kind {
                        case .bus:
                            let stopArrival = try await self.fetchBusStopArrival(
                                routeId: stop.routeId,
                                direction: stop.direction,
                                stopId: stop.stopId
                            )
                            return (favoriteID: fav.id, stop: stopArrival)
                        case .train:
                            let stopArrival = try await self.fetchTrainStopArrival(
                                stopId: stop.stopId,
                                routeId: stop.routeId,
                                direction: stop.direction
                            )
                            return (favoriteID: fav.id, stop: stopArrival)
                        }
                    }
                }
            }

            var buckets: [String: [StopArrival]] = [:]
            for try await item in group {
                buckets[item.favoriteID, default: []].append(item.stop)
            }

            let results: [Arrival] = buckets.map { (favID, stops) in
                Arrival(favoriteID: favID, stops: stops)
            }
            log("arrivals(for:) built \(results.count) favorite payloads")
            return results
        }
    }

    // MARK: - Per-endpoint calls (match RN)
    private func fetchBusStopArrival(routeId: String, direction: String, stopId: String) async throws -> StopArrival {
        let url = try makeURL(path: "/api/bus/times", query: [
            URLQueryItem(name: "routeId", value: routeId),
            URLQueryItem(name: "direction", value: direction),
            URLQueryItem(name: "stopId", value: stopId)
        ])
        let dto: [SimpleTimeDTO] = try await request(url: url)
        return StopArrival(stopId: stopId, routeId: routeId, direction: direction, timeDTOs: dto)
    }

    private func fetchTrainStopArrival(stopId: String, routeId: String, direction: String) async throws -> StopArrival {
        let url = try makeURL(path: "/api/train/times", query: [
            URLQueryItem(name: "stopId", value: stopId),
            URLQueryItem(name: "routeId", value: routeId)
        ])
        let dto: [SimpleTimeDTO] = try await request(url: url)
        return StopArrival(stopId: stopId, routeId: routeId, direction: direction, timeDTOs: dto)
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
