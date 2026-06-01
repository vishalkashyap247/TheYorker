//
//  CricAPIService.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import Foundation

// MARK: - Errors

/// Typed errors surfaced to callers; each case carries the minimal context needed for display.
enum CricAPIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(String)
    case apiError(String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid URL"
        case .noData:                return "No data received"
        case .decodingFailed(let m): return "Decoding error: \(m)"
        case .apiError(let m):       return "API error: \(m)"
        case .noAPIKey:              return "No API key configured"
        }
    }
}

// MARK: - Service

/// Singleton network layer for the CricAPI v1 REST endpoints.
/// All public methods are `async throws` — the caller decides how to handle errors.
final class CricAPIService {

    static let shared = CricAPIService()
    private init() {}

    /// Custom session with a short timeout so the UI doesn't hang on slow networks.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    // MARK: - Mock flag

    /// Returns `true` when mock data should be used instead of the live network.
    ///
    /// The Settings toggle writes to UserDefaults key `"useMockData"`.
    /// If the key exists, honour it; otherwise fall back to the compiled default in `APIConfig`.
    /// This lets the user override the build-time flag at runtime without a rebuild.
    private var shouldUseMock: Bool {
        if let stored = UserDefaults.standard.object(forKey: "useMockData") as? Bool {
            return stored
        }
        return APIConfig.useMockData
    }

    // MARK: - Fetch Current / Live Matches

    /// Returns matches that are currently in progress or started today.
    /// Simulates a realistic network delay in mock mode so loading states are testable.
    func fetchCurrentMatches() async throws -> [Match] {
        if shouldUseMock {
            try await Task.sleep(nanoseconds: 800_000_000) // simulate network
            return Match.mockMatches
        }
        return try await fetch(endpoint: "currentMatches", offset: 0)
    }

    // MARK: - Fetch All Matches (Schedule)

    /// Returns the full match schedule, paginated by `offset`.
    func fetchMatches(offset: Int = 0) async throws -> [Match] {
        if shouldUseMock {
            try await Task.sleep(nanoseconds: 600_000_000)
            return Match.mockMatches
        }
        return try await fetch(endpoint: "matches", offset: offset)
    }

    // MARK: - Search Matches

    /// Filters matches whose name or team list contains `query` (case-insensitive).
    /// In mock mode, the filter runs locally on the fixture data.
    func searchMatches(query: String) async throws -> [Match] {
        if shouldUseMock {
            try await Task.sleep(nanoseconds: 400_000_000)
            return Match.mockMatches.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.teams?.joined().localizedCaseInsensitiveContains(query) == true)
            }
        }
        let all = try await fetchMatches()
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            ($0.teams?.joined().localizedCaseInsensitiveContains(query) == true)
        }
    }

    // MARK: - Generic Fetch

    /// Shared HTTP + decode logic for all paginated CricAPI endpoints.
    /// Throws `noAPIKey` early so callers never make a request with a placeholder key.
    private func fetch(endpoint: String, offset: Int) async throws -> [Match] {
        guard APIConfig.apiKey != "YOUR_CRICAPI_KEY_HERE" else {
            throw CricAPIError.noAPIKey
        }

        var components = URLComponents(string: "\(APIConfig.baseURL)/\(endpoint)")
        components?.queryItems = [
            URLQueryItem(name: "apikey", value: APIConfig.apiKey),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        guard let url = components?.url else { throw CricAPIError.invalidURL }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CricAPIError.apiError("Status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        do {
            let decoded = try JSONDecoder().decode(CricAPIResponse<[Match]>.self, from: data)
            // CricAPI returns a `status` field; anything other than "success" is an API-level error.
            if let status = decoded.status, status != "success" {
                throw CricAPIError.apiError(status)
            }
            return decoded.data ?? []
        } catch let e as DecodingError {
            throw CricAPIError.decodingFailed(e.localizedDescription)
        }
    }
}
