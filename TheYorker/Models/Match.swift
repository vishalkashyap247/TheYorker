//
//  Match.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import Foundation

// MARK: - Generic API Response Wrapper

/// Wraps every CricAPI v1 response, which always has the shape `{ data: T, status: String, info: ... }`.
struct CricAPIResponse<T: Codable>: Codable {
    let data: T?
    let status: String?
    let info: APIInfo?
}

/// Quota metadata returned alongside every API response.
struct APIInfo: Codable {
    let hitsToday: Int?
    let hitsUsed: Int?
    let credits: Int?
}

// MARK: - Match

/// A single cricket match as returned by CricAPI v1.
///
/// Conforms to `Hashable` so it can be used with `NavigationLink(value:)` —
/// the navigation system requires the value type to be `Hashable`.
struct Match: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let matchType: String?
    let status: String?
    let venue: String?
    let date: String?
    let dateTimeGMT: String?
    let teams: [String]?
    let score: [Score]?
    let seriesId: String?
    let fantasyEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, matchType, status, venue, date, dateTimeGMT, teams, score, fantasyEnabled
        case seriesId = "series_id"
    }

    // MARK: - Computed Helpers

    /// First team name, or "TBD" when the teams array is missing or empty.
    var team1: String { teams?[safe: 0] ?? "TBD" }
    var team2: String { teams?[safe: 1] ?? "TBD" }

    /// Scores belonging to team 1 — matched by checking whether the `inning` string
    /// contains the team name (CricAPI format: "India Inning 1").
    var team1Scores: [Score] {
        score?.filter { $0.inning?.lowercased().contains(team1.lowercased()) == true } ?? []
    }

    var team2Scores: [Score] {
        score?.filter { $0.inning?.lowercased().contains(team2.lowercased()) == true } ?? []
    }

    /// The most recently updated score entry — used where only one score is needed.
    var latestScore: Score? { score?.last }

    /// Returns true when the match is currently being played.
    ///
    /// Logic: a match is live when it has score data but its status does not contain
    /// a terminal keyword ("won", "drawn", "tied", etc.). This matches CricAPI's
    /// convention where the status field is the only reliable live indicator.
    var isLive: Bool {
        guard let s = status?.lowercased() else { return false }
        return !s.contains("won") &&
               !s.contains("drawn") &&
               !s.contains("tied") &&
               !s.contains("no result") &&
               !s.contains("yet to bat") &&
               !s.contains("match not") &&
               score?.isEmpty == false
    }

    /// Normalised match format label used in badges.
    var matchTypeLabel: String {
        switch matchType?.lowercased() {
        case "t20", "t20i": return "T20"
        case "odi":          return "ODI"
        case "test":         return "TEST"
        case "ipl":          return "IPL"
        default:             return matchType?.uppercased() ?? "CRICKET"
        }
    }

    /// Match name up to the first comma — strips series context to show team names only.
    var shortName: String {
        // "India vs Australia, 1st ODI" → "India vs Australia"
        let parts = name.components(separatedBy: ",").first ?? name
        return parts
    }

    /// Series / match context after the first comma — e.g. "1st ODI", "3rd T20I".
    var seriesName: String {
        name.components(separatedBy: ",").dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Score

/// A single innings score entry from CricAPI's `score` array.
struct Score: Codable, Hashable {
    let r: Int?       // runs
    let w: Int?       // wickets
    let o: Double?    // overs (e.g. 32.4)
    let inning: String?  // e.g. "India Inning 1"

    // Convenience accessors with safe defaults
    var runs: Int { r ?? 0 }
    var wickets: Int { w ?? 0 }
    var overs: Double { o ?? 0.0 }

    /// Long format: "198/3 (32.4)" — used in detail views.
    var formatted: String {
        guard let r = r else { return "Yet to bat" }
        let wicketsStr = w != nil ? "/\(w!)" : ""
        let oversStr = o != nil ? " (\(String(format: "%.1f", o!)))" : ""
        return "\(r)\(wicketsStr)\(oversStr)"
    }

    /// Short format: "198/3" — used in cards and widgets where space is tight.
    var shortFormatted: String {
        guard let r = r else { return "-" }
        if let w = w { return "\(r)/\(w)" }
        return "\(r)"
    }

    /// Human-readable innings label derived from the raw `inning` string.
    var inningShort: String {
        guard let inning = inning else { return "" }
        if inning.contains("Inning 1") || inning.contains("1st") { return "1st Inn" }
        if inning.contains("Inning 2") || inning.contains("2nd") { return "2nd Inn" }
        return inning
    }
}

// MARK: - Safe Array Subscript

extension Array {
    /// Returns the element at `index` or `nil` if the index is out of bounds.
    /// Avoids the crash that `self[index]` would cause on malformed API responses.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Mock Data

extension Match {
    /// Convenience accessor for the first mock match — used when a single match is needed
    /// (e.g. starting a mock Live Activity from Settings).
    static var mockMatch: Match { mockMatches[0] }

    /// Full set of mock fixtures covering all filter categories:
    /// live (mock_1, mock_3), upcoming (mock_4, mock_6), and recent (mock_2, mock_5).
    static let mockMatches: [Match] = [

        // MARK: Live — India vs Australia (ODI, mid-innings)
        Match(
            id: "mock_1",
            name: "India vs Australia, 2nd ODI",
            matchType: "odi",
            status: "India are batting",
            venue: "Wankhede Stadium, Mumbai",
            date: "2026-05-21",
            dateTimeGMT: "2026-05-21T09:30:00",
            teams: ["India", "Australia"],
            score: [
                Score(r: 198, w: 3, o: 32.4, inning: "India Inning 1")
            ],
            seriesId: "s1",
            fantasyEnabled: false
        ),

        // MARK: Recent — England vs New Zealand (Test, completed)
        Match(
            id: "mock_2",
            name: "England vs New Zealand, 1st Test",
            matchType: "test",
            status: "New Zealand won by 4 wickets",
            venue: "Lord's Cricket Ground, London",
            date: "2026-05-18",
            dateTimeGMT: "2026-05-18T10:00:00",
            teams: ["England", "New Zealand"],
            score: [
                Score(r: 310, w: 10, o: 92.3, inning: "England Inning 1"),
                Score(r: 289, w: 10, o: 88.1, inning: "New Zealand Inning 1"),
                Score(r: 204, w: 10, o: 67.2, inning: "England Inning 2"),
                Score(r: 206, w: 6,  o: 54.0, inning: "New Zealand Inning 2")
            ],
            seriesId: "s2",
            fantasyEnabled: false
        ),

        // MARK: Live — Pakistan vs South Africa (T20, mid-chase)
        Match(
            id: "mock_3",
            name: "Pakistan vs South Africa, 3rd T20I",
            matchType: "t20",
            status: "Pakistan are batting",
            venue: "National Stadium, Karachi",
            date: "2026-05-21",
            dateTimeGMT: "2026-05-21T15:00:00",
            teams: ["Pakistan", "South Africa"],
            score: [
                Score(r: 156, w: 10, o: 20.0, inning: "South Africa Inning 1"),
                Score(r: 89,  w: 4,  o: 12.2, inning: "Pakistan Inning 1")
            ],
            seriesId: "s3",
            fantasyEnabled: false
        ),

        // MARK: Upcoming — West Indies vs Sri Lanka (ODI, not started)
        Match(
            id: "mock_4",
            name: "West Indies vs Sri Lanka, 1st ODI",
            matchType: "odi",
            status: "Match starts in 2 hours",
            venue: "Kensington Oval, Barbados",
            date: "2026-05-22",
            dateTimeGMT: "2026-05-22T13:00:00",
            teams: ["West Indies", "Sri Lanka"],
            score: [],
            seriesId: "s4",
            fantasyEnabled: false
        ),

        // MARK: Recent — Bangladesh vs Zimbabwe (T20, completed)
        Match(
            id: "mock_5",
            name: "Bangladesh vs Zimbabwe, 2nd T20I",
            matchType: "t20",
            status: "Bangladesh won by 32 runs",
            venue: "Shere Bangla National Stadium, Dhaka",
            date: "2026-05-20",
            dateTimeGMT: "2026-05-20T14:00:00",
            teams: ["Bangladesh", "Zimbabwe"],
            score: [
                Score(r: 178, w: 5,  o: 20.0, inning: "Bangladesh Inning 1"),
                Score(r: 146, w: 10, o: 19.2, inning: "Zimbabwe Inning 1")
            ],
            seriesId: "s5",
            fantasyEnabled: false
        ),

        // MARK: Upcoming — India vs Australia (ODI, future date)
        Match(
            id: "mock_6",
            name: "India vs Australia, 3rd ODI",
            matchType: "odi",
            status: "Yet to start",
            venue: "M. Chinnaswamy Stadium, Bengaluru",
            date: "2026-05-24",
            dateTimeGMT: "2026-05-24T09:30:00",
            teams: ["India", "Australia"],
            score: [],
            seriesId: "s1",
            fantasyEnabled: false
        )
    ]

    // MARK: Pre-filtered Mock Subsets

    /// Mock matches currently in play (used by tests and previews).
    static let mockLive: [Match] = mockMatches.filter { $0.isLive }

    /// Mock matches that have not yet started.
    static let mockUpcoming: [Match] = mockMatches.filter {
        $0.score?.isEmpty == true || $0.score == nil
    }

    /// Mock matches that have concluded.
    static let mockRecent: [Match] = mockMatches.filter {
        guard let s = $0.status?.lowercased() else { return false }
        return s.contains("won") || s.contains("drawn") || s.contains("tied")
    }
}
